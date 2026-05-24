# API Reference - KALC POS (Refactored)

## Authentication

- `POST /api/auth/login`
  - Request: `{ "pin": "11112222" }`
  - Response: `{ "token": "...", "user": { "id": 1, "username": "waiter", "role": "waiter" } }`

- `POST /api/auth/logout`
- `GET /api/auth/me`

## Stations

- `POST /api/stations/register`
- `GET /api/stations/{id}`
- `PUT /api/stations/{id}`
- `GET /api/stations/{id}/config`
- `POST /api/stations/{id}/heartbeat`

Register request:
```json
{
  "name": "Counter 1",
  "stationType": "COUNTER",
  "ipAddress": "192.168.1.20",
  "branchId": 1
}
```

Valid station types: `COUNTER`, `TABLE`, `DELIVERY`, `KITCHEN`.

## Orders

- `POST /api/orders`
- `GET /api/orders?stationId=&userId=&status=`
- `GET /api/orders/{id}`
- `PUT /api/orders/{id}`
- `POST /api/orders/{id}/items`
- `DELETE /api/orders/{id}/items/{itemId}`
- `POST /api/orders/{id}/recall`
- `POST /api/orders/{id}/split`
- `POST /api/orders/{id}/merge`

Create request:
```json
{
  "stationId": 1,
  "totalAmount": 0
}
```

Add item request:
```json
{
  "productId": 1,
  "itemName": "Ugali + Beef Stew",
  "qty": 1,
  "unitPrice": 450
}
```

## Payments

- `POST /api/orders/{id}/payment`
- `POST /api/orders/{id}/payment/confirm`
- `POST /api/orders/{id}/payment/reject`

Payment request:
```json
{
  "mode": "mpesa",
  "amount": 450,
  "last4": "A123",
  "paynetTime": "13:45"
}
```

Valid payment modes: `cash`, `mpesa`, `card`.

## Reports - SALES (Decoupled)

### Get Sales Report
- `GET /api/reports/sales` (Admin/Manager only)
  - Returns: `{ totals: { order_count, gross_sales }, byWaiter: [] }`
  - **Note**: SALES DATA ONLY, no commission calculations

### Get Orders Report
- `GET /api/reports/orders` (Admin/Manager only)
  - Returns: `[ { id, order_no, status, total_amount, waiter_username, waiter_name, created_at } ]`

## Reports - COMMISSIONS (Decoupled)

### Get Commission Summary
- `GET /api/reports/commissions` (Admin/Manager only)
  - Returns: `[ { username, role, total_commissions, total_commissions_calc, paid_total, unpaid_total } ]`

### Get My Commissions
- `GET /api/commissions/me?from=YYYY-MM-DD&to=YYYY-MM-DD` (Waiter/Staff)
  - Returns: `{ username, role, from, to, summary: { total_commissions, paid_total, pending_total, held_total, unpaid_total }, pending: [] }`

### Get Commission Details
- `GET /api/commissions/{commissionId}` (Admin/Manager)

### Hold Commission
- `POST /api/commissions/{commissionId}/hold` (Admin/Manager)
  - Body: `{ "reason": "Pending verification", "holdUntil": "2026-05-25T00:00:00" }`
  - Returns: `{ "held": true, "commissionId": 1 }`

### Release Commission
- `POST /api/commissions/{commissionId}/release` (Admin/Manager)
  - Returns: `{ "released": true, "commissionId": 1 }`

### Mark Commissions as Paid
- `POST /api/commissions/mark-paid` (Admin/Manager)
  - Body: `{ "commissionIds": [1, 2, 3] }`
  - Returns: `{ "markedPaid": 3, "total": 3 }`

### Get Commission Audit Trail
- `GET /api/commissions/{commissionId}/audit` (Admin/Manager)
  - Returns: `[ { id, action, previous_status, new_status, details, acted_by_user_id, acted_at } ]`

## WebSocket

- `/ws/orders`
- `/ws/station/{stationId}`

Station registration message:
```json
{
  "type": "station.register",
  "stationId": 1,
  "stationType": "COUNTER"
}
```

Order events include `type`, `eventType`, `target`, `orderId`, `orderNo`, `ticketNumber`, `stationId`, `stationType`, and `status`.

## Key Architecture Changes

### Before (Tightly Coupled)
```
ReportService
├─ salesReport() → returns sales + (calculated commission)
├─ commissionSummary() → returns sales + (calculated commission)
└─ myCommission() → returns sales + (hardcoded 1% waiter, 2% kitchen)
    └─ Hardcoded rates in code
    └─ No persistence
    └─ No audit trail
```

### After (Decoupled)
```
ReportService
├─ salesReport() → SALES ONLY
└─ ordersReport() → ORDER DETAILS ONLY

CommissionService
├─ getAllCommissionsSummary() → COMMISSION DATA ONLY
├─ getMyCommissions() → Personal commissions
├─ calculateCommissionForOrder() → Calculate & persist
├─ holdCommission() → Hold workflow
├─ releaseCommission() → Release workflow
└─ markCommissionsPaid() → Batch payment processing

CommissionRepository
└─ Full CRUD + audit trail persistence
```

## Commission Status Workflow

```
pending  →  held  →  released  →  paid
          (optional hold)
                ↓ (conditional release)
```

- **pending**: Initial state after calculation
- **held**: Awaiting review/verification (with optional hold_until date)
- **released**: Approved for payment
- **paid**: Payment processed (paid_at timestamp recorded)
- **cancelled**: Manually cancelled (optional)

## Commission Rate Configuration

Commission rates are now managed via the `commission_rules` table:

```sql
SELECT * FROM commission_rules;
-- role          | commission_rate | effective_from | effective_to
-- waiter        | 1.00            | 2026-05-24     | NULL
-- super_waiter  | 1.50            | 2026-05-24     | NULL
-- kitchen_staff | 2.00            | 2026-05-24     | NULL
-- manager       | 0.00            | 2026-05-24     | NULL
-- admin         | 0.00            | 2026-05-24     | NULL
```

Rate changes are versioned - old rates are preserved with `effective_to` dates for historical accuracy.

## Audit Trail

Every commission state change is logged in `commission_audit`:

```json
{
  "id": 1,
  "commission_id": 42,
  "user_id": 3,
  "action": "HOLD",
  "previous_status": "pending",
  "new_status": "held",
  "details": "Pending verification",
  "acted_by_user_id": 1,
  "acted_at": "2026-05-24T10:30:00Z"
}
```


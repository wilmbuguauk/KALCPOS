-- Commission Rules: Configurable rates by role and effective date
CREATE TABLE IF NOT EXISTS commission_rules (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    role ENUM('waiter','super_waiter','kitchen_staff','manager','admin') NOT NULL,
    commission_rate DECIMAL(5,2) NOT NULL,
    effective_from DATE NOT NULL,
    effective_to DATE,
    notes VARCHAR(500),
    created_by_user_id BIGINT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_commission_rules_creator FOREIGN KEY (created_by_user_id) REFERENCES users(id),
    UNIQUE KEY uk_role_effective (role, effective_from),
    INDEX idx_commission_rules_role_date (role, effective_from, effective_to)
);

-- Calculated Commissions: Audit trail of all commission calculations
CREATE TABLE IF NOT EXISTS commissions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    order_id BIGINT NOT NULL,
    payment_id BIGINT,
    commission_rule_id BIGINT NOT NULL,
    gross_sales DECIMAL(12,2) NOT NULL,
    commission_rate DECIMAL(5,2) NOT NULL,
    calculated_amount DECIMAL(12,2) NOT NULL,
    status ENUM('pending','held','released','paid','cancelled') NOT NULL DEFAULT 'pending',
    hold_reason VARCHAR(500),
    hold_until TIMESTAMP,
    paid_amount DECIMAL(12,2),
    paid_at TIMESTAMP,
    released_at TIMESTAMP,
    calculated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_commissions_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_commissions_order FOREIGN KEY (order_id) REFERENCES orders(id),
    CONSTRAINT fk_commissions_payment FOREIGN KEY (payment_id) REFERENCES payments(id),
    CONSTRAINT fk_commissions_rule FOREIGN KEY (commission_rule_id) REFERENCES commission_rules(id),
    INDEX idx_commissions_user_status (user_id, status),
    INDEX idx_commissions_order (order_id),
    INDEX idx_commissions_status_date (status, calculated_at),
    INDEX idx_commissions_paid (paid_at)
);

-- Commission Audit: Full audit trail for compliance
CREATE TABLE IF NOT EXISTS commission_audit (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    commission_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    action VARCHAR(50) NOT NULL,
    previous_status VARCHAR(30),
    new_status VARCHAR(30),
    previous_amount DECIMAL(12,2),
    new_amount DECIMAL(12,2),
    details TEXT,
    acted_by_user_id BIGINT NOT NULL,
    acted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_commission_audit_commission FOREIGN KEY (commission_id) REFERENCES commissions(id) ON DELETE CASCADE,
    CONSTRAINT fk_commission_audit_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_commission_audit_actor FOREIGN KEY (acted_by_user_id) REFERENCES users(id),
    INDEX idx_commission_audit_commission (commission_id, acted_at),
    INDEX idx_commission_audit_actor (acted_by_user_id, acted_at),
    INDEX idx_commission_audit_user (user_id, acted_at)
);

-- Insert default commission rates
INSERT INTO commission_rules (role, commission_rate, effective_from, notes)
SELECT 'waiter', 1.00, CURDATE(), 'Standard waiter commission rate'
WHERE NOT EXISTS (SELECT 1 FROM commission_rules WHERE role='waiter' AND effective_from=CURDATE());

INSERT INTO commission_rules (role, commission_rate, effective_from, notes)
SELECT 'super_waiter', 1.50, CURDATE(), 'Senior waiter commission rate'
WHERE NOT EXISTS (SELECT 1 FROM commission_rules WHERE role='super_waiter' AND effective_from=CURDATE());

INSERT INTO commission_rules (role, commission_rate, effective_from, notes)
SELECT 'kitchen_staff', 2.00, CURDATE(), 'Kitchen staff commission rate'
WHERE NOT EXISTS (SELECT 1 FROM commission_rules WHERE role='kitchen_staff' AND effective_from=CURDATE());

INSERT INTO commission_rules (role, commission_rate, effective_from, notes)
SELECT 'manager', 0.00, CURDATE(), 'Manager commission rate (no commission)'
WHERE NOT EXISTS (SELECT 1 FROM commission_rules WHERE role='manager' AND effective_from=CURDATE());

INSERT INTO commission_rules (role, commission_rate, effective_from, notes)
SELECT 'admin', 0.00, CURDATE(), 'Admin commission rate (no commission)'
WHERE NOT EXISTS (SELECT 1 FROM commission_rules WHERE role='admin' AND effective_from=CURDATE());

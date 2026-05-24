package com.kalcpos.api;

import com.kalcpos.service.AuthService;
import com.kalcpos.service.CommissionService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping({"/api/v1/commissions", "/api/commissions"})
public class CommissionController {
    private final AuthService authService;
    private final CommissionService commissionService;

    public CommissionController(AuthService authService, CommissionService commissionService) {
        this.authService = authService;
        this.commissionService = commissionService;
    }

    @GetMapping("/me")
    public Object getMyCommissions(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestParam(value = "from", required = false) String from,
            @RequestParam(value = "to", required = false) String to
    ) {
        AuthService.SessionUser user = requireUser(authorization);
        return commissionService.getMyCommissions(user, parseDate(from), parseDate(to));
    }

    @GetMapping("/summary")
    public Object commissionsSummary(@RequestHeader(value = "Authorization", required = false) String authorization) {
        requireAdminOrManager(authorization);
        return commissionService.getAllCommissionsSummary();
    }

    @PostMapping("/{commissionId}/hold")
    public Object holdCommission(
            @PathVariable long commissionId,
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestBody Map<String, Object> body
    ) {
        AuthService.SessionUser user = requireAdminOrManager(authorization);
        String reason = (String) body.getOrDefault("reason", "");
        LocalDateTime holdUntil = body.containsKey("holdUntil") 
            ? LocalDateTime.parse((String) body.get("holdUntil"))
            : null;
        return commissionService.holdCommission(commissionId, reason, holdUntil, user);
    }

    @PostMapping("/{commissionId}/release")
    public Object releaseCommission(
            @PathVariable long commissionId,
            @RequestHeader(value = "Authorization", required = false) String authorization
    ) {
        AuthService.SessionUser user = requireAdminOrManager(authorization);
        return commissionService.releaseCommission(commissionId, user);
    }

    @PostMapping("/mark-paid")
    public Object markCommissionsPaid(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestBody Map<String, List<Long>> body
    ) {
        AuthService.SessionUser user = requireAdminOrManager(authorization);
        List<Long> commissionIds = body.getOrDefault("commissionIds", List.of());
        return commissionService.markCommissionsPaid(commissionIds, user);
    }

    @GetMapping("/{commissionId}/audit")
    public Object getAuditTrail(
            @PathVariable long commissionId,
            @RequestHeader(value = "Authorization", required = false) String authorization
    ) {
        requireAdminOrManager(authorization);
        return commissionService.getCommissionAuditTrail(commissionId);
    }

    private AuthService.SessionUser requireUser(String authorization) {
        AuthService.SessionUser user = authService.requireUser(authorization);
        if (user == null) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthorized");
        return user;
    }

    private AuthService.SessionUser requireAdminOrManager(String authorization) {
        AuthService.SessionUser user = requireUser(authorization);
        if (!"manager".equals(user.role()) && !"admin".equals(user.role())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not allowed");
        }
        return user;
    }

    private LocalDate parseDate(String value) {
        if (value == null || value.isBlank()) return null;
        try {
            return LocalDate.parse(value);
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid date. Use YYYY-MM-DD.");
        }
    }
}

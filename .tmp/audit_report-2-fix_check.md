# DealerOps Fresh Recheck Report (All 7 Prior Issues)

Date: 2026-04-17  
Mode: Static-only (no app run, no tests executed, no Docker)

## Overall Status
- Fixed: 7
- Not Fixed: 0

## 1) High — Least-privilege role boundaries diverge (overprivileged compliance reviewer)
- Status: **Fixed**
- Evidence:
  - Compliance reviewer is denied leads/inventory: `Models/Enums/PermissionAction.swift:63-64`
  - UI section visibility remains permission-matrix gated: `App/MainSplitViewController.swift:63-71`, `App/MainSplitViewController.swift:143-147`
- Conclusion: Original overprivilege defect is resolved.

## 2) High — Admin site context can become empty
- Status: **Fixed**
- Evidence:
  - Login assigns site using centralized resolver: `App/LoginViewController.swift:84`, `App/LoginViewController.swift:111`
  - Resolver fallback is non-empty (`"main"`): `App/ServiceContainer.swift:192-202`
  - Lead creation rejects blank site values: `Services/LeadService.swift:43-45`
  - Site-resolution fallback tests exist: `Tests/ServiceContainerTests.swift:28-67`
- Conclusion: Empty-site path is closed.

## 3) High — Audit-log read path lacks explicit authorization control
- Status: **Fixed**
- Evidence:
  - Read API guards enforce admin/reviewer roles: `Services/AuditService.swift:84-102`
  - Audit log view uses guarded API: `App/Views/Admin/AuditLogViewController.swift:34-37`
  - Authorization test coverage present: `Tests/AuditServiceTests.swift:144-179`
- Conclusion: Audit read ACL issue is resolved.

## 4) Medium — Dashboard SLA alert counts are global, not site-scoped
- Status: **Fixed**
- Evidence:
  - Dashboard passes active site into SLA query: `App/ViewModels/DashboardViewModel.swift:32`
  - SLA query is site-filtered for leads/appointments: `Services/SLAService.swift:59-70`
- Conclusion: Count path is site-scoped.

## 5) Medium — RouteSegment entity persisted but unused in carpool matching logic
- Status: **Fixed (resolved via removal/defer path)**
- Evidence:
  - Carpool matching implementation has no RouteSegment dependency and remains internally consistent with coordinate-based scoring: `Services/CarpoolService.swift:125-218`
  - Current DI repository set excludes RouteSegment and CarpoolService wiring has no RouteSegment repo argument: `App/ServiceContainer.swift:11-34`, `App/ServiceContainer.swift:153-157`
  - Current Core Data model entity list excludes RouteSegment: `Persistence/PersistenceController.swift:85-94`
- Conclusion: Previous persisted-but-unused RouteSegment shape has been removed; no active stale RouteSegment persistence path remains in runtime model wiring.

## 6) Medium — Critical authz risks have limited targeted test coverage
- Status: **Fixed**
- Evidence:
  - Staff check-in coverage (sales/clerk/reviewer): `Tests/ExceptionServiceTests.swift:138-154`
  - Check-in no-scope denial coverage: `Tests/ExceptionServiceTests.swift:156-162`
  - Audit-log ACL tests (deny for staff, allow for reviewer): `Tests/AuditServiceTests.swift:144-179`
  - Admin site-resolution behavior coverage: `Tests/ServiceContainerTests.swift:28-67`
- Conclusion: Previously listed coverage gaps are now addressed.

## 7) Low — Internal comments reference non-existent docs (`design.md`, `questions.md`)
- Status: **Fixed**
- Evidence:
  - Prior example files now use generic/internal comments without those doc references:
    - `Services/AuthService.swift:1-6`
    - `Services/LeadService.swift:1-4`
    - `App/BootstrapViewController.swift:1-5`
    - `Services/Platform/BiometricService.swift:1-9`
  - Fresh repository scan found no remaining `design.md` / `questions.md` string references.
- Conclusion: Stale reference cleanup is complete.

## Final Recheck Conclusion
- All 7 previously reported issues are currently resolved in static code evidence.
- Static boundary note: build/runtime behavior is not asserted here because this is a static-only audit.

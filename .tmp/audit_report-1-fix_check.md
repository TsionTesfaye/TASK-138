# Fresh Static Re-Check (All Previously Reported Issues) — Updated
Date: 2026-04-14
Boundary: Static-only (no app run, no tests run, no Docker)

## Overall Verdict
Pass for the previously reported issue list.

## Re-Check Results (from prior list)

1) Authorization inconsistently enforced across privileged operations
- Status: Fixed
- Evidence:
  - Carpool permissions enforced on create/update/read/match paths: Services/CarpoolService.swift:54-57, 99-102, 133-136, 233-236, 295-298, 339-343, 362-365
  - ExceptionService depends on PermissionService and enforces checks: Services/ExceptionService.swift:10-19, 39-42, 74-77, 117-120, 174-177
  - File delete guarded: Services/FileService.swift:159-164
  - Reminder complete/cancel guarded: Services/ReminderService.swift:67-72, 99-104
  - Lead VM uses service APIs (no direct protected repo reads): App/ViewModels/LeadViewModel.swift:17, 33, 40, 43

2) Permission scopes not integrated into business flows
- Status: Fixed
- Evidence:
  - validateFullAccess: Services/PermissionService.swift:53-67
  - Lead/Appointment/Inventory core paths use validateFullAccess:
    - Services/LeadService.swift:44-47, 104-107, 162-165, 218-221
    - Services/AppointmentService.swift:41-44, 81-84, 118-121, 138-141, 148-151
    - Services/InventoryService.swift:50-53, 79-82, 128-131, 167-170, 190-193

3) SLA violation path did not generate local alerts
- Status: Fixed
- Evidence:
  - Violation detection triggers local notifications with dedupe: Services/SLAService.swift:72-79, 90-97
  - Notification API wiring present: Services/Platform/NotificationService.swift:75-86

4) Automatic exception detection not orchestrated
- Status: Fixed
- Evidence:
  - Triggered after check-in: Services/ExceptionService.swift:59-61
  - Triggered in background cycle: Services/BackgroundTaskService.swift:95-101

5) Appeal evidence lifecycle mismatch
- Status: Fixed
- Evidence:
  - Evidence upload now tied to `Appeal`: App/Views/Compliance/ExceptionListViewController.swift:272-279
  - Purge constrained to denied Appeal evidence and age threshold: Services/FileService.swift:197-201, 192-209
  - Test coverage for denied/approved/pinned behavior: Tests/FileServiceTests.swift:120-166

6) Background task registration incomplete
- Status: Fixed
- Evidence:
  - Carpool/variance/exception handlers registered and scheduled: App/AppDelegate.swift:105-143
  - Exception task identifier whitelisted in Info.plist: Resources/Info.plist:54-61

7) Biometric quick re-entry flow not production-correct
- Status: Fixed
- Evidence:
  - Persisted biometric user lookup + enabled/active checks: Services/SessionService.swift:75-81
  - Biometric login uses persisted user (restart-safe): App/LoginViewController.swift:108-117
  - Enable/disable APIs wired in UI with password re-entry: App/LoginViewController.swift:126-157; Services/AuthService.swift:121-156

8) Object-level/read isolation weak
- Status: Fixed for cited paths
- Evidence:
  - Lead object-level restriction in `findById`: Services/LeadService.swift:227-237
  - Appointment SLA read is user/site scoped: Services/AppointmentService.swift:117-126
  - UI call sites pass user/site: App/Views/Leads/AppointmentListViewController.swift:25-27; App/ViewModels/DashboardViewModel.swift:43-44

9) Phone format validation incomplete
- Status: Fixed
- Evidence:
  - Phone normalization + validation in create flow: Services/LeadService.swift:58-61, 272-285

10) Check-in location flow fallback-heavy
- Status: Fixed
- Evidence:
  - One-shot permission-aware location flow + manual entry fallback: App/Views/Compliance/CheckInViewController.swift:100-138, 61-70

11) Core Data fatalError-heavy failure mode
- Status: Fixed in production paths
- Evidence:
  - No `fatalError` in App/Services/Persistence/Repositories/Models production paths (current static scan)
  - `fatalError` remains only in test helpers: Tests/TestHelpers.swift:96-118

## Update on the Previously Flagged “Last Error”
The previously flagged Medium finding about Carpool screen gating is now resolved in current code:
- Sidebar now gates Carpool by permission matrix: App/MainSplitViewController.swift:143-145
- Unauthorized Carpool load now surfaces explicit error state: App/Views/Carpool/CarpoolListViewController.swift:30-38

## Final Conclusion
All items from your previously reported error list are fixed by current static evidence.

# DealerOps Fresh Static Re-Check (Issue List Verification)
Date: 2026-04-18
Scope: Re-validated only the six previously reported findings, from scratch, using current repository state.

## Verification Boundary
- Static review only (source + tests).
- Not executed: app runtime, tests, Docker, simulator, background tasks.
- Any runtime behavior claims remain Manual Verification Required.

## Overall Conclusion
**Pass (for the six listed findings)**

All six previously reported findings appear fixed in the current codebase, based on static evidence.

---

## 1) High — Missing object-level authorization for non-appeal evidence uploads
- Status: **Fixed**
- Evidence:
  - `Services/FileService.swift:49-52` (entity type validation for `Lead`/`Appeal`)
  - `Services/FileService.swift:63-72` (object-level authorization for both lead and appeal uploads)
  - `Services/FileService.swift:297-309` (lead existence + site + ownership enforcement)
  - `Services/FileService.swift:247-260` (same checks for entity query path)
  - `Tests/FileServiceTests.swift:318-327` (non-owner lead denied)
  - `Tests/FileServiceTests.swift:330-336` (missing lead denied)
  - `Tests/FileServiceTests.swift:366-372` (unsupported entity type rejected)

## 2) High — Appointment object-level protection bypass when parent lead is missing
- Status: **Fixed**
- Evidence:
  - `Services/AppointmentService.swift:98-100` (strict parent lead guard in `updateStatus`)
  - `Services/AppointmentService.swift:166-168` (strict parent lead guard in `findById`)
  - `Services/AppointmentService.swift:183-185` (strict parent lead guard in `findByLeadId`)
  - `Tests/AppointmentServiceTests.swift:344-354` (orphan lead rejected on update)
  - `Tests/AppointmentServiceTests.swift:357-367` (orphan lead rejected on read)
  - `Tests/AppointmentServiceTests.swift:370-377` (missing lead rejected in lead query)

## 3) High — Variance workflow lacks non-admin adjustment path for below-threshold variances
- Status: **Fixed**
- Evidence:
  - `Services/InventoryService.swift:233-242` (below-threshold variances are auto-approved during `computeVariances`, item quantity auto-updated, executed adjustment order auto-created)
  - `Services/InventoryService.swift:219` (threshold check still controls `requiresApproval`)
  - `Tests/InventoryServiceTests.swift:271-291` (test asserts auto-approval + qty update + executed adjustment order for sub-threshold variance)
- Note:
  - UI still presents admin action for pending variances (`App/Views/Inventory/InventoryTaskListViewController.swift:115-117`), but below-threshold variances no longer rely on that path because they are auto-processed at compute time.

## 4) Medium — Appeal filing role semantics narrower than prompt wording
- Status: **Fixed**
- Evidence:
  - `Models/Enums/PermissionAction.swift:33` and `Models/Enums/PermissionAction.swift:57` (Inventory Clerk has `appeals: CREATE`)
  - `Tests/AppealServiceTests.swift:191-199` (inventory clerk can submit appeal)
  - `Tests/AppealServiceTests.swift:202-212` (inventory clerk remains blocked from approve)

## 5) Medium — Security-critical scenarios under-tested
- Status: **Fixed (for the cited gaps)**
- Evidence:
  - `Tests/FileServiceTests.swift:318-336` (lead ownership + missing lead negative tests)
  - `Tests/FileServiceTests.swift:366-372` (unsupported entity type rejection)
  - `Tests/AppointmentServiceTests.swift:344-377` (orphan/missing parent lead negative tests)

## 6) Low — Carpool matching comment contradicts overlap threshold
- Status: **Fixed**
- Evidence:
  - `Services/CarpoolService.swift:129` (comment says overlap >= 15 min)
  - `Services/CarpoolService.swift:155-159` (logic enforces >= 15 minutes)

---

## Final Re-Check Summary
- Fixed: 6/6 listed findings.
- Remaining from this list: none.

## Manual Verification Required
- Run test suite to confirm all new/updated tests pass in runtime.
- Perform UI flow checks to confirm inventory auto-adjust behavior is reflected correctly in screens and user messaging.

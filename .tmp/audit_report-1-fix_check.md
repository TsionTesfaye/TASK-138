# DealerOps Previous-Issues Revalidation (From Scratch)
Date: 2026-04-17  
Scope: Static code review only (no app run, no tests executed)

## Summary
- Revalidated issues: **10/10**
- Currently fixed/materially addressed in code: **10/10**
- Remaining risk: regression-test depth for some new authorization guards.

## Issue-by-Issue Status

1. **Missing object-level authorization in notes APIs**  
   - **Current status:** **Fixed**  
   - **Evidence:** `Services/NoteService.swift:36-48`, `Services/NoteService.swift:73-75`, `Services/NoteService.swift:110-113`, `Services/NoteService.swift:152-154`, `Services/NoteService.swift:180-182`, `Services/NoteService.swift:200-203`  
   - **Why:** lead/entity access enforcement is now called on create/read/tag actions.

2. **Missing object-level authorization in reminder APIs**  
   - **Current status:** **Fixed**  
   - **Evidence:** `Services/ReminderService.swift:29-39`, `Services/ReminderService.swift:60-62`, `Services/ReminderService.swift:101-103`, `Services/ReminderService.swift:138-140`, `Services/ReminderService.swift:171-173`  
   - **Why:** reminder create/read/update paths now enforce parent lead/entity access.

3. **Carpool `acceptMatch` ownership enforcement missing**  
   - **Current status:** **Fixed**  
   - **Evidence:** `Services/CarpoolService.swift:249-255`, `Services/CarpoolService.swift:276-281`  
   - **Why:** requester ownership (or admin) is enforced before mutation.

4. **Inventory variance computation trusting caller site/batch**  
   - **Current status:** **Fixed**  
   - **Evidence:** `Services/InventoryService.swift:202-204`, `Services/InventoryService.swift:209`  
   - **Why:** batch site is revalidated and entry/item site consistency is guarded.

5. **iOS Data Protection at rest not evidenced**  
   - **Current status:** **Fixed (static evidence present)**  
   - **Evidence:** `Persistence/PersistenceController.swift:24-27`, `Services/FileService.swift:86-90`  
   - **Why:** Core Data persistent store file protection option is set; evidence files are written with complete file protection unless open.

6. **Session timeout idle-based vs background-based requirement**  
   - **Current status:** **Fixed**  
   - **Evidence:** `Services/SessionService.swift:12-14`, `Services/SessionService.swift:45-49`, `Services/SessionService.swift:73-76`, `App/AppDelegate.swift:67-73`  
   - **Why:** app background timestamp is tracked and foreground re-auth decision uses background duration.

7. **Dashboard SLA check side-effecting global scan**  
   - **Current status:** **Fixed**  
   - **Evidence:** `App/ViewModels/DashboardViewModel.swift:32`, `Services/SLAService.swift:58-65`, `Services/SLAService.swift:67-69`  
   - **Why:** dashboard now uses pure `violationCounts()`; side-effecting `checkViolations()` is separated.

8. **Role modeled only as enum (no persisted entity)**  
   - **Current status:** **Fixed**  
   - **Evidence:** `Models/Entities/Role.swift:3-8`, `Repositories/RoleRepository.swift:3-8`, `Persistence/PersistenceController.swift:60`, `Persistence/PersistenceController.swift:86-88`, `Persistence/PersistenceController.swift:102-112`, `App/ServiceContainer.swift:35`, `App/ServiceContainer.swift:123-125`  
   - **Why:** persisted role entity/repository wiring now exists.

9. **Lead detail tag workflow UI path missing**  
   - **Current status:** **Fixed**  
   - **Evidence:** `App/Views/Leads/LeadDetailViewController.swift:47`, `App/Views/Leads/LeadDetailViewController.swift:134-146`, `App/Views/Leads/LeadDetailViewController.swift:235-249`  
   - **Why:** add/remove tag actions are present and wired through the lead detail UI path.

10. **README stale “PIN entry” startup statement**  
   - **Current status:** **Fixed**  
   - **Evidence:** `README.md:24`, `App/AppDelegate.swift:49-56`  
   - **Why:** startup flow text aligns with actual bootstrap/login routing.

## Static-Boundary Notes
- This report confirms code-level presence and wiring only.
- Runtime behavior (device/file system enforcement details, UX behavior under all states) remains **Manual Verification Required**.

## Residual Risk (Non-blocking)
- Some newly added security checks are not yet covered by targeted negative regression tests (for example, non-owner deny cases in notes/reminders/carpool/inventory).

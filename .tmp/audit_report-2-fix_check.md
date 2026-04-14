# DealerOps Static Recheck (From Scratch)
Date: 2026-04-14
Mode: Static-only (no app run, no tests run)

## Overall
**Pass**

- Rechecked all 10 previously reported findings against current code.
- **10/10 are fixed.**

## Per-Issue Results

### 1) Blocker — Missing lot/site data isolation at model/repository layer
- Status: **Fixed**
- What is fixed:
  - `siteId` exists on lead/inventory entities and many service/repo paths are site-filtered.
  - Evidence: `Models/Entities/Lead.swift:6`, `Models/Entities/InventoryItem.swift:6`, `Repositories/LeadRepository.swift:10`, `Persistence/CoreDataRepositories/CoreDataLeadRepository.swift:44`, `Services/LeadService.swift:115`, `Services/LeadService.swift:240`, `Services/LeadService.swift:261`
- Recheck conclusion:
  - Site isolation is now materially enforced across reviewed entity, repository, and service paths for this finding.
  - Exception/appeal/file paths are site-scoped where this issue previously failed: `Services/ExceptionService.swift:354`, `Services/ExceptionService.swift:364`, `Services/AppealService.swift:45`, `Services/AppealService.swift:160`, `Services/FileService.swift:233`, `Services/FileService.swift:266`.
  - Deferred carpool matching now scopes candidate search to each order’s site: `Services/CarpoolService.swift:359`.

### 2) High — Inconsistent object-level authorization on mutable operations
- Status: **Fixed**
- Evidence:
  - Lead mutate paths enforce ownership + site: `Services/LeadService.swift:112`, `Services/LeadService.swift:115`, `Services/LeadService.swift:118`, `Services/LeadService.swift:176`, `Services/LeadService.swift:179`, `Services/LeadService.swift:182`
  - Appointment create/update/read paths enforce ownership + site: `Services/AppointmentService.swift:49`, `Services/AppointmentService.swift:52`, `Services/AppointmentService.swift:93`, `Services/AppointmentService.swift:96`, `Services/AppointmentService.swift:130`, `Services/AppointmentService.swift:141`, `Services/AppointmentService.swift:164`, `Services/AppointmentService.swift:183`

### 3) High — Appeal review actions do not enforce reviewer ownership
- Status: **Fixed**
- Evidence:
  - Ownership check enforced on approve/deny: `Services/AppealService.swift:147`, `Services/AppealService.swift:199`, `Services/AppealService.swift:301`, `Services/AppealService.swift:305`

### 4) High — File access authorization module mismatch for appeal evidence
- Status: **Fixed**
- Evidence:
  - Entity-aware module routing + appeal object checks: `Services/FileService.swift:215`, `Services/FileService.swift:225`, `Services/FileService.swift:246`, `Services/FileService.swift:257`, `Services/FileService.swift:266`

### 5) High — File format validation trusts declared type only
- Status: **Fixed**
- Evidence:
  - Magic-byte validation call + implementation: `Services/FileService.swift:61`, `Services/FileService.swift:62`, `Services/FileService.swift:280`, `Services/FileService.swift:287`, `Services/FileService.swift:290`, `Services/FileService.swift:294`

### 6) High — Background deferred matching/variance calculations not materially implemented
- Status: **Fixed**
- Evidence:
  - Background wiring: `Services/BackgroundTaskService.swift:73`, `Services/BackgroundTaskService.swift:76`, `Services/BackgroundTaskService.swift:85`, `Services/BackgroundTaskService.swift:87`
  - Deferred implementations: `Services/CarpoolService.swift:343`, `Services/InventoryService.swift:409`

### 7) Medium — Closed lead archival limited to `closed_won`
- Status: **Fixed**
- Evidence:
  - Terminal statuses include `closedWon` + `invalid`: `Repositories/LeadRepository.swift:37`, `Persistence/CoreDataRepositories/CoreDataLeadRepository.swift:35`

### 8) Medium — Multi-passenger trip merge behavior incomplete
- Status: **Fixed**
- Evidence:
  - Offer stays active until seats exhausted: `Services/CarpoolService.swift:262`, `Services/CarpoolService.swift:264`
  - Deferred matching supports iterative matching: `Services/CarpoolService.swift:343`

### 9) Medium — Encryption fallback may persist plaintext on failure
- Status: **Fixed**
- Evidence:
  - Save now hard-fails on encryption failure (no plaintext fallback): `Persistence/CoreDataRepositories/EncryptedCoreDataLeadRepository.swift:59`, `Persistence/CoreDataRepositories/EncryptedCoreDataLeadRepository.swift:62`, `Persistence/CoreDataRepositories/EncryptedCoreDataLeadRepository.swift:65`, `Persistence/CoreDataRepositories/EncryptedCoreDataLeadRepository.swift:80`

### 10) Low — Lead list default may hide non-new leads
- Status: **Fixed**
- Evidence:
  - No-filter path now loads all non-archived leads: `App/ViewModels/LeadViewModel.swift:16`, `App/ViewModels/LeadViewModel.swift:19`, `Services/LeadService.swift:275`, `Services/LeadService.swift:282`

## Final Summary
- Fixed: **10**
- Partially fixed / still open: **0**
- Not fixed: **0**

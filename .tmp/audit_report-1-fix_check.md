# Reinspection Report (From Scratch)

## Scope
- Static-only reinspection of the previously reported findings.
- No app run, no tests executed, no Docker, no code modifications.

## Overall Result
- Previous findings rechecked: **7**
- **Fixed:** 7
- **Partially Fixed:** 0
- **Not Fixed:** 0

## Detailed Status

### 1) High - Carpool object-level authorization gaps allow cross-owner operations within a site
- Previous conclusion: Fail
- Current status: **Fixed**
- Evidence:
  - `completeOrder` now enforces owner-or-admin:
    - `Services/CarpoolService.swift:325-327`
  - `findMatchesByOrderId` now enforces owner-or-admin:
    - `Services/CarpoolService.swift:493-499`
  - Regression tests added for owner/admin/non-owner behavior:
    - `Tests/CarpoolServiceTests.swift:50-56`
    - `Tests/CarpoolServiceTests.swift:307-358`
    - `Tests/CarpoolServiceTests.swift:360-409`
- Reinspection note: The exact cross-owner exposure path previously reported is now blocked by explicit object-level checks.

### 2) High - Prompt-declared route-segment persistence model is missing
- Previous conclusion: Partial Fail
- Current status: **Fixed**
- Evidence:
  - `RouteSegment` entity/model now exists:
    - `Models/Entities/RouteSegment.swift:3-13`
  - Core Data model includes `CDRouteSegment`:
    - `Persistence/PersistenceController.swift:83-95`
    - `Persistence/PersistenceController.swift:475-490`
  - Route segment repository added (in-memory + Core Data):
    - `Repositories/RouteSegmentRepository.swift:3-22`
    - `Persistence/CoreDataRepositories/CoreDataSecondaryRepositories.swift:329-346`
  - Service wiring includes route segment repo:
    - `App/ServiceContainer.swift:33`
    - `App/ServiceContainer.swift:92`
    - `App/ServiceContainer.swift:121`
    - `App/ServiceContainer.swift:156-160`
  - Carpool matching persists route segments:
    - `Services/CarpoolService.swift:224`
    - `Services/CarpoolService.swift:442-450`
  - Static tests for persistence behavior:
    - `Tests/CarpoolServiceTests.swift:56-57`
    - `Tests/CarpoolServiceTests.swift:413-476`
- Reinspection note: Route-segment persistence is now implemented end-to-end in model, repos, wiring, and service logic.

### 3) High - Video evidence is accepted but not rendered in viewer
- Previous conclusion: Fail
- Current status: **Fixed**
- Evidence:
  - Upload still supports MP4:
    - `Services/FileService.swift:33-35`
  - Evidence picker captures video as `.mp4`:
    - `App/Views/Compliance/ExceptionListViewController.swift:270-273`
  - Viewer now handles video with `AVPlayerViewController`:
    - `App/Views/Shared/MediaViewerViewController.swift:2`
    - `App/Views/Shared/MediaViewerViewController.swift:46-61`
- Reinspection note: End-to-end static support for video evidence viewing is now present.

### 4) Medium - UI evidence capture path always converts images to JPEG
- Previous conclusion: Partial Pass
- Current status: **Fixed**
- Evidence:
  - Picker now branches by UTI and preserves PNG:
    - `App/Views/Compliance/ExceptionListViewController.swift:262-266`
  - JPEG path remains fallback for non-PNG image inputs:
    - `App/Views/Compliance/ExceptionListViewController.swift:267-269`
  - Service accepts both `.jpg` and `.png`:
    - `Services/FileService.swift:63-64`
- Reinspection note: PNG is now handled explicitly; prior “always JPEG” behavior is no longer present.

### 5) Medium - Decrypt fallback returns ciphertext as plaintext on failure
- Previous conclusion: Fail
- Current status: **Fixed**
- Evidence:
  - Fallback now returns redacted failure marker, not ciphertext:
    - `Persistence/CoreDataRepositories/EncryptedCoreDataLeadRepository.swift:88-90`
- Reinspection note: The specific leakage path (ciphertext surfacing as plaintext) is removed.

### 6) Medium - Debug seeding with hardcoded credentials is production-reachable via launch arg
- Previous conclusion: Partial Pass
- Current status: **Fixed**
- Evidence:
  - Seeder invocation now gated behind debug compilation:
    - `App/AppDelegate.swift:22-31`
- Reinspection note: In release builds, this seeding path is compile-time excluded.

### 7) Medium - Documentation inconsistencies around reviewer scope and module model
- Previous conclusion: Partial Pass
- Current status: **Fixed**
- Evidence:
  - README reviewer scope now matches seeder scope:
    - `README.md:79`
    - `Services/DebugSeeder.swift:33`
  - README module count now aligned with permission matrix:
    - `README.md:183`
    - `Models/Enums/PermissionAction.swift:4-11`
- Reinspection note: Previously flagged doc drift appears corrected.

## Final Note
- Based on current static code evidence, all previously listed findings have been addressed.
- Runtime behavior (e.g., actual playback on all device states) still requires manual verification if needed.

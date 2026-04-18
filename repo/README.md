<!-- type: ios -->
# DealerOps — Offline Mobility & Inventory Suite

Fully offline **iOS** application for independent auto dealerships. Manages sales leads, inventory counting, staff carpool matching, compliance exceptions/appeals, and audit logging — all on-device with no network connectivity required.

## Requirements

- **Xcode 15+**
- **iOS 15.0+** deployment target (iPhone and iPad supported)
- **macOS 13+** host for development
- No external dependencies — all frameworks are Apple-native

## Quick Start

### Build & Run on iOS Simulator

1. Open the project:
   ```bash
   open DealerOps.xcodeproj
   ```
2. In Xcode, select the target **DealerOps** (top-left scheme selector).
3. Choose a simulator — e.g. **iPhone 15 (iOS 17.x)** — from the device picker.
4. Press **⌘R** (or **Product → Run**).
5. The app launches to the **Login screen** (username + password) if bootstrap has been completed, or the **Bootstrap wizard** (first-run admin account creation) if no users exist yet.

To run on a physical device, connect your iPhone, select it in the device picker, and ensure a valid development team is set under **Signing & Capabilities**.

### Regenerate Xcode Project

```bash
ruby scripts/generate_xcodeproj.rb
open DealerOps.xcodeproj
```

### Run Tests (macOS only)

```bash
bash scripts/run_tests.sh
```

Requires macOS with Xcode Command Line Tools (`swiftc` on PATH). The full suite — including CoreData integration and ViewModel tests — runs only on macOS. On other platforms the script prints a friendly message explaining why and exits cleanly without failure.

There is no Docker/Linux test fallback; all service and persistence tests depend on Apple frameworks (CoreData, os.log) that are not available on Linux.

### Static Lint

```bash
./scripts/lint.sh
```

---

## Tester Quick Start (Skip Bootstrap)

QA testers and reviewers do not need to complete the admin-creation bootstrap wizard. Launch the app with a single argument to have all four demo accounts seeded automatically — the app opens directly on the Login screen.

**In Xcode:**
1. Open **Product → Scheme → Edit Scheme…**
2. Select **Run → Arguments → Arguments Passed On Launch**
3. Add `-SeedDemoAccounts`
4. Close and press **⌘R**

The app will skip Bootstrap and land on the Login screen with all accounts ready.

**On the command line (Simulator via `xcrun simctl`):**
```bash
xcrun simctl launch booted com.dealerops.app -SeedDemoAccounts
```

### Demo Credentials

Demo site for permission-scoped features (Leads, Inventory, Carpool, Compliance): **`demo-lot`**

| Role | Username | Password | Site Access |
|------|----------|----------|-------------|
| Administrator | `admin` | `Admin12345678` | All sites (bypasses scope) |
| Sales Associate | `sales1` | `Sales12345678` | `demo-lot` — leads, carpool |
| Inventory Clerk | `clerk1` | `Clerk12345678` | `demo-lot` — inventory |
| Compliance Reviewer | `reviewer1` | `Reviewer12345` | `demo-lot` — exceptions, appeals, checkin |

> **Passwords meet the app policy**: ≥ 12 characters, at least one uppercase letter, one lowercase letter, and one digit.

> **Idempotent**: launching with `-SeedDemoAccounts` multiple times is safe — the seeder checks by username before saving and never overwrites existing accounts.

> **Bootstrap locked**: once any account exists (`userRepo.count > 0`) the Bootstrap screen is permanently unreachable. The seeder creates accounts before `AppDelegate` routes to the first screen, so Bootstrap is bypassed on the very first launch with the flag.

---

## Functional Verification Walkthrough

Follow this end-to-end flow to confirm the system is working correctly after build or deployment.

### 1 — Reach the Login screen

**Tester path (recommended):** Add `-SeedDemoAccounts` to the scheme's launch arguments as described in [Tester Quick Start](#tester-quick-start-skip-bootstrap). The app opens directly on the Login screen with all four demo accounts ready. Skip to step 2.

**First-run path (production flow):** On a clean install with no accounts the **Bootstrap Setup** screen appears. Enter a username and a policy-compliant password (≥ 12 chars, 1 uppercase, 1 lowercase, 1 digit) and tap **Create Administrator**. The app transitions to the Login screen. ✓

### 2 — Login & Session
1. Log in as `admin` / `Admin12345678`.
2. The **Dashboard** (home screen) appears showing module tiles: Leads, Inventory, Carpool, Compliance, Admin. ✓
3. Leave the app idle for 5 minutes; the screen locks and re-prompts for credentials (session timeout). ✓

### 3 — Lead Creation (Sales Associate)
1. Log in as `sales1` / `Sales12345678`.
2. Tap **Leads → New Lead**.
3. Fill in Customer Name, Phone, Vehicle Interest, and Contact Window. Tap **Save**.
4. The lead appears in the leads list with status **New** and an SLA deadline 2 hours out. ✓
5. Open the lead → tap **Add Note** → enter text → **Save**. The SLA deadline resets. ✓
6. Tap **Transition → Follow-Up**. Status updates to **Follow-Up**. ✓

### 4 — Appointment Scheduling
1. Still on the lead detail, tap **Schedule Appointment**.
2. Pick a future date/time. Tap **Save**.
3. The appointment appears under the lead with status **Scheduled**. ✓
4. Tap the appointment → **Confirm**. Status changes to **Confirmed**. ✓

### 5 — Inventory Count (Inventory Clerk)
1. Log in as `clerk1` / `Clerk12345678`.
2. Tap **Inventory → Start Count Task**.
3. Scan or enter item barcodes; each scan creates a Count Entry. ✓
4. Tap **Compute Variances**. Items with discrepancies appear in the variance list. ✓
5. Variances requiring approval show status **Pending Approval**. ✓

### 6 — Variance Approval (Administrator)
1. Log in as `admin`.
2. Tap **Inventory → Pending Approvals**.
3. Select a variance and tap **Approve**. Status changes to **Approved**. ✓

### 7 — Exception & Appeal (Compliance)
1. Log in as `reviewer1` / `Reviewer12345`.
2. Tap **Compliance → Exceptions**. Auto-detected exceptions appear. ✓
3. Open an exception → tap **Create Appeal**.
4. Assign the appeal to yourself → tap **Start Review** → **Approve** or **Deny**. ✓
5. The exception status reflects the appeal outcome. ✓

### 8 — Carpool Matching
1. Log in as `sales1`.
2. Tap **Carpool → Create Pool Order** and enter origin, destination, and time window.
3. Log in (second device or simulator) as another sales associate at the same site and create an overlapping order.
4. Tap **Find Matches**. The system returns matched orders within 2 mi and 15-min overlap. ✓

---

## Architecture

```
App/                    UIKit layer (ViewControllers, ViewModels)
Models/                 Domain entities and enums
Repositories/           Protocol-based data access (InMemory + CoreData)
Persistence/            Core Data stack, managed object mappings
Services/               All business logic (16 services)
Tests/                  Unit, integration, and Core Data tests
Resources/              Info.plist, LaunchScreen, entitlements
```

### Key Design Decisions

- **Layered architecture**: Views → ViewModels → Services → Repositories → Core Data
- **No business logic in UI**: All validation, state machines, permissions enforced in services
- **Protocol-based repositories**: InMemory for tests, CoreData for production
- **PBKDF2 password hashing**: 100,000 iterations via CommonCrypto (CryptoShim on Linux)
- **AES-256-CBC encryption**: Per-record keys stored in Keychain for sensitive fields
- **Programmatic Core Data model**: No .xcdatamodeld — model built in Swift code

## Modules

| Module | Description |
|--------|-------------|
| Auth | Bootstrap, login, lockout, biometric, session timeout |
| Leads | Lifecycle (New→FollowUp→ClosedWon/Invalid), SLA, notes, tags, reminders |
| Appointments | Scheduling, confirmation, SLA alerts |
| Inventory | Count tasks, batch entries, scanner input, variance detection, admin approval |
| Carpool | Pool orders, Haversine matching, 15-min windows, seat locking |
| Compliance | Exception auto-detection, appeal workflow, evidence handling |
| Admin | User management, role assignment, permission scope management |

## Security

- PBKDF2-HMAC-SHA256 password hashing (100k iterations)
- AES-256-CBC field encryption (phone, customerName, consentNotes)
- Per-record Keychain key storage
- Role-based access control (4 roles × 7 modules)
- Permission scope validation (site + function + date range)
- Site/lot data isolation: all queries are scoped to the authenticated user's site
- 5-minute session timeout with forced re-authentication
- Phone number masking in list views
- Binary signature (magic-byte) validation on uploaded evidence files
- Audit logging with tombstone deletion (1-year retention)

## Test Coverage

Tests covering:
- Authentication (18), Session (6), Permissions (14), User Management (8)
- Leads (13), Appointments (17), Notes/Tags (15), Reminders (13)
- SLA/Business Hours (5), Inventory/Variance (13)
- Carpool (21), Exceptions (6), Appeals (10), Audit (8)
- State Machines (4), Core Data Integration (23)
- Encryption (6), FileService (13), BackgroundTasks (6)

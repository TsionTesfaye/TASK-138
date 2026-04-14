# DealerOps — Offline Mobility & Inventory Suite

Fully offline iOS application for independent auto dealerships. Manages sales leads, inventory counting, staff carpool matching, compliance exceptions/appeals, and audit logging — all on-device with no network connectivity required.

## Requirements

- **Xcode 15+**
- **iOS 15.0+** deployment target
- **iPhone and iPad** supported
- No external dependencies — all frameworks are Apple-native

## Quick Start

### Open in Xcode

```bash
open DealerOps.xcodeproj
```

Or regenerate the project:

```bash
ruby scripts/generate_xcodeproj.rb
open DealerOps.xcodeproj
```

### Run Tests (without Xcode)

```bash
./run_tests.sh
```

### Run Tests (Docker)

```bash
docker compose up --build
```

### Static Lint

```bash
./scripts/lint.sh
```

## Architecture

```
App/                    UIKit layer (ViewControllers, ViewModels)
Models/                 Domain entities and enums
Repositories/           Protocol-based data access (InMemory + CoreData)
Persistence/            Core Data stack, managed object mappings
Services/               All business logic (16 services)
Tests/                  145 tests (unit + integration + Core Data)
Resources/              Info.plist, LaunchScreen, entitlements
```

### Key Design Decisions

- **Layered architecture**: Views → ViewModels → Services → Repositories → Core Data
- **No business logic in UI**: All validation, state machines, permissions enforced in services
- **Protocol-based repositories**: InMemory for tests, CoreData for production
- **PBKDF2 password hashing**: 100,000 iterations via CommonCrypto
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
- Role-based access control (4 roles × 5 modules)
- Permission scope validation (site + function + date range)
- 5-minute session timeout with forced re-authentication
- Phone number masking in list views
- Audit logging with tombstone deletion (1-year retention)

## Test Coverage

145 tests covering:
- Authentication (18), Session (6), Permissions (14), User Management (8)
- Leads (13), SLA/Business Hours (5), Inventory/Variance (13)
- Carpool (10), Exceptions (6), Appeals (10), Audit (8)
- State Machines (4), Core Data Integration (23)
- Encryption (6), FileService (9), BackgroundTasks (5)

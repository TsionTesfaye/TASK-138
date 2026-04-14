# DealerOps — design.md

## 1. System Overview

DealerOps is a fully offline iOS application that manages:
- sales leads and appointments
- inventory counting and variance workflows
- staff transportation (carpool matching)
- compliance exceptions and appeals

All logic and data persist locally using Core Data.  
No external services, APIs, or network dependencies exist.

---

## 2. Architecture

### 2.1 Pattern

The app follows a strict layered architecture:

Views (UIKit / SwiftUI wrappers)  
→ ViewModels / Controllers  
→ Services (business logic)  
→ Persistence (Core Data)

Rules:
- No business logic in views
- All workflows enforced in service layer
- Controllers only orchestrate
- ALL validation must occur in services (never UI-only)

---

### 2.2 Core Modules

- Auth Module
- Lead & Appointment Module
- Inventory & Counting Module
- Carpool Matching Module
- Exception & Appeal Module
- Media & File Module
- Audit & Security Module
- SLA & Background Processing Module (NEW)

---

### 2.3 Mandatory Enforcement Rules (NEW)

The following rules are globally enforced:

- ALL state transitions must go through service layer
- ALL writes must:
  - validate permissions
  - validate state transition
  - log audit event
- NO direct Core Data writes from UI

Violation of these rules is considered a system failure.

## 3. Data Model

All entities use UUID primary keys.

---

### 3.1 User

- `id: UUID`
- `username: String` (unique)
- `passwordHash: String`
- `passwordSalt: String`  ← NEW
- `role: Enum`
- `biometricEnabled: Bool`
- `failedAttempts: Int`
- `lastFailedAttempt: Date?` ← NEW
- `lockoutUntil: Date?`
- `createdAt: Date`
- `isActive: Bool` ← NEW

---

### 3.2 PermissionScope

- `id: UUID`
- `userId: UUID`
- `site: String`
- `functionKey: String`
- `validFrom: Date`
- `validTo: Date`

---

### 3.3 Lead

- `id: UUID`
- `leadType: Enum` (`quote_request`, `appointment`, `general_contact`)
- `status: Enum` (`new`, `follow_up`, `closed_won`, `invalid`)
- `customerName: String`
- `phone: String`
- `vehicleInterest: String`
- `preferredContactWindow: String`
- `consentNotes: String`
- `assignedTo: UUID?`
- `createdAt: Date`
- `updatedAt: Date`
- `slaDeadline: Date?` ← NEW
- `lastQualifyingAction: Date?` ← NEW
- `archivedAt: Date?` ← NEW

---

### 3.4 Appointment

- `id: UUID`
- `leadId: UUID`
- `startTime: Date`
- `status: Enum` (`scheduled`, `confirmed`, `completed`, `canceled`, `no_show`)

---

### 3.5 Note

- `id: UUID`
- `entityId: UUID`
- `entityType: String`
- `content: String`
- `createdAt: Date`
- `createdBy: UUID` ← NEW

---

### 3.6 Tag

- `id: UUID`
- `name: String` (normalized unique)

### 3.6.1 TagAssignment (NEW)

- `tagId: UUID`
- `entityId: UUID`
- `entityType: String`

---

### 3.7 Reminder

- `id: UUID`
- `entityId: UUID`
- `entityType: String` ← NEW
- `createdBy: UUID` ← NEW
- `dueAt: Date`
- `status: Enum` (`pending`, `completed`, `canceled`)

---

### 3.8 PoolOrder

- `id: UUID`
- `originLat: Double` ← UPDATED
- `originLng: Double` ← UPDATED
- `destinationLat: Double` ← UPDATED
- `destinationLng: Double` ← UPDATED
- `startTime: Date`
- `endTime: Date`
- `seatsAvailable: Int`
- `vehicleType: String`
- `createdBy: UUID`
- `status: Enum` ← NEW (draft, active, matched, completed, canceled, expired)

---

### 3.9 RouteSegment

- `id: UUID`
- `poolOrderId: UUID`
- `sequence: Int`
- `locationLat: Double` ← UPDATED
- `locationLng: Double` ← UPDATED

---

### 3.10 InventoryItem

- `id: UUID`
- `identifier: String`
- `expectedQty: Int`
- `location: String`
- `custodian: String`

---

### 3.11 CountTask

- `id: UUID`
- `assignedTo: UUID`
- `status: Enum`

---

### 3.12 CountBatch

- `id: UUID`
- `taskId: UUID`
- `createdAt: Date`

---

### 3.12.1 CountEntry (NEW — CRITICAL FIX)

- `id: UUID`
- `batchId: UUID`
- `itemId: UUID`
- `countedQty: Int`
- `countedLocation: String`
- `countedCustodian: String`

---

### 3.13 Variance

- `id: UUID`
- `itemId: UUID`
- `expectedQty: Int`
- `countedQty: Int`
- `type: Enum`
- `requiresApproval: Bool`
- `approved: Bool`

---

### 3.14 AdjustmentOrder

- `id: UUID`
- `varianceId: UUID`
- `approvedBy: UUID?`
- `createdAt: Date`
- status: Enum (pending, approved, executed)

Service Rule:
- when executed:
  → update InventoryItem.expectedQty

---

### 3.15 ExceptionCase

- `id: UUID`
- `type: Enum`
- `sourceId: UUID`
- `reason: String` ← NEW
- `status: Enum` ← NEW
- `createdAt: Date`

---

### 3.15.1 CheckIn (NEW — CRITICAL)

- `id: UUID`
- `userId: UUID`
- `timestamp: Date`
- `locationLat: Double`
- `locationLng: Double`

---

### 3.16 Appeal

- `id: UUID`
- `exceptionId: UUID`
- `status: Enum`
- `reviewerId: UUID?`
- `reason: String`
- `resolvedAt: Date?` ← NEW

---

### 3.17 EvidenceFile

- id: UUID
- entityId: UUID   ← ADD
- entityType: String  ← ADD
- filePath: String
- fileType: String
- fileSize: Int
- hash: String
- createdAt: Date
- pinnedByAdmin: Bool
---

### 3.18 AuditLog

- `id: UUID`
- `actorId: UUID`
- `action: String`
- `entityId: UUID`
- `timestamp: Date`
- `tombstone: Bool`
- `deletedAt: Date?` ← NEW
- `deletedBy: UUID?` ← NEW

### 3.19 BusinessHoursConfig (NEW)

- id: UUID
- startHour: Int (default 9)
- endHour: Int (default 17)
- workingDays: [Mon–Fri]

---

## 4. Core Services

---

### 4.1 AuthService

Responsibilities:
- login
- password validation
- lockout enforcement
- biometric enablement
- bootstrap admin (NEW)

Rules:
- 5 failed attempts → 10 min lock
- rolling window using `lastFailedAttempt`
- password hashed + salted

---

### 4.2 LeadService

Responsibilities:
- create/update leads
- enforce lifecycle transitions
- SLA tracking
- archiving (NEW)

Rules:
- strict transition table
- SLA only resets on qualifying actions

---

### 4.3 AppointmentService

Responsibilities:
- manage appointments
- trigger SLA alerts

Rules:
- alert if unconfirmed within 30 min

---

### 4.4 ReminderService

Responsibilities:
- manage reminders
- trigger local notifications

Rules:
- no external messaging
- state-driven updates

---

### 4.5 CarpoolService

Responsibilities:
- create pool orders
- compute matches

Rules:
- use Haversine distance calculation ← NEW
- filter by:
  - time overlap
  - seat availability
- reject if detour > min(10%, 1.5 miles)
- persist matches (NEW)
- lock seat allocation (NEW)

---

### 4.6 InventoryService

Responsibilities:
- manage counts
- compute variances

Rules:
- uses CountEntry (NOT batch directly) ← FIXED
- threshold = max(3 units, 2%)
- create AdjustmentOrder

---

### 4.7 ExceptionService

Responsibilities:
- generate exception cases

Rules:
- triggered from:
  - CheckIn
  - inventory anomalies
- must record reason (NEW)

---

### 4.8 AppealService

Responsibilities:
- manage appeals
- enforce workflow

Rules:
- approval updates ExceptionCase status ← FIXED
- full audit trail

---

### 4.9 FileService

Responsibilities:
- handle uploads
- validate files
- manage lifecycle

Rules:
- image ≤ 10 MB
- video ≤ 50 MB
- SHA-256 fingerprint
- watermark support (NEW)
- sandbox-only storage

---

### 4.10 AuditService

Responsibilities:
- log all actions
- manage tombstones

Rules:
- append-only logs
- deleted logs become tombstones
- retained for 1 year

---

### 4.11 SLAService (NEW)

Responsibilities:
- compute deadlines
- detect SLA violations

---

## 4.12 BackgroundTaskService (NEW)

Responsibilities:
- SLA checks
- media cleanup
- carpool recalculation

---

## 4.13 State Machines (NEW)

All entities with status MUST enforce transitions via explicit tables.

### Lead State Machine

Allowed transitions:

- new → follow_up
- follow_up → closed_won
- follow_up → invalid
- invalid → follow_up (Admin only)
- closed_won → follow_up (Admin only)

---

### PoolOrder State Machine

- draft → active
- active → matched
- matched → completed
- active → canceled
- any → expired (background task)

---

### Appeal State Machine

- submitted → under_review
- under_review → approved
- under_review → denied
- approved/denied → archived

## 4.14 Idempotency & Concurrency (NEW)

All critical actions must be idempotent.

### Rules

- Each write must include:
  - operationId (UUID)
- If operationId already exists:
  - ignore duplicate execution

---

### Concurrency Control

- Use last-write-wins with audit logging
- For critical operations (e.g., carpool matching):
    - apply entity-level lock during update
  
## 4.15 Permission Enforcement Contract (NEW)

ALL services must call:

PermissionService.validateAccess(user, action, entity)

Before ANY write or sensitive read.

---

Rules:

- No permission checks in UI
- No bypass allowed
- Missing permission = hard failure

## 4.16 SLA Execution Model (NEW)

SLA is enforced via BackgroundTaskService.

---

### SLA Trigger

- On Lead creation → compute deadline
- On qualifying update → recompute deadline

---

### SLA Check

Runs every app wake or scheduled interval:

- If now > slaDeadline:
  - trigger alert
  - log SLA violation
  
## 4.17 SessionService 

Responsibilities:
- manage active session
- track background/foreground transitions
- enforce re-authentication

Rules:
- store lastActiveTimestamp
- if app resumes and idle > 5 minutes:
  - require password or biometric re-auth
- session state stored in memory only

## 4.18 UserManagementService (NEW)

Responsibilities:
- create users
- update roles
- deactivate users
- reset lockout

Rules:
- only Administrator can perform these actions
- must log all changes in AuditLog

## 4.19 Permission Matrix (NEW)

| Role                | Leads | Inventory | Carpool | Appeals | Admin |
|---------------------|------|----------|--------|--------|------|
| Administrator       | FULL | FULL     | FULL   | FULL   | FULL |
| Sales Associate     | CRUD | NONE     | VIEW   | CREATE | NONE |
| Inventory Clerk     | NONE | CRUD     | NONE   | NONE   | NONE |
| Compliance Reviewer | READ | READ     | NONE   | REVIEW | NONE |

## 4.20 Exception Detection Rules (NEW)

- Missed check-in:
  → no check-in within 30 min of expected time

- Buddy punching:
  → 2 users check in within 30 seconds at same location

- Misidentification:
  → inconsistent check-in pattern over time



## 5. Security

- AES encryption for sensitive fields
- keys stored in Keychain
- masking applied in UI
- role + scope enforced via service layer (NOT UI)

---

## 5.1 Input Validation Rules (NEW)

All inputs must be validated at service layer.

---

### Validation Types

- required fields
- type validation
- enum validation
- range validation

---

### Failure Behavior

- reject operation
- return structured error:
  - code
  - message
  
## 5.2 Audit Coverage Rules (NEW)

The following MUST be logged:

- login attempts (success + failure)
- role changes
- permission changes
- state transitions
- approvals/rejections
- file uploads/deletions
- background task failures

Missing audit entry = system violation

## 6. Background Tasks

Executed via iOS background scheduler:
- carpool recalculation
- inventory variance processing
- media cleanup
- SLA checks ← NEW

Constraints:
- no continuous execution
- battery-aware scheduling

---

## 6.1 Background Execution Rules (NEW)

Tasks run:

- on app launch
- on app foreground
- scheduled intervals (if OS allows)

---

### Retry Rules

- retry up to 3 times
- exponential backoff

---

### Failure Handling

- log failure in AuditLog
- do NOT crash app

## 7. Performance Constraints

- cold start < 1.5s
- memory-safe media handling
- release caches on warning
- no blocking operations on main thread

---

## 8. Non-Negotiable Rules

- no network calls
- no external APIs
- no partial workflows
- no UI-only logic
- all validation in services

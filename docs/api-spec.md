# DealerOps API Specification

**Version:** 1.0  
**Platform:** iOS 15+ / macOS 12+ (offline-first, Core Data persistence)  
**Architecture:** Service layer with repository-backed persistence, role-based access control, site-scoped data isolation

---

## Table of Contents

1. [Common Conventions](#1-common-conventions)
2. [Data Types — Entities](#2-data-types--entities)
3. [Data Types — Enums](#3-data-types--enums)
4. [State Machines](#4-state-machines)
5. [Error Codes](#5-error-codes)
6. [Permission Matrix](#6-permission-matrix)
7. [Service APIs](#7-service-apis)
   - [AuthService](#71-authservice)
   - [SessionService](#72-sessionservice)
   - [UserManagementService](#73-usermanagementservice)
   - [PermissionService](#74-permissionservice)
   - [LeadService](#75-leadservice)
   - [AppointmentService](#76-appointmentservice)
   - [SLAService](#77-slaservice)
   - [NoteService](#78-noteservice)
   - [ReminderService](#79-reminderservice)
   - [InventoryService](#710-inventoryservice)
   - [CarpoolService](#711-carpoolservice)
   - [ExceptionService](#712-exceptionservice)
   - [AppealService](#713-appealservice)
   - [FileService](#714-fileservice)
   - [AuditService](#715-auditservice)
   - [BackgroundTaskService](#716-backgroundtaskservice)

---

## 1. Common Conventions

### Result Type

All service methods that can fail return:

```
ServiceResult<T>  =  Result<T, ServiceError>
```

- `.success(T)` — operation succeeded, payload is `T`
- `.failure(ServiceError)` — operation failed with structured error

### Idempotency

Mutating operations accept an `operationId: UUID`. If the same `operationId` is submitted twice, the second call returns `OP_DUPLICATE` without side effects.

### Site Isolation

All data-bearing entities carry a `siteId: String`. Repository queries and service methods enforce site-scoped access. A user scoped to site `lot-a` cannot read, mutate, or match against records belonging to site `lot-b`.

### Authentication & Authorization Flow

Every service method that accepts `by user: User, site: String` performs:
1. **Role check** — user's role must permit the action on the module (see [Permission Matrix](#6-permission-matrix))
2. **Scope check** — user must hold a valid `PermissionScope` for the given `site` + `functionKey` at the current time (administrators bypass scope checks)
3. **Object-level check** — where applicable (e.g. appeal reviewer ownership)

### Audit Logging

All state-changing operations produce audit log entries via `AuditService.log()`. Audit logs are immutable; deletion marks them as tombstones.

---

## 2. Data Types — Entities

### User

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `username` | `String` | Unique, case-sensitive |
| `passwordHash` | `String` | PBKDF2/SHA-256 |
| `passwordSalt` | `String` | Random per-user |
| `role` | `UserRole` | See enum |
| `biometricEnabled` | `Bool` | Face ID / Touch ID |
| `failedAttempts` | `Int` | Reset on successful login |
| `lastFailedAttempt` | `Date?` | |
| `lockoutUntil` | `Date?` | 30-min lockout after 5 failures |
| `createdAt` | `Date` | |
| `isActive` | `Bool` | Deactivated users cannot log in |

### Lead

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `siteId` | `String` | Site isolation key |
| `leadType` | `LeadType` | |
| `status` | `LeadStatus` | State machine enforced |
| `customerName` | `String` | Encrypted at rest (AES-256) |
| `phone` | `String` | Encrypted at rest, validated E.164-like |
| `vehicleInterest` | `String` | |
| `preferredContactWindow` | `String` | |
| `consentNotes` | `String` | Encrypted at rest |
| `assignedTo` | `UUID?` | User ID of assigned sales associate |
| `createdAt` | `Date` | |
| `updatedAt` | `Date` | |
| `slaDeadline` | `Date?` | Computed from business hours |
| `lastQualifyingAction` | `Date?` | Resets SLA clock |
| `archivedAt` | `Date?` | Set by auto-archive background task |

### Appointment

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `siteId` | `String` | Site isolation key |
| `leadId` | `UUID` | Foreign key to Lead |
| `startTime` | `Date` | |
| `status` | `AppointmentStatus` | State machine enforced |

### PoolOrder

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `siteId` | `String` | Site isolation key |
| `originLat` | `Double` | |
| `originLng` | `Double` | |
| `destinationLat` | `Double` | |
| `destinationLng` | `Double` | |
| `startTime` | `Date` | |
| `endTime` | `Date` | |
| `seatsAvailable` | `Int` | Decremented on match accept |
| `vehicleType` | `String` | |
| `createdBy` | `UUID` | User ID |
| `status` | `PoolOrderStatus` | State machine enforced |

### CarpoolMatch

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `requestOrderId` | `UUID` | Foreign key to PoolOrder |
| `offerOrderId` | `UUID` | Foreign key to PoolOrder |
| `matchScore` | `Double` | 0.0–1.0 composite score |
| `detourMiles` | `Double` | |
| `timeOverlapMinutes` | `Double` | |
| `accepted` | `Bool` | |
| `createdAt` | `Date` | |

### RouteSegment

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `poolOrderId` | `UUID` | Foreign key to PoolOrder |
| `sequence` | `Int` | Ordering index |
| `locationLat` | `Double` | |
| `locationLng` | `Double` | |

### InventoryItem

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `siteId` | `String` | Site isolation key |
| `identifier` | `String` | SKU / VIN, scanner-scannable |
| `expectedQty` | `Int` | |
| `location` | `String` | |
| `custodian` | `String` | |

### CountTask

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `siteId` | `String` | Site isolation key |
| `assignedTo` | `UUID` | User ID of assigned clerk |
| `status` | `CountTaskStatus` | |

### CountBatch

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `siteId` | `String` | Site isolation key |
| `taskId` | `UUID` | Foreign key to CountTask |
| `createdAt` | `Date` | |

### CountEntry

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `siteId` | `String` | Site isolation key |
| `batchId` | `UUID` | Foreign key to CountBatch |
| `itemId` | `UUID` | Foreign key to InventoryItem |
| `countedQty` | `Int` | |
| `countedLocation` | `String` | |
| `countedCustodian` | `String` | |

### Variance

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `siteId` | `String` | Site isolation key |
| `itemId` | `UUID` | Foreign key to InventoryItem |
| `expectedQty` | `Int` | |
| `countedQty` | `Int` | |
| `type` | `VarianceType` | |
| `requiresApproval` | `Bool` | True if abs(delta) >= 5 |
| `approved` | `Bool` | |

### AdjustmentOrder

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `siteId` | `String` | Site isolation key |
| `varianceId` | `UUID` | Foreign key to Variance |
| `approvedBy` | `UUID?` | Admin who approved |
| `createdAt` | `Date` | |
| `status` | `AdjustmentOrderStatus` | |

### ExceptionCase

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `siteId` | `String` | Site isolation key |
| `type` | `ExceptionType` | |
| `sourceId` | `UUID` | Reference to originating entity |
| `reason` | `String` | |
| `status` | `ExceptionCaseStatus` | |
| `createdAt` | `Date` | |

### CheckIn

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `siteId` | `String` | Site isolation key |
| `userId` | `UUID` | |
| `timestamp` | `Date` | |
| `locationLat` | `Double` | |
| `locationLng` | `Double` | |

### Appeal

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `siteId` | `String` | Site isolation key |
| `exceptionId` | `UUID` | Foreign key to ExceptionCase |
| `status` | `AppealStatus` | State machine enforced |
| `reviewerId` | `UUID?` | Assigned compliance reviewer |
| `submittedBy` | `UUID` | User who filed the appeal |
| `reason` | `String` | |
| `resolvedAt` | `Date?` | |

### EvidenceFile

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `siteId` | `String` | Site isolation key |
| `entityId` | `UUID` | Polymorphic FK (Appeal or Lead) |
| `entityType` | `String` | `"Appeal"` or `"Lead"` |
| `filePath` | `String` | Sandbox-local path |
| `fileType` | `EvidenceFileType` | Validated against binary signature |
| `fileSize` | `Int` | Bytes |
| `hash` | `String` | SHA-256 hex digest |
| `createdAt` | `Date` | |
| `pinnedByAdmin` | `Bool` | Pinned files survive lifecycle purge |

### Note

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `entityId` | `UUID` | Polymorphic FK |
| `entityType` | `String` | |
| `content` | `String` | |
| `createdAt` | `Date` | |
| `createdBy` | `UUID` | |

### Tag

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `name` | `String` | Lowercased, trimmed, unique |

### TagAssignment

| Field | Type | Notes |
|-------|------|-------|
| `tagId` | `UUID` | Foreign key to Tag |
| `entityId` | `UUID` | Polymorphic FK |
| `entityType` | `String` | |

### Reminder

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `entityId` | `UUID` | Polymorphic FK |
| `entityType` | `String` | |
| `createdBy` | `UUID` | |
| `dueAt` | `Date` | |
| `status` | `ReminderStatus` | |

### PermissionScope

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `userId` | `UUID` | |
| `site` | `String` | Site key (e.g. `"lot-a"`) |
| `functionKey` | `String` | Module key (e.g. `"leads"`, `"inventory"`) |
| `validFrom` | `Date` | |
| `validTo` | `Date` | |

### BusinessHoursConfig

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `id` | `UUID` | | Primary key |
| `startHour` | `Int` | `9` | 24-hour format |
| `endHour` | `Int` | `17` | 24-hour format |
| `workingDays` | `[Int]` | `[2,3,4,5,6]` | 1=Sun, 2=Mon, ..., 7=Sat |

### AuditLog

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `actorId` | `UUID` | User who performed the action |
| `action` | `String` | Machine-readable action key |
| `entityId` | `UUID` | Affected entity |
| `timestamp` | `Date` | |
| `tombstone` | `Bool` | Soft-delete flag |
| `deletedAt` | `Date?` | |
| `deletedBy` | `UUID?` | |

---

## 3. Data Types — Enums

### UserRole

| Case | Raw Value |
|------|-----------|
| `administrator` | `"administrator"` |
| `salesAssociate` | `"sales_associate"` |
| `inventoryClerk` | `"inventory_clerk"` |
| `complianceReviewer` | `"compliance_reviewer"` |

### LeadType

| Case | Raw Value |
|------|-----------|
| `quoteRequest` | `"quote_request"` |
| `appointment` | `"appointment"` |
| `generalContact` | `"general_contact"` |

### LeadStatus

| Case | Raw Value |
|------|-----------|
| `new` | `"new"` |
| `followUp` | `"follow_up"` |
| `closedWon` | `"closed_won"` |
| `invalid` | `"invalid"` |

### AppointmentStatus

| Case | Raw Value |
|------|-----------|
| `scheduled` | `"scheduled"` |
| `confirmed` | `"confirmed"` |
| `completed` | `"completed"` |
| `canceled` | `"canceled"` |
| `noShow` | `"no_show"` |

### PoolOrderStatus

| Case | Raw Value |
|------|-----------|
| `draft` | `"draft"` |
| `active` | `"active"` |
| `matched` | `"matched"` |
| `completed` | `"completed"` |
| `canceled` | `"canceled"` |
| `expired` | `"expired"` |

### AppealStatus

| Case | Raw Value |
|------|-----------|
| `submitted` | `"submitted"` |
| `underReview` | `"under_review"` |
| `approved` | `"approved"` |
| `denied` | `"denied"` |
| `archived` | `"archived"` |

### CountTaskStatus

| Case | Raw Value |
|------|-----------|
| `pending` | `"pending"` |
| `inProgress` | `"in_progress"` |
| `completed` | `"completed"` |
| `canceled` | `"canceled"` |

### AdjustmentOrderStatus

| Case | Raw Value |
|------|-----------|
| `pending` | `"pending"` |
| `approved` | `"approved"` |
| `executed` | `"executed"` |

### VarianceType

| Case | Raw Value |
|------|-----------|
| `surplus` | `"surplus"` |
| `shortage` | `"shortage"` |
| `locationMismatch` | `"location_mismatch"` |
| `custodianMismatch` | `"custodian_mismatch"` |

### ExceptionType

| Case | Raw Value |
|------|-----------|
| `missedCheckIn` | `"missed_check_in"` |
| `buddyPunching` | `"buddy_punching"` |
| `misidentification` | `"misidentification"` |

### ExceptionCaseStatus

| Case | Raw Value |
|------|-----------|
| `open` | `"open"` |
| `underAppeal` | `"under_appeal"` |
| `resolved` | `"resolved"` |
| `dismissed` | `"dismissed"` |

### ReminderStatus

| Case | Raw Value |
|------|-----------|
| `pending` | `"pending"` |
| `completed` | `"completed"` |
| `canceled` | `"canceled"` |

### EvidenceFileType

| Case | Raw Value | Category | Max Size |
|------|-----------|----------|----------|
| `jpg` | `"jpg"` | Image | 10 MB |
| `png` | `"png"` | Image | 10 MB |
| `mp4` | `"mp4"` | Video | 50 MB |

### PermissionModule

| Case | Raw Value |
|------|-----------|
| `leads` | `"leads"` |
| `inventory` | `"inventory"` |
| `carpool` | `"carpool"` |
| `appeals` | `"appeals"` |
| `exceptions` | `"exceptions"` |
| `admin` | `"admin"` |

### PermissionLevel

| Case | Raw Value |
|------|-----------|
| `none` | `"none"` |
| `view` | `"view"` |
| `read` | `"read"` |
| `create` | `"create"` |
| `crud` | `"crud"` |
| `review` | `"review"` |
| `full` | `"full"` |

---

## 4. State Machines

### Lead Status Transitions

```
new ──→ followUp ──→ closedWon
                 ──→ invalid

Admin-only reversals:
  closedWon ──→ followUp
  invalid   ──→ followUp
```

| From | To | Admin Required |
|------|----|----------------|
| `new` | `followUp` | No |
| `followUp` | `closedWon` | No |
| `followUp` | `invalid` | No |
| `invalid` | `followUp` | **Yes** |
| `closedWon` | `followUp` | **Yes** |

### Appointment Status Transitions

```
scheduled ──→ confirmed ──→ completed
          ──→ canceled      ──→ canceled
          ──→ noShow        ──→ noShow
```

| From | To | Notes |
|------|----|-------|
| `scheduled` | `confirmed` | |
| `scheduled` | `canceled` | |
| `scheduled` | `noShow` | |
| `confirmed` | `completed` | |
| `confirmed` | `canceled` | |
| `confirmed` | `noShow` | |

### Pool Order Status Transitions

```
draft ──→ active ──→ matched ──→ completed
                 ──→ canceled
         * ──→ expired  (any state, background task)
```

| From | To | Notes |
|------|----|-------|
| `draft` | `active` | |
| `active` | `matched` | Auto when all seats filled |
| `matched` | `completed` | |
| `active` | `canceled` | |
| `*` | `expired` | Background task only |

### Appeal Status Transitions

```
submitted ──→ underReview ──→ approved ──→ archived
                          ──→ denied   ──→ archived
```

| From | To | Notes |
|------|----|-------|
| `submitted` | `underReview` | Assigns reviewer |
| `underReview` | `approved` | Resolves linked ExceptionCase |
| `underReview` | `denied` | Reopens linked ExceptionCase |
| `approved` | `archived` | |
| `denied` | `archived` | |

---

## 5. Error Codes

### Authentication

| Code | Constant | Message |
|------|----------|---------|
| `AUTH_LOCKED` | `accountLocked(until:)` | Account locked until {date} |
| `AUTH_INVALID` | `invalidCredentials` | Invalid username or password |
| `AUTH_INACTIVE` | `accountInactive` | Account is deactivated |
| `AUTH_BIO_DISABLED` | `biometricNotEnabled` | Biometric authentication not enabled |
| `AUTH_BIO_UNAVAIL` | `biometricUnavailable` | Biometric authentication unavailable on this device |
| `SESSION_EXPIRED` | `sessionExpired` | Session expired, re-authentication required |
| `AUTH_BOOTSTRAP_DONE` | `bootstrapAlreadyComplete` | Bootstrap already completed |
| `AUTH_PASS_REQUIRED` | `passwordReEntryRequired` | Password re-entry required for this action |

### Password Validation

| Code | Constant | Message |
|------|----------|---------|
| `PASS_SHORT` | `passwordTooShort` | Password must be at least 12 characters |
| `PASS_NO_UPPER` | `passwordMissingUppercase` | Password must contain at least 1 uppercase letter |
| `PASS_NO_LOWER` | `passwordMissingLowercase` | Password must contain at least 1 lowercase letter |
| `PASS_NO_NUMBER` | `passwordMissingNumber` | Password must contain at least 1 number |

### Authorization

| Code | Constant | Message |
|------|----------|---------|
| `PERM_DENIED` | `permissionDenied` | Permission denied |
| `SCOPE_DENIED` | `scopeDenied` | Access denied: no valid scope |
| `PERM_ADMIN_REQ` | `adminRequired` | Administrator role required |

### Validation

| Code | Constant | Message |
|------|----------|---------|
| `VAL_REQUIRED` | `missingRequiredField` | Required field is missing |
| `VAL_ENUM` | `invalidEnumValue` | Invalid enum value |
| `STATE_INVALID` | `invalidTransition` | Invalid state transition |
| `VAL_FAILED` | `validationFailed(field, reason)` | {field}: {reason} |

### Entity

| Code | Constant | Message |
|------|----------|---------|
| `ENTITY_NOT_FOUND` | `entityNotFound` | Entity not found |
| `ENTITY_DUPLICATE` | `duplicateEntity` | Entity already exists |
| `OP_DUPLICATE` | `duplicateOperation` | Duplicate operation ignored |

### File

| Code | Constant | Message |
|------|----------|---------|
| `FILE_TOO_LARGE` | `fileTooLarge` | File exceeds size limit |
| `FILE_FORMAT` | `invalidFileFormat` | Invalid file format |
| `FILE_NOT_FOUND` | `fileNotFound` | File not found |

### Inventory

| Code | Constant | Message |
|------|----------|---------|
| `INV_APPROVAL_REQ` | `approvalRequired` | Admin approval required for this variance |
| `INV_SCAN_INVALID` | `invalidScanInput` | Scanner input does not match any inventory item |

### Carpool

| Code | Constant | Message |
|------|----------|---------|
| `POOL_NO_SEATS` | `noSeatsAvailable` | No seats available |
| `POOL_DETOUR` | `detourExceedsThreshold` | Detour exceeds threshold |
| `POOL_TIME` | `insufficientTimeOverlap` | Insufficient time overlap |

---

## 6. Permission Matrix

| Role | leads | inventory | carpool | appeals | exceptions | admin |
|------|-------|-----------|---------|---------|------------|-------|
| **Administrator** | full | full | full | full | full | full |
| **Sales Associate** | crud | none | view | create | read | none |
| **Inventory Clerk** | none | crud | none | none | none | none |
| **Compliance Reviewer** | read | read | none | review | review | none |

**Permission levels and what they grant:**

| Level | read | create | update | delete | review | approve | deny |
|-------|------|--------|--------|--------|--------|---------|------|
| `none` | - | - | - | - | - | - | - |
| `view` | yes | - | - | - | - | - | - |
| `read` | yes | - | - | - | - | - | - |
| `create` | yes | yes | - | - | - | - | - |
| `crud` | yes | yes | yes | yes | - | - | - |
| `review` | yes | yes | yes | - | yes | yes | yes |
| `full` | yes | yes | yes | yes | yes | yes | yes |

**Scope enforcement:** Non-admin users must also hold a `PermissionScope` record that matches the requested `site` + `functionKey` and whose `validFrom..validTo` window contains the current date. Administrators bypass scope checks.

---

## 7. Service APIs

### 7.1 AuthService

Bootstrap and credential-based authentication.

---

#### `bootstrap`

Create the first administrator account. Can only be called once.

```
bootstrap(username: String, password: String) -> ServiceResult<User>
```

| Parameter | Type | Required | Notes |
|-----------|------|----------|-------|
| `username` | `String` | Yes | Must be non-empty |
| `password` | `String` | Yes | Must pass password policy |

**Returns:** The created admin `User`.

**Errors:** `AUTH_BOOTSTRAP_DONE`, `VAL_FAILED`, `PASS_SHORT`, `PASS_NO_UPPER`, `PASS_NO_LOWER`, `PASS_NO_NUMBER`

---

#### `login`

Authenticate with username and password.

```
login(username: String, password: String, now: Date = Date()) -> ServiceResult<User>
```

| Parameter | Type | Required | Notes |
|-----------|------|----------|-------|
| `username` | `String` | Yes | |
| `password` | `String` | Yes | |
| `now` | `Date` | No | Defaults to current time |

**Returns:** Authenticated `User`.

**Errors:** `AUTH_INVALID`, `AUTH_INACTIVE`, `AUTH_LOCKED`

**Side effects:** Increments `failedAttempts` on failure. Locks account for 30 minutes after 5 consecutive failures. Resets `failedAttempts` on success.

---

#### `enableBiometric`

Enable biometric (Face ID / Touch ID) for a user. Requires password re-entry.

```
enableBiometric(userId: UUID, password: String) -> ServiceResult<Void>
```

**Errors:** `ENTITY_NOT_FOUND`, `AUTH_INVALID`, `AUTH_BIO_UNAVAIL`

---

#### `disableBiometric`

Disable biometric for a user. Requires password re-entry.

```
disableBiometric(userId: UUID, password: String) -> ServiceResult<Void>
```

**Errors:** `ENTITY_NOT_FOUND`, `AUTH_INVALID`

---

#### `validatePasswordPolicy`

Check if a password meets policy requirements.

```
validatePasswordPolicy(_ password: String) -> ServiceError?
```

**Returns:** `nil` if valid, or the first violated policy rule as a `ServiceError`.

**Policy:** Minimum 12 characters, at least 1 uppercase, 1 lowercase, 1 digit.

---

### 7.2 SessionService

In-memory session management with 5-minute inactivity timeout.

---

#### `startSession`

```
startSession(user: User) -> Void
```

---

#### `isSessionValid`

```
isSessionValid() -> Bool
```

Returns `false` if no session or if last activity was more than 5 minutes ago.

---

#### `requiresReAuthentication`

```
requiresReAuthentication() -> Bool
```

Returns `true` if session has expired (requires password or biometric re-entry).

---

#### `recordActivity`

```
recordActivity() -> Void
```

Updates the last-activity timestamp. Call on each user interaction.

---

#### `endSession`

```
endSession() -> Void
```

Clears current user and timestamps.

---

#### `onAppForeground`

```
onAppForeground() -> Bool
```

**Returns:** `true` if session is still valid, `false` if re-authentication is required.

---

#### `onAppBackground`

```
onAppBackground() -> Void
```

Records the time the app entered background.

---

#### Properties

| Property | Type | Notes |
|----------|------|-------|
| `currentUser` | `User?` | Currently authenticated user |
| `lastActiveTimestamp` | `Date?` | Last recorded activity |

---

### 7.3 UserManagementService

User CRUD, role management, scope management. **Admin-only** for all operations.

---

#### `createUser`

```
createUser(by: User, username: String, password: String, role: UserRole, operationId: UUID) -> ServiceResult<User>
```

**Errors:** `PERM_ADMIN_REQ`, `ENTITY_DUPLICATE`, `VAL_FAILED`, `PASS_*`, `OP_DUPLICATE`

---

#### `updateRole`

```
updateRole(by: User, userId: UUID, newRole: UserRole, operationId: UUID) -> ServiceResult<User>
```

**Errors:** `PERM_ADMIN_REQ`, `ENTITY_NOT_FOUND`, `OP_DUPLICATE`

---

#### `deactivateUser`

```
deactivateUser(by: User, userId: UUID, operationId: UUID) -> ServiceResult<Void>
```

**Errors:** `PERM_ADMIN_REQ`, `ENTITY_NOT_FOUND`, `OP_DUPLICATE`

---

#### `listUsers`

```
listUsers(by: User) -> ServiceResult<[User]>
```

**Errors:** `PERM_ADMIN_REQ`

---

#### `findUserByUsername`

```
findUserByUsername(by: User, username: String) -> ServiceResult<User?>
```

**Errors:** `PERM_ADMIN_REQ`

---

#### `createScope`

```
createScope(by: User, userId: UUID, site: String, functionKey: String, validFrom: Date, validTo: Date) -> ServiceResult<PermissionScope>
```

**Errors:** `PERM_ADMIN_REQ`

---

#### `deleteScope`

```
deleteScope(by: User, scopeId: UUID) -> ServiceResult<Void>
```

**Errors:** `PERM_ADMIN_REQ`, `ENTITY_NOT_FOUND`

---

#### `listAllScopes`

```
listAllScopes(by: User) -> ServiceResult<[PermissionScope]>
```

**Errors:** `PERM_ADMIN_REQ`

---

#### `resetLockout`

```
resetLockout(by: User, userId: UUID, operationId: UUID) -> ServiceResult<Void>
```

**Errors:** `PERM_ADMIN_REQ`, `ENTITY_NOT_FOUND`, `OP_DUPLICATE`

---

### 7.4 PermissionService

Central authorization enforcement.

---

#### `validateAccess`

Role-based permission check.

```
validateAccess(user: User, action: String, module: PermissionModule) -> ServiceResult<Void>
```

**Errors:** `AUTH_INACTIVE`, `PERM_DENIED`

---

#### `validateScope`

Time-bounded site+function scope check. Administrators bypass.

```
validateScope(user: User, site: String, functionKey: String, at: Date = Date()) -> ServiceResult<Void>
```

**Errors:** `AUTH_INACTIVE`, `SCOPE_DENIED`

---

#### `validateFullAccess`

Combined role + scope check (calls both of the above).

```
validateFullAccess(user: User, action: String, module: PermissionModule, site: String, functionKey: String, at: Date = Date()) -> ServiceResult<Void>
```

**Errors:** `AUTH_INACTIVE`, `PERM_DENIED`, `SCOPE_DENIED`

---

#### `requireAdmin`

```
requireAdmin(user: User) -> ServiceResult<Void>
```

**Errors:** `AUTH_INACTIVE`, `PERM_ADMIN_REQ`

---

### 7.5 LeadService

Lead lifecycle management with SLA enforcement.

**Module:** `leads` | **Function key:** `"leads"`

---

#### `createLead`

```
createLead(by: User, site: String, input: CreateLeadInput, operationId: UUID) -> ServiceResult<Lead>
```

**Input struct:**

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `leadType` | `LeadType` | Yes | |
| `customerName` | `String` | Yes | Non-empty |
| `phone` | `String` | Yes | Validated format |
| `vehicleInterest` | `String` | Yes | |
| `preferredContactWindow` | `String` | Yes | |
| `consentNotes` | `String` | Yes | |

**Returns:** Created `Lead` with status `new`, computed `slaDeadline`.

**Errors:** `PERM_DENIED`, `SCOPE_DENIED`, `VAL_FAILED`, `OP_DUPLICATE`

---

#### `updateLeadStatus`

```
updateLeadStatus(by: User, site: String, leadId: UUID, newStatus: LeadStatus, operationId: UUID) -> ServiceResult<Lead>
```

**Errors:** `PERM_DENIED`, `SCOPE_DENIED`, `ENTITY_NOT_FOUND`, `STATE_INVALID`, `PERM_ADMIN_REQ` (for admin-only transitions), `OP_DUPLICATE`

**Side effects:** Resets SLA deadline on qualifying transitions. Logs audit entry.

---

#### `assignLead`

```
assignLead(by: User, site: String, leadId: UUID, assigneeId: UUID, operationId: UUID) -> ServiceResult<Lead>
```

**Errors:** `PERM_DENIED`, `SCOPE_DENIED`, `ENTITY_NOT_FOUND`, `OP_DUPLICATE`

---

#### `archiveClosedLeads`

System-initiated. Archives leads in terminal status older than threshold.

```
archiveClosedLeads(olderThan date: Date) -> Int
```

**Returns:** Count of archived leads.

---

#### `findById`

```
findById(by: User, site: String, _ id: UUID) -> ServiceResult<Lead?>
```

---

#### `findByStatus`

```
findByStatus(by: User, site: String, _ status: LeadStatus) -> ServiceResult<[Lead]>
```

---

#### `findByAssignedTo`

```
findByAssignedTo(by: User, site: String, _ userId: UUID) -> ServiceResult<[Lead]>
```

---

#### `findAllNonArchived`

```
findAllNonArchived(by: User, site: String) -> ServiceResult<[Lead]>
```

---

#### Static Utilities

| Method | Signature | Notes |
|--------|-----------|-------|
| `normalizePhone` | `(_ phone: String) -> String` | Strips non-digits, adds +1 prefix |
| `isValidPhone` | `(_ phone: String) -> Bool` | 10–15 digits after normalization |
| `maskPhone` | `(_ phone: String) -> String` | Shows last 4 digits only |

---

### 7.6 AppointmentService

Appointment scheduling with lead ownership validation.

**Module:** `leads` | **Function key:** `"leads"`

---

#### `createAppointment`

```
createAppointment(by: User, site: String, leadId: UUID, startTime: Date, operationId: UUID) -> ServiceResult<Appointment>
```

**Validation:** Lead must exist, belong to the site, and be owned by the user (or user is admin).

**Errors:** `PERM_DENIED`, `SCOPE_DENIED`, `ENTITY_NOT_FOUND`, `OP_DUPLICATE`

---

#### `updateStatus`

```
updateStatus(by: User, site: String, appointmentId: UUID, newStatus: AppointmentStatus, operationId: UUID) -> ServiceResult<Appointment>
```

**Errors:** `PERM_DENIED`, `SCOPE_DENIED`, `ENTITY_NOT_FOUND`, `STATE_INVALID`, `OP_DUPLICATE`

---

#### `getUnconfirmedWithinSLA`

Returns appointments that are still `scheduled` and whose `startTime` is within 30 minutes.

```
getUnconfirmedWithinSLA(by: User, site: String, now: Date = Date()) -> ServiceResult<[Appointment]>
```

---

#### `getUnconfirmedWithinSLAForSystem`

System-initiated variant (no auth check).

```
getUnconfirmedWithinSLAForSystem(now: Date = Date()) -> [Appointment]
```

---

#### `findById`

```
findById(by: User, site: String, _ id: UUID) -> ServiceResult<Appointment?>
```

---

#### `findByLeadId`

```
findByLeadId(by: User, site: String, _ leadId: UUID) -> ServiceResult<[Appointment]>
```

---

### 7.7 SLAService

Business-hours-aware SLA deadline computation.

---

#### `computeLeadDeadline`

Compute an SLA deadline from a start date using business hours configuration.

```
computeLeadDeadline(from startDate: Date) -> Date
```

**Returns:** Deadline `Date` (4 business hours from start).

---

#### `resetLeadSLA`

Reset a lead's SLA deadline based on a new qualifying action.

```
resetLeadSLA(leadId: UUID, actionDate: Date) -> Void
```

---

#### `computeAppointmentSLADeadline`

```
computeAppointmentSLADeadline(appointmentStartTime: Date) -> Date
```

**Returns:** 30 minutes before `appointmentStartTime` (confirmation deadline).

---

#### `checkViolations`

Scan for leads and appointments that have exceeded their SLA deadlines.

```
checkViolations(now: Date = Date()) -> (leadViolations: [UUID], appointmentViolations: [UUID])
```

**Returns:** Tuple of lead IDs and appointment IDs that are in violation.

---

#### `addBusinessHours`

Add N business hours to a date, skipping non-working hours and non-working days.

```
addBusinessHours(_ hours: Int, to startDate: Date, config: BusinessHoursConfig) -> Date
```

---

### 7.8 NoteService

Notes and tags for any entity.

**Module:** `leads` | **Function key:** `"leads"`

---

#### `addNote`

```
addNote(by: User, site: String, entityId: UUID, entityType: String, content: String, operationId: UUID) -> ServiceResult<Note>
```

**Errors:** `PERM_DENIED`, `SCOPE_DENIED`, `VAL_FAILED` (empty content), `OP_DUPLICATE`

---

#### `getNotesForEntity`

```
getNotesForEntity(by: User, site: String, entityId: UUID, entityType: String) -> ServiceResult<[Note]>
```

---

#### `getOrCreateTag`

Get a tag by name, creating it if it doesn't exist. Tag names are lowercased and trimmed.

```
getOrCreateTag(name: String) -> ServiceResult<Tag>
```

---

#### `assignTag`

```
assignTag(by: User, site: String, tagId: UUID, entityId: UUID, entityType: String) -> ServiceResult<Void>
```

---

#### `removeTag`

```
removeTag(by: User, site: String, tagId: UUID, entityId: UUID, entityType: String) -> ServiceResult<Void>
```

---

#### `getTagsForEntity`

```
getTagsForEntity(by: User, site: String, entityId: UUID, entityType: String) -> ServiceResult<[TagAssignment]>
```

---

### 7.9 ReminderService

Reminders attached to any entity.

**Module:** `leads` | **Function key:** `"leads"`

---

#### `createReminder`

```
createReminder(by: User, site: String, entityId: UUID, entityType: String, dueAt: Date, operationId: UUID) -> ServiceResult<Reminder>
```

**Errors:** `PERM_DENIED`, `SCOPE_DENIED`, `OP_DUPLICATE`

---

#### `completeReminder`

```
completeReminder(by: User, site: String, reminderId: UUID, operationId: UUID) -> ServiceResult<Reminder>
```

---

#### `cancelReminder`

```
cancelReminder(by: User, site: String, reminderId: UUID, operationId: UUID) -> ServiceResult<Reminder>
```

---

#### `getDueReminders`

System-initiated. Returns all pending reminders with `dueAt <= now`.

```
getDueReminders(now: Date = Date()) -> [Reminder]
```

---

#### `findByEntity`

```
findByEntity(by: User, site: String, entityId: UUID, entityType: String) -> ServiceResult<[Reminder]>
```

---

### 7.10 InventoryService

Inventory counting, variance detection, and adjustment workflow.

**Module:** `inventory` | **Function key:** `"inventory"`

---

#### `createCountTask`

```
createCountTask(by: User, site: String, assignedTo: UUID, operationId: UUID) -> ServiceResult<CountTask>
```

---

#### `createCountBatch`

```
createCountBatch(by: User, site: String, taskId: UUID, operationId: UUID) -> ServiceResult<CountBatch>
```

---

#### `recordCountEntry`

```
recordCountEntry(by: User, site: String, batchId: UUID, itemId: UUID, countedQty: Int, countedLocation: String, countedCustodian: String, operationId: UUID) -> ServiceResult<CountEntry>
```

---

#### `lookupByScanner`

Resolve a scanner input (barcode / VIN) to an inventory item.

```
lookupByScanner(by: User, site: String, identifier: String) -> ServiceResult<InventoryItem>
```

**Errors:** `PERM_DENIED`, `SCOPE_DENIED`, `INV_SCAN_INVALID`

---

#### `computeVariances`

Compare counted entries in a batch against expected quantities and generate variance records.

```
computeVariances(by: User, site: String, forBatchId batchId: UUID) -> ServiceResult<[Variance]>
```

**Variance types detected:**
- `surplus` — countedQty > expectedQty
- `shortage` — countedQty < expectedQty
- `locationMismatch` — countedLocation != item.location
- `custodianMismatch` — countedCustodian != item.custodian

**Auto-approval:** Variances with `abs(expectedQty - countedQty) < 5` are auto-approved. Larger variances require admin approval.

---

#### `approveVariance`

Admin-only. Approve a variance that requires manual approval.

```
approveVariance(by: User, site: String, varianceId: UUID, operationId: UUID) -> ServiceResult<AdjustmentOrder>
```

**Returns:** A new `AdjustmentOrder` in `pending` status.

**Errors:** `PERM_ADMIN_REQ`, `ENTITY_NOT_FOUND`, `INV_APPROVAL_REQ` (already approved), `OP_DUPLICATE`

---

#### `executeAdjustmentOrder`

Admin-only. Execute an approved adjustment order, updating the inventory item's `expectedQty`.

```
executeAdjustmentOrder(by: User, site: String, orderId: UUID, operationId: UUID) -> ServiceResult<AdjustmentOrder>
```

**Side effects:** Updates `InventoryItem.expectedQty` to match the variance's `countedQty`.

**Errors:** `PERM_ADMIN_REQ`, `ENTITY_NOT_FOUND`, `OP_DUPLICATE`

---

#### `findAllTasks`

```
findAllTasks(by: User, site: String) -> ServiceResult<[CountTask]>
```

---

#### `findAllItems`

```
findAllItems(by: User, site: String) -> ServiceResult<[InventoryItem]>
```

---

#### `findPendingVariances`

```
findPendingVariances(by: User, site: String) -> ServiceResult<[Variance]>
```

---

#### `findApprovedOrders`

```
findApprovedOrders(by: User, site: String) -> ServiceResult<[AdjustmentOrder]>
```

---

#### `computeDeferredVariances`

System-initiated. Process unprocessed batches in bulk.

```
computeDeferredVariances() -> (batchesProcessed: Int, variancesFound: Int)
```

---

### 7.11 CarpoolService

Pool order lifecycle, Haversine-based matching, seat locking.

**Module:** `carpool` | **Function key:** `"carpool"`

---

#### `createPoolOrder`

```
createPoolOrder(by: User, site: String, input: CreatePoolOrderInput, operationId: UUID) -> ServiceResult<PoolOrder>
```

**Input struct:**

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `originLat` | `Double` | Yes | |
| `originLng` | `Double` | Yes | |
| `destinationLat` | `Double` | Yes | |
| `destinationLng` | `Double` | Yes | |
| `startTime` | `Date` | Yes | |
| `endTime` | `Date` | Yes | |
| `seatsAvailable` | `Int` | Yes | Must be > 0 |
| `vehicleType` | `String` | Yes | |

**Returns:** Created `PoolOrder` with status `draft`.

---

#### `activateOrder`

Transition order from `draft` to `active`.

```
activateOrder(by: User, site: String, orderId: UUID, operationId: UUID) -> ServiceResult<PoolOrder>
```

**Errors:** `ENTITY_NOT_FOUND` (includes cross-site), `STATE_INVALID`, `OP_DUPLICATE`

---

#### `computeMatches`

Compute candidate matches for an active order using Haversine distance.

```
computeMatches(by: User, site: String, for orderId: UUID) -> ServiceResult<[CarpoolMatch]>
```

**Matching criteria (all must pass):**
- Candidate is `active` and on the **same site**
- Time overlap >= 15 minutes
- Pickup distance <= `pickupRadiusMiles` (default 2.0)
- Detour <= `min(10% of route, 1.5 miles)`
- Candidate has available seats

**Scoring formula:**
```
matchScore = (routeOverlapScore * 0.5) + (timeFitScore * 0.3) - (detourPenalty * 0.2)
```

**Returns:** Matches sorted by score descending. Matches are persisted.

---

#### `acceptMatch`

Accept a match, locking a seat on the offer order.

```
acceptMatch(by: User, site: String, matchId: UUID, operationId: UUID) -> ServiceResult<CarpoolMatch>
```

**Side effects:**
- Decrements `offerOrder.seatsAvailable`
- If seats reach 0, transitions offer order to `matched`
- Transitions request order to `matched`

**Errors:** `ENTITY_NOT_FOUND`, `OP_DUPLICATE`, `POOL_NO_SEATS`

---

#### `completeOrder`

```
completeOrder(by: User, site: String, orderId: UUID, operationId: UUID) -> ServiceResult<PoolOrder>
```

**Errors:** `ENTITY_NOT_FOUND`, `STATE_INVALID`, `OP_DUPLICATE`

---

#### `expireStaleOrders`

System-initiated. Expire active orders whose `endTime` has passed.

```
expireStaleOrders(now: Date = Date()) -> Int
```

**Returns:** Count of expired orders.

---

#### `computeDeferredMatches`

System-initiated. Compute matches for all eligible active orders across all sites (candidates are site-scoped per order).

```
computeDeferredMatches(now: Date = Date()) -> (ordersProcessed: Int, matchesFound: Int)
```

---

#### `findAllOrders`

Returns orders for the given site. Admins see all; others see own orders + active orders.

```
findAllOrders(by: User, site: String) -> ServiceResult<[PoolOrder]>
```

---

#### `findOrderById`

```
findOrderById(by: User, site: String, _ orderId: UUID) -> ServiceResult<PoolOrder?>
```

---

#### `findMatchesByOrderId`

```
findMatchesByOrderId(by: User, site: String, _ orderId: UUID) -> ServiceResult<[CarpoolMatch]>
```

**Errors:** `ENTITY_NOT_FOUND` (if order doesn't belong to site)

---

#### Haversine Distance

```
static haversineDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double
```

**Returns:** Great-circle distance in **miles**.

---

### 7.12 ExceptionService

Compliance exception detection and manual exception creation.

**Module:** `exceptions` | **Function key:** `"exceptions"`

---

#### `recordCheckIn`

Record a location check-in for the authenticated user.

```
recordCheckIn(by: User, site: String, locationLat: Double, locationLng: Double, operationId: UUID) -> ServiceResult<CheckIn>
```

---

#### `detectMissedCheckIns`

Detect if a user failed to check in within 30 minutes of expected time.

```
detectMissedCheckIns(by: User, site: String, userId: UUID, expectedTime: Date, now: Date = Date()) -> ServiceResult<[ExceptionCase]>
```

**Returns:** Created `ExceptionCase` records (type `missedCheckIn`), or empty if check-in was on time.

---

#### `detectBuddyPunching`

Detect two different users checking in at the same location within 30 seconds.

```
detectBuddyPunching(by: User, site: String, inTimeRange start: Date, end: Date) -> ServiceResult<[ExceptionCase]>
```

**Returns:** Created `ExceptionCase` records (type `buddyPunching`).

---

#### `detectMisidentification`

Detect a single user checking in at locations 15+ miles apart within 5 minutes.

```
detectMisidentification(by: User, site: String, userId: UUID, inTimeRange start: Date, end: Date) -> ServiceResult<[ExceptionCase]>
```

**Returns:** Created `ExceptionCase` records (type `misidentification`).

---

#### `runDetectionCycle`

System-initiated. Run buddy punching and misidentification detection for the last hour.

```
runDetectionCycle(now: Date = Date()) -> (buddyPunching: Int, misidentification: Int)
```

---

#### `createException`

Manually create an exception case.

```
createException(by: User, site: String, type: ExceptionType, sourceId: UUID, reason: String, operationId: UUID) -> ServiceResult<ExceptionCase>
```

---

#### `findById`

```
findById(by: User, site: String, _ id: UUID) -> ServiceResult<ExceptionCase?>
```

---

#### `findByStatus`

```
findByStatus(by: User, site: String, _ status: ExceptionCaseStatus) -> ServiceResult<[ExceptionCase]>
```

---

### 7.13 AppealService

Appeal lifecycle for exception cases.

**Module:** `appeals` | **Function key:** `"appeals"`

---

#### `submitAppeal`

Submit an appeal against an exception case. Updates exception status to `underAppeal`.

```
submitAppeal(by: User, site: String, exceptionId: UUID, reason: String, operationId: UUID) -> ServiceResult<Appeal>
```

**Validation:**
- Exception must exist and belong to the site
- No active appeal (status `submitted` or `underReview`) may exist for the same exception
- Reason must be non-empty

**Errors:** `PERM_DENIED`, `SCOPE_DENIED`, `ENTITY_NOT_FOUND`, `ENTITY_DUPLICATE` (active appeal exists), `VAL_FAILED`, `OP_DUPLICATE`

---

#### `startReview`

Transition appeal from `submitted` to `underReview`. Assigns the reviewer.

```
startReview(by: User, site: String, appealId: UUID, operationId: UUID) -> ServiceResult<Appeal>
```

**Errors:** `PERM_DENIED`, `SCOPE_DENIED`, `ENTITY_NOT_FOUND`, `STATE_INVALID`, `OP_DUPLICATE`

---

#### `approveAppeal`

Approve an appeal. Transitions linked exception to `resolved`.

```
approveAppeal(by: User, site: String, appealId: UUID, operationId: UUID) -> ServiceResult<Appeal>
```

**Authorization:** Only the assigned reviewer or an administrator can approve.

**Errors:** `PERM_DENIED`, `SCOPE_DENIED`, `ENTITY_NOT_FOUND`, `APPEAL_NOT_ASSIGNED`, `STATE_INVALID`, `OP_DUPLICATE`

---

#### `denyAppeal`

Deny an appeal. Transitions linked exception back to `open`.

```
denyAppeal(by: User, site: String, appealId: UUID, operationId: UUID) -> ServiceResult<Appeal>
```

**Authorization:** Only the assigned reviewer or an administrator can deny.

**Errors:** `PERM_DENIED`, `SCOPE_DENIED`, `ENTITY_NOT_FOUND`, `APPEAL_NOT_ASSIGNED`, `STATE_INVALID`, `OP_DUPLICATE`

---

#### `archiveAppeal`

Archive a resolved (approved or denied) appeal.

```
archiveAppeal(by: User, site: String, appealId: UUID, operationId: UUID) -> ServiceResult<Appeal>
```

**Errors:** `PERM_DENIED`, `SCOPE_DENIED`, `ENTITY_NOT_FOUND`, `STATE_INVALID`, `OP_DUPLICATE`

---

#### `findById`

```
findById(by: User, site: String, _ id: UUID) -> ServiceResult<Appeal?>
```

---

#### `findByExceptionId`

```
findByExceptionId(by: User, site: String, _ exceptionId: UUID) -> ServiceResult<[Appeal]>
```

---

#### `findByStatus`

Returns appeals filtered by status. Admins and compliance reviewers see all; others see only their own submissions.

```
findByStatus(by: User, site: String, _ status: AppealStatus) -> ServiceResult<[Appeal]>
```

---

### 7.14 FileService

Evidence file upload, validation, watermarking, and lifecycle management.

**Module:** Determined by `entityType` — `appeals` for Appeal evidence, `leads` for Lead evidence.

---

#### `uploadFile`

Upload and validate a file. Computes SHA-256 hash and stores in app sandbox.

```
uploadFile(by: User, site: String, entityId: UUID, entityType: String, data: Data, fileType: EvidenceFileType, operationId: UUID) -> ServiceResult<EvidenceFile>
```

**Validation pipeline:**
1. **Format check** — `fileType` must be `.jpg`, `.png`, or `.mp4`
2. **Binary signature validation** — file header bytes must match declared type:
   - JPG: bytes `[0..2]` = `FF D8 FF`
   - PNG: bytes `[0..7]` = `89 50 4E 47 0D 0A 1A 0A`
   - MP4: bytes `[4..7]` = `66 74 79 70` (`"ftyp"`)
3. **Size check** — images <= 10 MB, video <= 50 MB
4. **SHA-256 fingerprint** — computed and stored

**Errors:** `PERM_DENIED`, `SCOPE_DENIED`, `FILE_FORMAT`, `FILE_TOO_LARGE`, `OP_DUPLICATE`

---

#### `getWatermarkInfo`

Get watermark metadata for display overlay. Original file is not modified.

```
getWatermarkInfo(by: User, site: String, for fileId: UUID) -> ServiceResult<WatermarkResult>
```

**WatermarkResult:**

| Field | Type | Notes |
|-------|------|-------|
| `originalPath` | `String` | Sandbox file path |
| `watermarkText` | `String` | `"DealerOps \u{2022} Confidential"` |
| `enabled` | `Bool` | Admin-configurable, default `true` |

---

#### `pinFile`

Admin-only. Pin a file to prevent lifecycle purge.

```
pinFile(by: User, site: String, fileId: UUID, operationId: UUID) -> ServiceResult<EvidenceFile>
```

**Errors:** `PERM_ADMIN_REQ`, `FILE_NOT_FOUND`, `OP_DUPLICATE`

---

#### `deleteFile`

Delete a file from sandbox and database.

```
deleteFile(by: User, site: String, fileId: UUID, operationId: UUID) -> ServiceResult<Void>
```

**Errors:** `FILE_NOT_FOUND`, `PERM_DENIED`, `OP_DUPLICATE`

---

#### `purgeRejectedAppealMedia`

System-initiated. Delete evidence files linked to denied appeals older than threshold, unless pinned.

```
purgeRejectedAppealMedia(olderThan date: Date) -> Int
```

**Purge criteria (all must be true):**
1. `entityType == "Appeal"`
2. Linked appeal has status `denied`
3. File `createdAt` < threshold date
4. `pinnedByAdmin == false`

**Returns:** Count of purged files.

---

#### `findByEntity`

```
findByEntity(by: User, site: String, entityId: UUID, entityType: String) -> ServiceResult<[EvidenceFile]>
```

**Authorization:** For appeal evidence, additionally checks that user is the submitter, assigned reviewer, or admin.

---

#### `findById`

```
findById(by: User, site: String, _ id: UUID) -> ServiceResult<EvidenceFile?>
```

---

#### `sha256`

Compute SHA-256 hex digest of data.

```
sha256(data: Data) -> String
```

**Returns:** 64-character lowercase hex string.

---

### 7.15 AuditService

Immutable audit trail with soft-delete (tombstone) support.

---

#### `log`

Create an audit log entry. Called internally by all services on state changes.

```
log(actorId: UUID, action: String, entityId: UUID) -> Void
```

---

#### `deleteLog`

Soft-delete an audit log (marks as tombstone). Does not physically remove.

```
deleteLog(logId: UUID, deletedBy actorId: UUID) -> ServiceResult<Void>
```

---

#### `purgeOldTombstones`

Physically remove tombstoned logs older than the given date (1-year retention policy).

```
purgeOldTombstones(olderThan date: Date) -> Int
```

**Returns:** Count of purged entries.

---

#### `logsForEntity`

```
logsForEntity(_ entityId: UUID) -> [AuditLog]
```

Returns non-tombstoned logs.

---

#### `logsForActor`

```
logsForActor(_ actorId: UUID) -> [AuditLog]
```

Returns non-tombstoned logs.

---

#### `allLogs`

```
allLogs() -> [AuditLog]
```

---

### Audit Action Keys

| Action | Triggered By |
|--------|-------------|
| `lead_created` | LeadService.createLead |
| `lead_status_changed` | LeadService.updateLeadStatus |
| `lead_assigned` | LeadService.assignLead |
| `lead_archived` | LeadService.archiveClosedLeads |
| `appointment_created` | AppointmentService.createAppointment |
| `appointment_status_changed` | AppointmentService.updateStatus |
| `pool_order_created` | CarpoolService.createPoolOrder |
| `pool_order_activated` | CarpoolService.activateOrder |
| `pool_order_completed` | CarpoolService.completeOrder |
| `pool_order_expired` | CarpoolService.expireStaleOrders |
| `carpool_match_accepted` | CarpoolService.acceptMatch |
| `count_task_created` | InventoryService.createCountTask |
| `count_batch_created` | InventoryService.createCountBatch |
| `count_entry_recorded` | InventoryService.recordCountEntry |
| `variance_detected` | InventoryService.computeVariances |
| `variance_approved` | InventoryService.approveVariance |
| `adjustment_executed` | InventoryService.executeAdjustmentOrder |
| `exception_detected` | ExceptionService (auto-detection) |
| `exception_created` | ExceptionService.createException |
| `appeal_submitted` | AppealService.submitAppeal |
| `appeal_review_started` | AppealService.startReview |
| `appeal_approved` | AppealService.approveAppeal |
| `appeal_denied` | AppealService.denyAppeal |
| `appeal_archived` | AppealService.archiveAppeal |
| `exception_resolved_via_appeal` | AppealService.approveAppeal |
| `file_uploaded` | FileService.uploadFile |
| `file_pinned` | FileService.pinFile |
| `file_deleted` | FileService.deleteFile |
| `file_purged_lifecycle` | FileService.purgeRejectedAppealMedia |
| `user_created` | UserManagementService.createUser |
| `user_role_changed` | UserManagementService.updateRole |
| `user_deactivated` | UserManagementService.deactivateUser |
| `user_lockout_reset` | UserManagementService.resetLockout |
| `login_success` | AuthService.login |
| `login_failed` | AuthService.login |
| `biometric_enabled` | AuthService.enableBiometric |
| `biometric_disabled` | AuthService.disableBiometric |

---

### 7.16 BackgroundTaskService

Orchestrates periodic background processing.

---

#### `runSLAChecks`

```
runSLAChecks(now: Date = Date()) -> BackgroundTaskResult
```

Checks lead and appointment SLA violations.

---

#### `runMediaCleanup`

```
runMediaCleanup(now: Date = Date()) -> BackgroundTaskResult
```

Purges rejected appeal media older than 30 days.

---

#### `runCarpoolRecalculation`

```
runCarpoolRecalculation(now: Date = Date()) -> BackgroundTaskResult
```

Expires stale orders and computes deferred matches.

---

#### `runVarianceProcessing`

```
runVarianceProcessing() -> BackgroundTaskResult
```

Processes unprocessed count batches for variance detection.

---

#### `runExceptionDetection`

```
runExceptionDetection(now: Date = Date()) -> BackgroundTaskResult
```

Runs buddy punching and misidentification detection.

---

#### `runAllTasks`

```
runAllTasks(now: Date = Date()) -> Void
```

Runs all background tasks in sequence.

---

## Appendix: Encryption

### Encrypted Fields

The following fields are encrypted at rest using AES-256-CBC with per-record Keychain-stored keys:

| Entity | Field |
|--------|-------|
| Lead | `customerName` |
| Lead | `phone` |
| Lead | `consentNotes` |

Encryption is transparent to the service layer — the `EncryptedCoreDataLeadRepository` encrypts on save and decrypts on read. **Encryption failure is a hard error** — if encryption fails for any field, the entire save is rejected with `EncryptionError.fieldEncryptionFailed`. No plaintext fallback exists.

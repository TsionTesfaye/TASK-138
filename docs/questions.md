# DealerOps — Questions (Final Structured Version)

---

## 1. Initial Administrator Setup

**Question**  
How is the first Administrator account created securely on first launch?

**My Understanding**  
The system must support a one-time bootstrap flow where the first user becomes an Administrator. This flow must be strictly controlled to prevent unauthorized re-entry.

**Solution**  
- Detect first launch via: `User.count == 0`  
- First created user is automatically assigned `Administrator` role  
- After creation, bootstrap must be permanently disabled  
- No further users can self-register  

---

## 2. Password Policy

**Question**  
What password validation rules must be enforced?

**My Understanding**  
Strong password rules are required for security, and validation must happen before hashing.

**Solution**  
- Minimum 12 characters  
- Must include:
  - 1 uppercase letter  
  - 1 lowercase letter  
  - 1 number  
- Password must be hashed with salt  
- Validation errors must return clear feedback  

---

## 3. Failed Login Lockout

**Question**  
How should login lockout be enforced?

**My Understanding**  
Lockout must be based on a rolling time window, not just a counter.

**Solution**  
- Track:
  - `failedAttempts`
  - `lastFailedAttempt`
- If 5 failures occur within 10 minutes:
  - Lock account for 10 minutes  
- If outside the 10-minute window:
  - Reset `failedAttempts`  

---

## 4. Biometric Authentication

**Question**  
How should biometric authentication behave?

**My Understanding**  
Biometrics are optional and must always be tied to a valid password-authenticated session.

**Solution**  
- Can only be enabled after successful password login  
- Disabling or reconfiguring requires password re-entry  
- If biometric is unavailable:
  - fallback to password  

---

## 5. Background Re-authentication

**Question**  
When should the app require re-authentication?

**My Understanding**  
Sensitive sessions must expire when the app is inactive.

**Solution**  
- Track background timestamp  
- If inactive > 5 minutes:
  - require full re-authentication  
- Applies to both biometric and password flows  

---

## 6. Role Permissions

**Question**  
What roles exist and how are they defined?

**My Understanding**  
Each role must have explicit permissions; no implicit access allowed.

**Solution**  
Define roles:
- Administrator  
- SalesAssociate  
- InventoryClerk  
- ComplianceReviewer  

Each role must map to:
- allowed modules  
- allowed actions  

---

## 7. Permission Scope Enforcement

**Question**  
How is access scoped per user?

**My Understanding**  
Role alone is insufficient; scope restrictions must also apply.

**Solution**  
- Every action must validate:
  - role
  - scope (site + functionKey)
- Default rule:
  - no scope = no access  

---

## 8. Unified Intake Model

**Question**  
What types of leads must be supported?

**My Understanding**  
All intake flows must use a single unified structure.

**Solution**  
Lead types:
- QuoteRequest  
- Appointment  
- GeneralContact  

---

## 9. Lead Lifecycle Rules

**Question**  
What transitions are allowed for leads?

**My Understanding**  
Lead states must follow a strict state machine.

**Solution**  
Allowed transitions:
- New → FollowUp  
- FollowUp → ClosedWon  
- FollowUp → Invalid  
- Invalid → FollowUp (Admin only)  
- ClosedWon → FollowUp (Admin only)  

---

## 10. Appointment SLA

**Question**  
How is appointment confirmation enforced?

**My Understanding**  
Appointments must be confirmed within a strict time window.

**Solution**  
- Alert if not confirmed within 30 minutes  
- Alert stops when:
  - confirmed  
  - canceled  

---

## 11. Lead SLA (2 Business Hours)

**Question**  
How is SLA enforced for leads?

**My Understanding**  
SLA must respect business hours and only reset on meaningful actions.

**Solution**  
- SLA starts on lead creation  
- SLA resets on:
  - status change  
  - meaningful note  
- Must track:
  - `slaDeadline`
  - `lastQualifyingAction`
- Must support business hours configuration  

---

## 12. Notes and Tags

**Question**  
How are notes and tags structured?

**My Understanding**  
Notes must support polymorphic associations; tags must support many-to-many.

**Solution**  
- Notes:
  - entityId
  - entityType
  - createdBy  
- Tags:
  - use join table (`TagAssignment`)  

---

## 13. Reminder System

**Question**  
How are reminders handled?

**My Understanding**  
Reminders must be tied to entities and users.

**Solution**  
- Must include:
  - entityId
  - entityType
  - createdBy  
- States:
  - pending
  - completed
  - canceled  

---

## 14. Pool Order Model

**Question**  
What lifecycle must pool orders support?

**My Understanding**  
Pool orders require full lifecycle tracking.

**Solution**  
States:
- Draft  
- Active  
- Matched  
- Completed  
- Canceled  
- Expired  

---

## 15. Carpool Matching Logic

**Question**  
How should matching work?

**My Understanding**  
Matching must be deterministic and fully offline.

**Solution**  
- Require:
  - time overlap ≥ 20 minutes  
  - detour threshold respected  
  - seat availability  
- Must produce match score  

---

## 16. Detour Threshold

**Question**  
How is detour calculated?

**My Understanding**  
Threshold must cap excessive deviation.

**Solution**  
- Use:
  - min(10% of route OR 1.5 miles)  

---

## 17. Location Handling

**Question**  
How are locations processed offline?

**My Understanding**  
Distance cannot be calculated from text alone.

**Solution**  
- Store:
  - latitude
  - longitude  
- Distance calculated using Haversine formula  

---

## 18. Inventory Model

**Question**  
What entities are required for inventory?

**My Understanding**  
Inventory requires detailed tracking of counts and adjustments.

**Solution**  
Entities:
- InventoryItem  
- CountTask  
- CountBatch  
- CountEntry  
- AdjustmentOrder  

---

## 19. Variance Threshold Rules

**Question**  
When is approval required?

**My Understanding**  
Significant differences must be reviewed.

**Solution**  
- Approval required if:
  - ±3 units OR  
  - ±2%  

---

## 20. Variance Types

**Question**  
What variance types must be supported?

**My Understanding**  
All discrepancy types must be explicitly defined.

**Solution**  
Types:
- surplus  
- shortage  
- locationMismatch  
- custodianMismatch  

---

## 21. Scanner Input

**Question**  
How is scanner input handled?

**My Understanding**  
Scanner must integrate with inventory validation.

**Solution**  
- Accept plain text identifiers  
- Must map to InventoryItem  
- Invalid scans rejected  

---

## 22. Exception Generation

**Question**  
How are exceptions triggered?

**My Understanding**  
Triggers must be rule-based and deterministic.

**Solution**  
Define rules for:
- missed check-in  
- buddy punching  
- misidentification  

---

## 23. Appeal Workflow

**Question**  
How are appeals processed?

**My Understanding**  
Appeals must follow a strict lifecycle and update original records.

**Solution**  
States:
- submitted  
- under_review  
- approved  
- denied  
- archived  

Approval must update ExceptionCase.

---

## 24. Evidence Handling

**Question**  
How are files handled?

**My Understanding**  
Files must be validated, linked, and secured.

**Solution**  
- Must link to entity  
- Allowed formats:
  - JPG, PNG, MP4  
- Size limits enforced  

---

## 25. Media Lifecycle

**Question**  
How is media retained or deleted?

**My Understanding**  
Retention rules must be enforced automatically.

**Solution**  
- Leads archived after 180 days  
- Evidence deleted after 30 days unless pinned  

---

## 26. Watermarking

**Question**  
How is watermarking applied?

**My Understanding**  
Sensitive files must include visible watermark.

**Solution**  
- Apply:
  - "DealerOps • Confidential"  
- Configurable by admin  

---

## 27. Sensitive Data Protection

**Question**  
How is sensitive data protected?

**My Understanding**  
Data must be encrypted and masked.

**Solution**  
- AES encryption for sensitive fields  
- Masked display in UI and services  

---

## 28. Audit Log Behavior

**Question**  
How are audit logs handled?

**My Understanding**  
Audit logs must be immutable but traceable.

**Solution**  
- Append-only  
- Tombstone allowed  
- Retain for 1 year  

---

## 29. Permission Enforcement

**Question**  
Where are permissions enforced?

**My Understanding**  
Security must not rely on UI alone.

**Solution**  
- All checks enforced at service layer  
- No UI-only enforcement  

---

## 30. Background Tasks

**Question**  
What runs in background?

**My Understanding**  
Heavy or periodic tasks must not block UI.

**Solution**  
Tasks:
- SLA checks  
- media cleanup  
- carpool recalculation  
- variance processing  

import Foundation

// MARK: - Entity Drift Justification
//
// Two entities exist in the implementation that are not explicitly in design.md:
//
// 1. CarpoolMatch (DealerOps/Models/Entities/CarpoolMatch.swift)
//    JUSTIFICATION: design.md 4.5 CarpoolService rules state "persist matches (NEW)".
//    This entity persists the result of carpool matching computations.
//    Without it, match results would be ephemeral and could not be accepted/tracked.
//    Fields: id, requestOrderId, offerOrderId, matchScore, detourMiles, timeOverlapMinutes, accepted, createdAt
//    Backed by: CDCarpoolMatch in Core Data model, CarpoolMatchRepository protocol.
//    ROLE: stores deterministic match results from CarpoolService.computeMatches().
//    Used by: CarpoolService.acceptMatch() to lock seats and transition PoolOrder status.
//
// 2. OperationLog (DealerOps/Repositories/OperationLogRepository.swift)
//    JUSTIFICATION: design.md 4.14 Idempotency & Concurrency states
//    "Each write must include: operationId (UUID)" and
//    "If operationId already exists: ignore duplicate execution"
//    This requires a persistence mechanism for tracking used operationIds.
//    The OperationLogRepository stores only operationId + createdAt.
//    Backed by: CDOperationLog in Core Data model.
//    ROLE: prevents duplicate execution of idempotent operations across all services.
//
// Both entities are required by explicit design.md rules.
// They are NOT phantom entities — they implement mandated behaviors.

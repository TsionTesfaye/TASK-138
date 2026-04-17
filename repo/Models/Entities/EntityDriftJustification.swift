import Foundation

// MARK: - Entity Drift Justification
//
// Two entities exist in the implementation that are not part of the core domain model:
//
// 1. CarpoolMatch (DealerOps/Models/Entities/CarpoolMatch.swift)
//    JUSTIFICATION: CarpoolService matching rules require persisting match results.
//    Without persistence, match results would be ephemeral and could not be accepted/tracked.
//    Fields: id, requestOrderId, offerOrderId, matchScore, detourMiles, timeOverlapMinutes, accepted, createdAt
//    Backed by: CDCarpoolMatch in Core Data model, CarpoolMatchRepository protocol.
//    ROLE: stores deterministic match results from CarpoolService.computeMatches().
//    Used by: CarpoolService.acceptMatch() to lock seats and transition PoolOrder status.
//
// 2. OperationLog (DealerOps/Repositories/OperationLogRepository.swift)
//    JUSTIFICATION: Idempotency requires that each write operation carry an operationId (UUID)
//    and that duplicate operationIds are rejected. This requires persisting previously seen IDs.
//    The OperationLogRepository stores only operationId + createdAt.
//    Backed by: CDOperationLog in Core Data model.
//    ROLE: prevents duplicate execution of idempotent operations across all services.
//
// Both entities are required by explicit system architecture rules.
// They are NOT phantom entities — they implement mandated behaviors.

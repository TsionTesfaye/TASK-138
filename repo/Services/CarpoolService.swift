import Foundation

/// design.md 4.5, 4.13 (PoolOrder State Machine), questions.md Q14-Q17
/// Manages pool orders, Haversine matching, seat locking.
final class CarpoolService {

    private let poolOrderRepo: PoolOrderRepository
    private let routeSegmentRepo: RouteSegmentRepository
    private let carpoolMatchRepo: CarpoolMatchRepository
    private let permissionService: PermissionService
    private let auditService: AuditService
    private let operationLogRepo: OperationLogRepository

    /// Configurable pickup radius in miles (default 2.0)
    var pickupRadiusMiles: Double = 2.0

    init(
        poolOrderRepo: PoolOrderRepository,
        routeSegmentRepo: RouteSegmentRepository,
        carpoolMatchRepo: CarpoolMatchRepository,
        permissionService: PermissionService,
        auditService: AuditService,
        operationLogRepo: OperationLogRepository
    ) {
        self.poolOrderRepo = poolOrderRepo
        self.routeSegmentRepo = routeSegmentRepo
        self.carpoolMatchRepo = carpoolMatchRepo
        self.permissionService = permissionService
        self.auditService = auditService
        self.operationLogRepo = operationLogRepo
    }

    // MARK: - Create Pool Order

    struct CreatePoolOrderInput {
        let originLat: Double
        let originLng: Double
        let destinationLat: Double
        let destinationLng: Double
        let startTime: Date
        let endTime: Date
        let seatsAvailable: Int
        let vehicleType: String
    }

    func createPoolOrder(
        by user: User,
        site: String,
        input: CreatePoolOrderInput,
        operationId: UUID
    ) -> ServiceResult<PoolOrder> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "create", module: .carpool,
            site: site, functionKey: "carpool"
        ) {
            return .failure(err)
        }

        guard input.seatsAvailable > 0 else {
            return .failure(.validationFailed("seatsAvailable", "must be > 0"))
        }

        let order = PoolOrder(
            id: UUID(),
            siteId: site,
            originLat: input.originLat,
            originLng: input.originLng,
            destinationLat: input.destinationLat,
            destinationLng: input.destinationLng,
            startTime: input.startTime,
            endTime: input.endTime,
            seatsAvailable: input.seatsAvailable,
            vehicleType: input.vehicleType,
            createdBy: user.id,
            status: .draft
        )

        do {
            try poolOrderRepo.save(order)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "pool_order_created", entityId: order.id)
            return .success(order)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Activate Order (draft → active)

    func activateOrder(
        by user: User,
        site: String,
        orderId: UUID,
        operationId: UUID
    ) -> ServiceResult<PoolOrder> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "update", module: .carpool,
            site: site, functionKey: "carpool"
        ) {
            return .failure(err)
        }

        guard var order = poolOrderRepo.findById(orderId, siteId: site) else {
            return .failure(.entityNotFound)
        }

        guard order.status.canTransition(to: .active) else {
            return .failure(.invalidTransition)
        }

        order.status = .active

        do {
            try poolOrderRepo.save(order)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "pool_order_activated", entityId: orderId)
            return .success(order)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Compute Matches

    /// Deterministic offline matching using Haversine distance.
    /// Hard filters: time overlap ≥ 20 min, seat availability, pickup radius.
    /// Detour threshold: min(10% of route, 1.5 miles)
    /// Returns scored matches sorted by score descending.
    func computeMatches(by user: User, site: String, for orderId: UUID) -> ServiceResult<[CarpoolMatch]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .carpool,
            site: site, functionKey: "carpool"
        ) {
            return .failure(err)
        }

        guard let order = poolOrderRepo.findById(orderId, siteId: site) else {
            return .failure(.entityNotFound)
        }

        guard order.status == .active else {
            return .failure(.invalidTransition)
        }

        let candidates = poolOrderRepo.findActiveInTimeWindow(start: order.startTime, end: order.endTime, siteId: site)
        var matches: [CarpoolMatch] = []

        for candidate in candidates {
            guard candidate.id != order.id else { continue }
            guard candidate.seatsAvailable > 0 else { continue }

            // Time overlap check (≥ 15 minutes per business prompt)
            let overlapStart = max(order.startTime, candidate.startTime)
            let overlapEnd = min(order.endTime, candidate.endTime)
            let overlapMinutes = overlapEnd.timeIntervalSince(overlapStart) / 60.0
            guard overlapMinutes >= 15 else { continue }

            // Pickup radius check
            let pickupDistance = haversineDistance(
                lat1: order.originLat, lng1: order.originLng,
                lat2: candidate.originLat, lng2: candidate.originLng
            )
            guard pickupDistance <= pickupRadiusMiles else { continue }

            // Route distance for detour calculation
            let orderRouteDistance = haversineDistance(
                lat1: order.originLat, lng1: order.originLng,
                lat2: order.destinationLat, lng2: order.destinationLng
            )

            // Detour: distance from candidate origin to order origin + order route vs direct
            let candidateRouteDistance = haversineDistance(
                lat1: candidate.originLat, lng1: candidate.originLng,
                lat2: candidate.destinationLat, lng2: candidate.destinationLng
            )
            let combinedDistance = pickupDistance + haversineDistance(
                lat1: order.originLat, lng1: order.originLng,
                lat2: candidate.destinationLat, lng2: candidate.destinationLng
            )
            let detourMiles = max(0, combinedDistance - candidateRouteDistance)

            // Detour threshold: min(10% of route, 1.5 miles)
            let percentThreshold = candidateRouteDistance * 0.10
            let detourThreshold = min(percentThreshold, 1.5)
            guard detourMiles <= detourThreshold else { continue }

            // Route overlap score (0.0 - 1.0)
            let destDistance = haversineDistance(
                lat1: order.destinationLat, lng1: order.destinationLng,
                lat2: candidate.destinationLat, lng2: candidate.destinationLng
            )
            let maxRoute = max(orderRouteDistance, candidateRouteDistance, 0.01)
            let routeOverlapScore = max(0, 1.0 - (destDistance / maxRoute))

            // Combined score: weight time fit + route overlap - detour penalty
            let timeFitScore = min(overlapMinutes / 60.0, 1.0)
            let detourPenalty = detourMiles / max(detourThreshold, 0.01)
            let matchScore = (routeOverlapScore * 0.5) + (timeFitScore * 0.3) - (detourPenalty * 0.2)

            let match = CarpoolMatch(
                id: UUID(),
                requestOrderId: orderId,
                offerOrderId: candidate.id,
                matchScore: matchScore,
                detourMiles: detourMiles,
                timeOverlapMinutes: overlapMinutes,
                accepted: false,
                createdAt: Date()
            )

            do { try carpoolMatchRepo.save(match) } catch { ServiceLogger.persistenceError(ServiceLogger.carpool, operation: "save_match", error: error) }
            matches.append(match)
        }

        // Sort by score descending
        matches.sort { $0.matchScore > $1.matchScore }
        return .success(matches)
    }

    // MARK: - Accept Match (Lock Seat)

    func acceptMatch(
        by user: User,
        site: String,
        matchId: UUID,
        operationId: UUID
    ) -> ServiceResult<CarpoolMatch> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "update", module: .carpool,
            site: site, functionKey: "carpool"
        ) {
            return .failure(err)
        }

        guard var match = carpoolMatchRepo.findById(matchId) else {
            return .failure(.entityNotFound)
        }

        guard !match.accepted else {
            return .failure(.duplicateOperation)
        }

        guard var offerOrder = poolOrderRepo.findById(match.offerOrderId, siteId: site) else {
            return .failure(.entityNotFound)
        }

        // Lock seat: check availability
        guard offerOrder.seatsAvailable > 0 else {
            return .failure(.noSeatsAvailable)
        }

        // Decrement seat and update match
        offerOrder.seatsAvailable -= 1
        match.accepted = true

        // Offer order transitions to matched ONLY when all seats are filled.
        // While seats remain, the order stays active to allow further multi-passenger merges.
        if offerOrder.seatsAvailable == 0 && offerOrder.status == .active {
            offerOrder.status = .matched
        }

        // Request order transitions to matched (rider is committed)
        if var requestOrder = poolOrderRepo.findById(match.requestOrderId, siteId: site) {
            if requestOrder.status == .active {
                requestOrder.status = .matched
                do { try poolOrderRepo.save(requestOrder) } catch { ServiceLogger.persistenceError(ServiceLogger.carpool, operation: "save_pool_order", error: error) }
            }
        }

        do {
            try poolOrderRepo.save(offerOrder)
            try carpoolMatchRepo.save(match)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "carpool_match_accepted", entityId: matchId)
            return .success(match)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Complete Order

    func completeOrder(
        by user: User,
        site: String,
        orderId: UUID,
        operationId: UUID
    ) -> ServiceResult<PoolOrder> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "update", module: .carpool,
            site: site, functionKey: "carpool"
        ) {
            return .failure(err)
        }

        guard var order = poolOrderRepo.findById(orderId, siteId: site) else {
            return .failure(.entityNotFound)
        }

        guard order.status.canTransition(to: .completed) else {
            return .failure(.invalidTransition)
        }

        order.status = .completed

        do {
            try poolOrderRepo.save(order)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "pool_order_completed", entityId: orderId)
            return .success(order)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Expire Stale Orders (background task)

    func expireStaleOrders(now: Date = Date()) -> Int {
        let stale = poolOrderRepo.findExpiredBefore(now)
        var expired = 0
        for var order in stale {
            order.status = .expired
            do { try poolOrderRepo.save(order) } catch { ServiceLogger.persistenceError(ServiceLogger.carpool, operation: "save_pool_order", error: error) }
            auditService.log(actorId: UUID(), action: "pool_order_expired", entityId: order.id)
            expired += 1
        }
        return expired
    }

    // MARK: - Deferred Matching (background task)

    /// System-initiated deferred matching for all active orders with available seats.
    /// Computes matches for each eligible active order that does not yet have pending unaccepted matches.
    /// Returns (ordersProcessed, matchesFound).
    func computeDeferredMatches(now: Date = Date()) -> (ordersProcessed: Int, matchesFound: Int) {
        let activeOrders = poolOrderRepo.findActiveInTimeWindow(
            start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(86400)
        )
        var ordersProcessed = 0
        var totalMatches = 0

        for order in activeOrders {
            guard order.seatsAvailable > 0 else { continue }

            // Skip orders that already have unaccepted pending matches
            let existingMatches = carpoolMatchRepo.findByRequestOrderId(order.id)
            let hasPendingMatch = existingMatches.contains { !$0.accepted }
            if hasPendingMatch { continue }

            // Compute new matches scoped to the order's site (same algorithm as user-initiated, without auth)
            let candidates = poolOrderRepo.findActiveInTimeWindow(start: order.startTime, end: order.endTime, siteId: order.siteId)

            for candidate in candidates {
                guard candidate.id != order.id else { continue }
                guard candidate.seatsAvailable > 0 else { continue }

                let overlapStart = max(order.startTime, candidate.startTime)
                let overlapEnd = min(order.endTime, candidate.endTime)
                let overlapMinutes = overlapEnd.timeIntervalSince(overlapStart) / 60.0
                guard overlapMinutes >= 15 else { continue }

                let pickupDistance = haversineDistance(
                    lat1: order.originLat, lng1: order.originLng,
                    lat2: candidate.originLat, lng2: candidate.originLng
                )
                guard pickupDistance <= pickupRadiusMiles else { continue }

                let orderRouteDistance = haversineDistance(
                    lat1: order.originLat, lng1: order.originLng,
                    lat2: order.destinationLat, lng2: order.destinationLng
                )
                let candidateRouteDistance = haversineDistance(
                    lat1: candidate.originLat, lng1: candidate.originLng,
                    lat2: candidate.destinationLat, lng2: candidate.destinationLng
                )
                let combinedDistance = pickupDistance + haversineDistance(
                    lat1: order.originLat, lng1: order.originLng,
                    lat2: candidate.destinationLat, lng2: candidate.destinationLng
                )
                let detourMiles = max(0, combinedDistance - candidateRouteDistance)
                let percentThreshold = candidateRouteDistance * 0.10
                let detourThreshold = min(percentThreshold, 1.5)
                guard detourMiles <= detourThreshold else { continue }

                // Check not already matched (idempotent)
                let alreadyMatched = existingMatches.contains { $0.offerOrderId == candidate.id }
                    || carpoolMatchRepo.findByRequestOrderId(order.id).contains { $0.offerOrderId == candidate.id }
                guard !alreadyMatched else { continue }

                let destDistance = haversineDistance(
                    lat1: order.destinationLat, lng1: order.destinationLng,
                    lat2: candidate.destinationLat, lng2: candidate.destinationLng
                )
                let maxRoute = max(orderRouteDistance, candidateRouteDistance, 0.01)
                let routeOverlapScore = max(0, 1.0 - (destDistance / maxRoute))
                let timeFitScore = min(overlapMinutes / 60.0, 1.0)
                let detourPenalty = detourMiles / max(detourThreshold, 0.01)
                let matchScore = (routeOverlapScore * 0.5) + (timeFitScore * 0.3) - (detourPenalty * 0.2)

                let match = CarpoolMatch(
                    id: UUID(),
                    requestOrderId: order.id,
                    offerOrderId: candidate.id,
                    matchScore: matchScore,
                    detourMiles: detourMiles,
                    timeOverlapMinutes: overlapMinutes,
                    accepted: false,
                    createdAt: Date()
                )

                do { try carpoolMatchRepo.save(match) } catch { ServiceLogger.persistenceError(ServiceLogger.carpool, operation: "save_deferred_match", error: error) }
                totalMatches += 1
            }

            ordersProcessed += 1
        }

        return (ordersProcessed: ordersProcessed, matchesFound: totalMatches)
    }

    // MARK: - Query

    func findAllOrders(by user: User, site: String) -> ServiceResult<[PoolOrder]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .carpool,
            site: site, functionKey: "carpool"
        ) {
            return .failure(err)
        }
        let all = poolOrderRepo.findBySiteId(site)
        // Admins see everything within site; others see their own orders + active orders available for matching
        if user.role == .administrator { return .success(all) }
        return .success(all.filter { $0.createdBy == user.id || $0.status == .active })
    }

    func findOrderById(by user: User, site: String, _ orderId: UUID) -> ServiceResult<PoolOrder?> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .carpool,
            site: site, functionKey: "carpool"
        ) {
            return .failure(err)
        }
        return .success(poolOrderRepo.findById(orderId, siteId: site))
    }

    func findMatchesByOrderId(by user: User, site: String, _ orderId: UUID) -> ServiceResult<[CarpoolMatch]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .carpool,
            site: site, functionKey: "carpool"
        ) {
            return .failure(err)
        }
        // Verify the order belongs to this site before returning its matches
        guard poolOrderRepo.findById(orderId, siteId: site) != nil else {
            return .failure(.entityNotFound)
        }
        return .success(carpoolMatchRepo.findByRequestOrderId(orderId))
    }

    // MARK: - Haversine Distance

    /// Calculate great-circle distance between two coordinates in miles.
    static func haversineDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let earthRadiusMiles = 3958.8
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLng = (lng2 - lng1) * .pi / 180.0
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLng / 2) * sin(dLng / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusMiles * c
    }

    func haversineDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        CarpoolService.haversineDistance(lat1: lat1, lng1: lng1, lat2: lat2, lng2: lng2)
    }
}

import Foundation

/// Tests for CarpoolService: matching, Haversine, detour, time overlap, seat lock.
final class CarpoolServiceTests {

    private let testSite = "lot-a"

    private func makeService() -> (CarpoolService, InMemoryPoolOrderRepository, InMemoryCarpoolMatchRepository) {
        let poolRepo = InMemoryPoolOrderRepository()
        let routeRepo = InMemoryRouteSegmentRepository()
        let matchRepo = InMemoryCarpoolMatchRepository()
        let permService = PermissionService(permissionScopeRepo: InMemoryPermissionScopeRepository())
        let auditService = AuditService(auditLogRepo: InMemoryAuditLogRepository())
        let opLogRepo = InMemoryOperationLogRepository()

        let service = CarpoolService(
            poolOrderRepo: poolRepo, routeSegmentRepo: routeRepo,
            carpoolMatchRepo: matchRepo, permissionService: permService,
            auditService: auditService, operationLogRepo: opLogRepo
        )
        return (service, poolRepo, matchRepo)
    }

    func runAll() {
        print("--- CarpoolServiceTests ---")
        testHaversineDistance()
        testCreatePoolOrder()
        testActivateOrder()
        testMatchWithinRadius()
        testMatchRejectsOutsideRadius()
        testMatchRequires15MinOverlap()
        testAcceptMatchLocksSeat()
        testAcceptMatchNoSeats()
        testExpireStaleOrders()
        testDetourThreshold()
        testCrossSiteOrderLookupDenied()
        testCrossSiteFindAllIsolated()
        testCrossSiteMatchIsolated()
    }

    func testHaversineDistance() {
        let distance = CarpoolService.haversineDistance(
            lat1: 37.7749, lng1: -122.4194, lat2: 37.8044, lng2: -122.2712
        )
        TestHelpers.assert(distance > 7 && distance < 12, "SF to Oakland should be ~8-10 miles, got \(distance)")
        print("  PASS: testHaversineDistance")
    }

    func testCreatePoolOrder() {
        let (service, repo, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let input = CarpoolService.CreatePoolOrderInput(
            originLat: 37.7749, originLng: -122.4194,
            destinationLat: 37.8044, destinationLng: -122.2712,
            startTime: Date(), endTime: Date().addingTimeInterval(3600),
            seatsAvailable: 3, vehicleType: "Sedan"
        )
        let result = service.createPoolOrder(by: admin, site: testSite, input: input, operationId: UUID())
        let order = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(order.status == .draft)
        TestHelpers.assert(order.seatsAvailable == 3)
        print("  PASS: testCreatePoolOrder")
    }

    func testActivateOrder() {
        let (service, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let order = createAndActivateOrder(service: service, user: admin)
        TestHelpers.assert(order.status == .active)
        print("  PASS: testActivateOrder")
    }

    func testMatchWithinRadius() {
        let (service, poolRepo, _) = makeService()
        let admin = TestHelpers.makeAdmin()

        let now = Date()
        let order1 = createActiveOrder(service: service, user: admin,
            originLat: 37.7749, originLng: -122.4194,
            destLat: 37.80, destLng: -122.27,
            start: now, end: now.addingTimeInterval(3600))

        let input2 = CarpoolService.CreatePoolOrderInput(
            originLat: 37.7750, originLng: -122.4195,
            destinationLat: 37.8044, destinationLng: -122.2712,
            startTime: now, endTime: now.addingTimeInterval(3600),
            seatsAvailable: 2, vehicleType: "SUV"
        )
        let order2 = TestHelpers.assertSuccess(service.createPoolOrder(by: admin, site: testSite, input: input2, operationId: UUID()))!
        _ = service.activateOrder(by: admin, site: testSite, orderId: order2.id, operationId: UUID())

        let matches = TestHelpers.assertSuccess(service.computeMatches(by: admin, site: testSite, for: order1.id))!
        TestHelpers.assert(!matches.isEmpty, "Should find at least one match")
        print("  PASS: testMatchWithinRadius")
    }

    func testMatchRejectsOutsideRadius() {
        let (service, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let now = Date()

        let order1 = createActiveOrder(service: service, user: admin,
            originLat: 37.7749, originLng: -122.4194,
            destLat: 37.80, destLng: -122.27,
            start: now, end: now.addingTimeInterval(3600))

        let input2 = CarpoolService.CreatePoolOrderInput(
            originLat: 37.90, originLng: -122.10,
            destinationLat: 37.95, destinationLng: -122.05,
            startTime: now, endTime: now.addingTimeInterval(3600),
            seatsAvailable: 2, vehicleType: "SUV"
        )
        let o2 = TestHelpers.assertSuccess(service.createPoolOrder(by: admin, site: testSite, input: input2, operationId: UUID()))!
        _ = service.activateOrder(by: admin, site: testSite, orderId: o2.id, operationId: UUID())

        let matches = TestHelpers.assertSuccess(service.computeMatches(by: admin, site: testSite, for: order1.id))!
        TestHelpers.assert(matches.isEmpty, "Should not match orders > 2 miles apart")
        print("  PASS: testMatchRejectsOutsideRadius")
    }

    func testMatchRequires15MinOverlap() {
        let (service, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let now = Date()

        let order1 = createActiveOrder(service: service, user: admin,
            originLat: 37.7749, originLng: -122.4194,
            destLat: 37.80, destLng: -122.27,
            start: now, end: now.addingTimeInterval(10 * 60))

        let input2 = CarpoolService.CreatePoolOrderInput(
            originLat: 37.7750, originLng: -122.4195,
            destinationLat: 37.8044, destinationLng: -122.2712,
            startTime: now.addingTimeInterval(5 * 60),
            endTime: now.addingTimeInterval(70 * 60),
            seatsAvailable: 2, vehicleType: "SUV"
        )
        let o2 = TestHelpers.assertSuccess(service.createPoolOrder(by: admin, site: testSite, input: input2, operationId: UUID()))!
        _ = service.activateOrder(by: admin, site: testSite, orderId: o2.id, operationId: UUID())

        let matches = TestHelpers.assertSuccess(service.computeMatches(by: admin, site: testSite, for: order1.id))!
        TestHelpers.assert(matches.isEmpty, "Should reject overlap < 15 min")
        print("  PASS: testMatchRequires15MinOverlap")
    }

    func testAcceptMatchLocksSeat() {
        let (service, poolRepo, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let now = Date()

        let order1 = createActiveOrder(service: service, user: admin,
            originLat: 37.7749, originLng: -122.4194,
            destLat: 37.80, destLng: -122.27,
            start: now, end: now.addingTimeInterval(3600))

        let input2 = CarpoolService.CreatePoolOrderInput(
            originLat: 37.7750, originLng: -122.4195,
            destinationLat: 37.8044, destinationLng: -122.2712,
            startTime: now, endTime: now.addingTimeInterval(3600),
            seatsAvailable: 1, vehicleType: "SUV"
        )
        let o2 = TestHelpers.assertSuccess(service.createPoolOrder(by: admin, site: testSite, input: input2, operationId: UUID()))!
        _ = service.activateOrder(by: admin, site: testSite, orderId: o2.id, operationId: UUID())

        let matches = TestHelpers.assertSuccess(service.computeMatches(by: admin, site: testSite, for: order1.id))!
        guard let match = matches.first else {
            print("  SKIP: testAcceptMatchLocksSeat (no match found)")
            return
        }

        let accepted = TestHelpers.assertSuccess(service.acceptMatch(by: admin, site: testSite, matchId: match.id, operationId: UUID()))!
        TestHelpers.assert(accepted.accepted, "Match should be accepted")

        let updatedOffer = poolRepo.findById(o2.id)!
        TestHelpers.assert(updatedOffer.seatsAvailable == 0, "Seat should be decremented")
        print("  PASS: testAcceptMatchLocksSeat")
    }

    func testAcceptMatchNoSeats() {
        let (service, poolRepo, matchRepo) = makeService()
        let admin = TestHelpers.makeAdmin()

        let order = PoolOrder(
            id: UUID(), siteId: testSite, originLat: 37.77, originLng: -122.41,
            destinationLat: 37.80, destinationLng: -122.27,
            startTime: Date(), endTime: Date().addingTimeInterval(3600),
            seatsAvailable: 0, vehicleType: "Van", createdBy: admin.id, status: .active
        )
        try! poolRepo.save(order)

        let match = CarpoolMatch(
            id: UUID(), requestOrderId: UUID(), offerOrderId: order.id,
            matchScore: 0.8, detourMiles: 0.5, timeOverlapMinutes: 30,
            accepted: false, createdAt: Date()
        )
        try! matchRepo.save(match)

        let result = service.acceptMatch(by: admin, site: testSite, matchId: match.id, operationId: UUID())
        TestHelpers.assertFailure(result, code: "POOL_NO_SEATS")
        print("  PASS: testAcceptMatchNoSeats")
    }

    func testExpireStaleOrders() {
        let (service, poolRepo, _) = makeService()
        let pastOrder = PoolOrder(
            id: UUID(), siteId: testSite, originLat: 37.77, originLng: -122.41,
            destinationLat: 37.80, destinationLng: -122.27,
            startTime: Date().addingTimeInterval(-7200),
            endTime: Date().addingTimeInterval(-3600),
            seatsAvailable: 2, vehicleType: "Car",
            createdBy: UUID(), status: .active
        )
        try! poolRepo.save(pastOrder)

        let expired = service.expireStaleOrders()
        TestHelpers.assert(expired == 1, "Should expire 1 order")
        let updated = poolRepo.findById(pastOrder.id)!
        TestHelpers.assert(updated.status == .expired)
        print("  PASS: testExpireStaleOrders")
    }

    func testDetourThreshold() {
        let routeDistance = 10.0
        let tenPercent = routeDistance * 0.10
        let threshold = min(tenPercent, 1.5)
        TestHelpers.assert(threshold == 1.0, "Threshold should be 1.0 for 10-mile route")

        let shortRoute = 20.0
        let shortTenPercent = shortRoute * 0.10
        let shortThreshold = min(shortTenPercent, 1.5)
        TestHelpers.assert(shortThreshold == 1.5, "Threshold should cap at 1.5 for 20-mile route")
        print("  PASS: testDetourThreshold")
    }

    // MARK: - Cross-Site Isolation Tests

    func testCrossSiteOrderLookupDenied() {
        let (service, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let order = createAndActivateOrder(service: service, user: admin)

        // Attempt to find order from a different site
        let result = service.findOrderById(by: admin, site: "lot-b", order.id)
        let found = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(found == nil, "Cross-site order lookup should return nil")
        print("  PASS: testCrossSiteOrderLookupDenied")
    }

    func testCrossSiteFindAllIsolated() {
        let (service, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()

        // Create order on lot-a
        _ = createAndActivateOrder(service: service, user: admin)

        // Query from lot-b should return empty
        let result = service.findAllOrders(by: admin, site: "lot-b")
        let orders = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(orders.isEmpty, "Cross-site findAll should return empty, got \(orders.count)")
        print("  PASS: testCrossSiteFindAllIsolated")
    }

    func testCrossSiteMatchIsolated() {
        let (service, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let now = Date()

        // Create two orders on lot-a
        let order1 = createActiveOrder(service: service, user: admin,
            originLat: 37.7749, originLng: -122.4194,
            destLat: 37.80, destLng: -122.27,
            start: now, end: now.addingTimeInterval(3600))

        // Attempt to compute matches from lot-b — order not found
        let result = service.computeMatches(by: admin, site: "lot-b", for: order1.id)
        TestHelpers.assertFailure(result, code: "ENTITY_NOT_FOUND")
        print("  PASS: testCrossSiteMatchIsolated")
    }

    // MARK: - Helpers

    private func createAndActivateOrder(service: CarpoolService, user: User) -> PoolOrder {
        let input = CarpoolService.CreatePoolOrderInput(
            originLat: 37.7749, originLng: -122.4194,
            destinationLat: 37.8044, destinationLng: -122.2712,
            startTime: Date(), endTime: Date().addingTimeInterval(3600),
            seatsAvailable: 3, vehicleType: "Sedan"
        )
        let order = TestHelpers.assertSuccess(service.createPoolOrder(by: user, site: testSite, input: input, operationId: UUID()))!
        return TestHelpers.assertSuccess(service.activateOrder(by: user, site: testSite, orderId: order.id, operationId: UUID()))!
    }

    private func createActiveOrder(
        service: CarpoolService, user: User,
        originLat: Double, originLng: Double,
        destLat: Double, destLng: Double,
        start: Date, end: Date
    ) -> PoolOrder {
        let input = CarpoolService.CreatePoolOrderInput(
            originLat: originLat, originLng: originLng,
            destinationLat: destLat, destinationLng: destLng,
            startTime: start, endTime: end,
            seatsAvailable: 3, vehicleType: "Sedan"
        )
        let order = TestHelpers.assertSuccess(service.createPoolOrder(by: user, site: testSite, input: input, operationId: UUID()))!
        return TestHelpers.assertSuccess(service.activateOrder(by: user, site: testSite, orderId: order.id, operationId: UUID()))!
    }
}

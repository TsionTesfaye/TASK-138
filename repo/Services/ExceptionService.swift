import Foundation

/// design.md 4.7, 4.20, questions.md Q22
/// Auto-generates exception cases based on deterministic rules.
/// Exception types: missed check-in, buddy punching, misidentification.
final class ExceptionService {

    private let exceptionCaseRepo: ExceptionCaseRepository
    private let checkInRepo: CheckInRepository
    private let permissionService: PermissionService
    private let auditService: AuditService
    private let operationLogRepo: OperationLogRepository

    init(
        exceptionCaseRepo: ExceptionCaseRepository,
        checkInRepo: CheckInRepository,
        permissionService: PermissionService,
        auditService: AuditService,
        operationLogRepo: OperationLogRepository
    ) {
        self.exceptionCaseRepo = exceptionCaseRepo
        self.checkInRepo = checkInRepo
        self.permissionService = permissionService
        self.auditService = auditService
        self.operationLogRepo = operationLogRepo
    }

    // MARK: - Record Check-In

    func recordCheckIn(
        by user: User,
        site: String,
        locationLat: Double,
        locationLng: Double,
        operationId: UUID
    ) -> ServiceResult<CheckIn> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "create", module: .exceptions,
            site: site, functionKey: "exceptions"
        ) {
            return .failure(err)
        }

        let checkIn = CheckIn(
            id: UUID(),
            siteId: site,
            userId: user.id,
            timestamp: Date(),
            locationLat: locationLat,
            locationLng: locationLng
        )

        do {
            try checkInRepo.save(checkIn)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "check_in_recorded", entityId: checkIn.id)

            // Trigger exception detection after every check-in
            _ = runDetectionCycle()

            return .success(checkIn)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Detect Missed Check-Ins (design.md 4.20)

    /// Rule: no check-in within 30 min of expected time.
    /// expectedTime represents when the user was expected to check in.
    /// System-initiated detection — requires authorized caller.
    func detectMissedCheckIns(by caller: User, site: String, userId: UUID, expectedTime: Date, now: Date = Date()) -> ServiceResult<[ExceptionCase]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: caller, action: "review", module: .exceptions,
            site: site, functionKey: "exceptions"
        ) {
            return .failure(err)
        }

        let windowStart = expectedTime
        let windowEnd = expectedTime.addingTimeInterval(30 * 60) // 30 min after expected

        // Only flag if we're past the window
        guard now > windowEnd else { return .success([]) }

        let checkIns = checkInRepo.findByUserIdInTimeRange(userId: userId, start: windowStart, end: windowEnd)
        guard checkIns.isEmpty else { return .success([]) }

        // Check if we already flagged this
        let existingExceptions = exceptionCaseRepo.findBySourceId(userId)
        let alreadyFlagged = existingExceptions.contains {
            $0.type == .missedCheckIn &&
            abs($0.createdAt.timeIntervalSince(expectedTime)) < 60 // within 1 minute of expected
        }
        guard !alreadyFlagged else { return .success([]) }

        let exception = ExceptionCase(
            id: UUID(),
            siteId: site,
            type: .missedCheckIn,
            sourceId: userId,
            reason: "No check-in recorded within 30 minutes of expected time \(expectedTime)",
            status: .open,
            createdAt: Date()
        )

        do { try exceptionCaseRepo.save(exception) } catch { ServiceLogger.persistenceError(ServiceLogger.exceptions, operation: "save_exception", error: error) }
        auditService.log(actorId: caller.id, action: "exception_generated_missed_checkin", entityId: exception.id)
        return .success([exception])
    }

    // MARK: - Detect Buddy Punching (design.md 4.20)

    /// Rule: 2 users check in within 30 seconds at same location.
    /// "Same location" = within 0.01 miles (~50 feet)
    func detectBuddyPunching(by caller: User, site: String, inTimeRange start: Date, end: Date) -> ServiceResult<[ExceptionCase]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: caller, action: "review", module: .exceptions,
            site: site, functionKey: "exceptions"
        ) {
            return .failure(err)
        }

        let checkIns = checkInRepo.findInTimeRange(start: start, end: end)
        var exceptions: [ExceptionCase] = []

        for i in 0..<checkIns.count {
            for j in (i + 1)..<checkIns.count {
                let a = checkIns[i]
                let b = checkIns[j]

                // Different users
                guard a.userId != b.userId else { continue }

                // Within 30 seconds
                let timeDiff = abs(a.timestamp.timeIntervalSince(b.timestamp))
                guard timeDiff <= 30 else { continue }

                // Same location (within ~50 feet)
                let distance = CarpoolService.haversineDistance(
                    lat1: a.locationLat, lng1: a.locationLng,
                    lat2: b.locationLat, lng2: b.locationLng
                )
                guard distance <= 0.01 else { continue }

                // Check not already flagged
                let existingA = exceptionCaseRepo.findBySourceId(a.id)
                let alreadyFlagged = existingA.contains { $0.type == .buddyPunching }
                guard !alreadyFlagged else { continue }

                let exception = ExceptionCase(
                    id: UUID(),
                    siteId: site,
                    type: .buddyPunching,
                    sourceId: a.id,
                    reason: "Users \(a.userId) and \(b.userId) checked in within 30 seconds at same location",
                    status: .open,
                    createdAt: Date()
                )

                do { try exceptionCaseRepo.save(exception) } catch { ServiceLogger.persistenceError(ServiceLogger.exceptions, operation: "save_exception", error: error) }
                auditService.log(actorId: caller.id, action: "exception_generated_buddy_punching", entityId: exception.id)
                exceptions.append(exception)
            }
        }

        return .success(exceptions)
    }

    // MARK: - Detect Misidentification (design.md 4.20)

    /// Rule: inconsistent check-in pattern over time.
    /// Flags if a user has check-ins at locations > 10 miles apart within 15 minutes.
    func detectMisidentification(by caller: User, site: String, userId: UUID, inTimeRange start: Date, end: Date) -> ServiceResult<[ExceptionCase]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: caller, action: "review", module: .exceptions,
            site: site, functionKey: "exceptions"
        ) {
            return .failure(err)
        }

        let checkIns = checkInRepo.findByUserIdInTimeRange(userId: userId, start: start, end: end)
            .sorted { $0.timestamp < $1.timestamp }

        var exceptions: [ExceptionCase] = []

        for i in 0..<checkIns.count {
            for j in (i + 1)..<checkIns.count {
                let a = checkIns[i]
                let b = checkIns[j]

                let timeDiff = b.timestamp.timeIntervalSince(a.timestamp)
                guard timeDiff <= 15 * 60 && timeDiff > 0 else { continue }

                let distance = CarpoolService.haversineDistance(
                    lat1: a.locationLat, lng1: a.locationLng,
                    lat2: b.locationLat, lng2: b.locationLng
                )
                guard distance > 10 else { continue }

                let existingExceptions = exceptionCaseRepo.findBySourceId(a.id)
                let alreadyFlagged = existingExceptions.contains { $0.type == .misidentification }
                guard !alreadyFlagged else { continue }

                let exception = ExceptionCase(
                    id: UUID(),
                    siteId: site,
                    type: .misidentification,
                    sourceId: a.id,
                    reason: "User \(userId) has check-ins \(distance) miles apart within \(Int(timeDiff/60)) minutes",
                    status: .open,
                    createdAt: Date()
                )

                do { try exceptionCaseRepo.save(exception) } catch { ServiceLogger.persistenceError(ServiceLogger.exceptions, operation: "save_exception", error: error) }
                auditService.log(actorId: caller.id, action: "exception_generated_misidentification", entityId: exception.id)
                exceptions.append(exception)
            }
        }

        return .success(exceptions)
    }

    // MARK: - Detection Cycle (system-initiated)

    /// Run all detection algorithms over the last hour of check-ins.
    /// Called by BackgroundTaskService and after each check-in event.
    /// No authorization required — this is a system-initiated batch operation.
    /// Duplicates are prevented by the individual detect methods (sourceId check).
    func runDetectionCycle(now: Date = Date()) -> (buddyPunching: Int, misidentification: Int) {
        let windowStart = now.addingTimeInterval(-3600) // last hour

        // Buddy punching detection across all recent check-ins
        let recentCheckIns = checkInRepo.findInTimeRange(start: windowStart, end: now)
        var buddyCount = 0

        for i in 0..<recentCheckIns.count {
            for j in (i + 1)..<recentCheckIns.count {
                let a = recentCheckIns[i]
                let b = recentCheckIns[j]

                guard a.userId != b.userId else { continue }
                let timeDiff = abs(a.timestamp.timeIntervalSince(b.timestamp))
                guard timeDiff <= 30 else { continue }
                let distance = CarpoolService.haversineDistance(
                    lat1: a.locationLat, lng1: a.locationLng,
                    lat2: b.locationLat, lng2: b.locationLng
                )
                guard distance <= 0.01 else { continue }

                let existingA = exceptionCaseRepo.findBySourceId(a.id)
                let alreadyFlagged = existingA.contains { $0.type == .buddyPunching }
                guard !alreadyFlagged else { continue }

                let exception = ExceptionCase(
                    id: UUID(), siteId: a.siteId, type: .buddyPunching, sourceId: a.id,
                    reason: "Users \(a.userId) and \(b.userId) checked in within 30 seconds at same location",
                    status: .open, createdAt: Date()
                )
                do { try exceptionCaseRepo.save(exception) } catch { ServiceLogger.persistenceError(ServiceLogger.exceptions, operation: "save_exception", error: error) }
                auditService.log(actorId: UUID(), action: "exception_generated_buddy_punching", entityId: exception.id)
                buddyCount += 1
            }
        }

        // Misidentification detection per unique user
        let uniqueUserIds = Set(recentCheckIns.map { $0.userId })
        var misidCount = 0

        for userId in uniqueUserIds {
            let userCheckIns = recentCheckIns.filter { $0.userId == userId }.sorted { $0.timestamp < $1.timestamp }

            for i in 0..<userCheckIns.count {
                for j in (i + 1)..<userCheckIns.count {
                    let a = userCheckIns[i]
                    let b = userCheckIns[j]
                    let timeDiff = b.timestamp.timeIntervalSince(a.timestamp)
                    guard timeDiff <= 15 * 60 && timeDiff > 0 else { continue }
                    let distance = CarpoolService.haversineDistance(
                        lat1: a.locationLat, lng1: a.locationLng,
                        lat2: b.locationLat, lng2: b.locationLng
                    )
                    guard distance > 10 else { continue }

                    let existingExceptions = exceptionCaseRepo.findBySourceId(a.id)
                    let alreadyFlagged = existingExceptions.contains { $0.type == .misidentification }
                    guard !alreadyFlagged else { continue }

                    let exception = ExceptionCase(
                        id: UUID(), siteId: a.siteId, type: .misidentification, sourceId: a.id,
                        reason: "User \(userId) has check-ins \(distance) miles apart within \(Int(timeDiff/60)) minutes",
                        status: .open, createdAt: Date()
                    )
                    do { try exceptionCaseRepo.save(exception) } catch { ServiceLogger.persistenceError(ServiceLogger.exceptions, operation: "save_exception", error: error) }
                    auditService.log(actorId: UUID(), action: "exception_generated_misidentification", entityId: exception.id)
                    misidCount += 1
                }
            }
        }

        return (buddyPunching: buddyCount, misidentification: misidCount)
    }

    // MARK: - Create Exception (manual)

    func createException(
        by user: User,
        site: String,
        type: ExceptionType,
        sourceId: UUID,
        reason: String,
        operationId: UUID
    ) -> ServiceResult<ExceptionCase> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "create", module: .exceptions,
            site: site, functionKey: "exceptions"
        ) {
            return .failure(err)
        }

        let exception = ExceptionCase(
            id: UUID(),
            siteId: site,
            type: type,
            sourceId: sourceId,
            reason: reason,
            status: .open,
            createdAt: Date()
        )

        do {
            try exceptionCaseRepo.save(exception)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "exception_created_\(type.rawValue)", entityId: exception.id)
            return .success(exception)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Query

    func findById(by user: User, site: String, _ id: UUID) -> ServiceResult<ExceptionCase?> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .exceptions,
            site: site, functionKey: "exceptions"
        ) {
            return .failure(err)
        }
        return .success(exceptionCaseRepo.findById(id, siteId: site))
    }

    func findByStatus(by user: User, site: String, _ status: ExceptionCaseStatus) -> ServiceResult<[ExceptionCase]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .exceptions,
            site: site, functionKey: "exceptions"
        ) {
            return .failure(err)
        }
        return .success(exceptionCaseRepo.findByStatus(status, siteId: site))
    }
}

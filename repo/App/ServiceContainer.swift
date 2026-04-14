import Foundation
import CoreData

/// Central dependency injection container.
/// Wires Core Data backed repositories into all services.
/// For tests: use init(inMemory: true) which uses InMemory repositories.
final class ServiceContainer {

    let persistence: PersistenceController

    // Repositories (protocol types — backed by Core Data in production, InMemory in tests)
    let userRepo: UserRepository
    let permissionScopeRepo: PermissionScopeRepository
    let leadRepo: LeadRepository
    let appointmentRepo: AppointmentRepository
    let noteRepo: NoteRepository
    let tagRepo: TagRepository
    let reminderRepo: ReminderRepository
    let poolOrderRepo: PoolOrderRepository
    let routeSegmentRepo: RouteSegmentRepository
    let inventoryItemRepo: InventoryItemRepository
    let countTaskRepo: CountTaskRepository
    let countBatchRepo: CountBatchRepository
    let countEntryRepo: CountEntryRepository
    let varianceRepo: VarianceRepository
    let adjustmentOrderRepo: AdjustmentOrderRepository
    let exceptionCaseRepo: ExceptionCaseRepository
    let checkInRepo: CheckInRepository
    let appealRepo: AppealRepository
    let evidenceFileRepo: EvidenceFileRepository
    let auditLogRepo: AuditLogRepository
    let businessHoursRepo: BusinessHoursConfigRepository
    let carpoolMatchRepo: CarpoolMatchRepository
    let operationLogRepo: OperationLogRepository

    // Platform services
    let keychainService: KeychainServiceProtocol
    let encryptionService: EncryptionServiceProtocol

    // Services
    let auditService: AuditService
    let permissionService: PermissionService
    let authService: AuthService
    let sessionService: SessionService
    let userManagementService: UserManagementService
    let slaService: SLAService
    let leadService: LeadService
    let appointmentService: AppointmentService
    let reminderService: ReminderService
    let noteService: NoteService
    let carpoolService: CarpoolService
    let inventoryService: InventoryService
    let exceptionService: ExceptionService
    let appealService: AppealService
    let fileService: FileService
    let backgroundTaskService: BackgroundTaskService

    init(inMemory: Bool = false) {
        persistence = PersistenceController(inMemory: inMemory)
        let ctx = persistence.viewContext

        if inMemory {
            // InMemory repositories + encryption for tests
            keychainService = InMemoryKeychainService()
            encryptionService = InMemoryEncryptionService()
            userRepo = InMemoryUserRepository()
            permissionScopeRepo = InMemoryPermissionScopeRepository()
            leadRepo = InMemoryLeadRepository()
            appointmentRepo = InMemoryAppointmentRepository()
            noteRepo = InMemoryNoteRepository()
            tagRepo = InMemoryTagRepository()
            reminderRepo = InMemoryReminderRepository()
            poolOrderRepo = InMemoryPoolOrderRepository()
            routeSegmentRepo = InMemoryRouteSegmentRepository()
            inventoryItemRepo = InMemoryInventoryItemRepository()
            countTaskRepo = InMemoryCountTaskRepository()
            countBatchRepo = InMemoryCountBatchRepository()
            countEntryRepo = InMemoryCountEntryRepository()
            varianceRepo = InMemoryVarianceRepository()
            adjustmentOrderRepo = InMemoryAdjustmentOrderRepository()
            exceptionCaseRepo = InMemoryExceptionCaseRepository()
            checkInRepo = InMemoryCheckInRepository()
            appealRepo = InMemoryAppealRepository()
            evidenceFileRepo = InMemoryEvidenceFileRepository()
            auditLogRepo = InMemoryAuditLogRepository()
            businessHoursRepo = InMemoryBusinessHoursConfigRepository()
            carpoolMatchRepo = InMemoryCarpoolMatchRepository()
            operationLogRepo = InMemoryOperationLogRepository()
        } else {
            // Production: real Keychain + AES encryption + 100% Core Data
            keychainService = KeychainService()
            encryptionService = EncryptionService(keychainService: keychainService)
            userRepo = CoreDataUserRepository(context: ctx)
            permissionScopeRepo = CoreDataPermissionScopeRepository(context: ctx)
            // Lead uses encrypted repository — phone + customerName + consentNotes encrypted at rest
            leadRepo = EncryptedCoreDataLeadRepository(context: ctx, encryption: encryptionService)
            appointmentRepo = CoreDataAppointmentRepository(context: ctx)
            noteRepo = CoreDataNoteRepository(context: ctx)
            tagRepo = CoreDataTagRepository(context: ctx)
            reminderRepo = CoreDataReminderRepository(context: ctx)
            poolOrderRepo = CoreDataPoolOrderRepository(context: ctx)
            routeSegmentRepo = CoreDataRouteSegmentRepository(context: ctx)
            inventoryItemRepo = CoreDataInventoryItemRepository(context: ctx)
            countTaskRepo = CoreDataCountTaskRepository(context: ctx)
            countBatchRepo = CoreDataCountBatchRepository(context: ctx)
            countEntryRepo = CoreDataCountEntryRepository(context: ctx)
            varianceRepo = CoreDataVarianceRepository(context: ctx)
            adjustmentOrderRepo = CoreDataAdjustmentOrderRepository(context: ctx)
            exceptionCaseRepo = CoreDataExceptionCaseRepository(context: ctx)
            checkInRepo = CoreDataCheckInRepository(context: ctx)
            appealRepo = CoreDataAppealRepository(context: ctx)
            evidenceFileRepo = CoreDataEvidenceFileRepository(context: ctx)
            auditLogRepo = CoreDataAuditLogRepository(context: ctx)
            businessHoursRepo = CoreDataBusinessHoursConfigRepository(context: ctx)
            carpoolMatchRepo = CoreDataCarpoolMatchRepository(context: ctx)
            operationLogRepo = CoreDataOperationLogRepository(context: ctx)
        }

        // Wire services
        auditService = AuditService(auditLogRepo: auditLogRepo)
        permissionService = PermissionService(permissionScopeRepo: permissionScopeRepo)
        authService = AuthService(userRepo: userRepo, auditService: auditService, operationLogRepo: operationLogRepo)
        sessionService = SessionService(userRepo: userRepo)
        userManagementService = UserManagementService(
            userRepo: userRepo, permissionService: permissionService, authService: authService,
            auditService: auditService, operationLogRepo: operationLogRepo
        )
        slaService = SLAService(businessHoursRepo: businessHoursRepo, leadRepo: leadRepo,
            appointmentRepo: appointmentRepo, auditService: auditService
        )
        leadService = LeadService(
            leadRepo: leadRepo, permissionService: permissionService, slaService: slaService,
            auditService: auditService, operationLogRepo: operationLogRepo, reminderRepo: reminderRepo
        )
        appointmentService = AppointmentService(
            appointmentRepo: appointmentRepo, leadRepo: leadRepo, permissionService: permissionService,
            slaService: slaService, auditService: auditService, operationLogRepo: operationLogRepo
        )
        reminderService = ReminderService(
            reminderRepo: reminderRepo, permissionService: permissionService,
            auditService: auditService, operationLogRepo: operationLogRepo
        )
        noteService = NoteService(
            noteRepo: noteRepo, tagRepo: tagRepo, permissionService: permissionService,
            auditService: auditService, slaService: slaService, operationLogRepo: operationLogRepo
        )
        carpoolService = CarpoolService(
            poolOrderRepo: poolOrderRepo, routeSegmentRepo: routeSegmentRepo,
            carpoolMatchRepo: carpoolMatchRepo, permissionService: permissionService,
            auditService: auditService, operationLogRepo: operationLogRepo
        )
        inventoryService = InventoryService(
            inventoryItemRepo: inventoryItemRepo, countTaskRepo: countTaskRepo,
            countBatchRepo: countBatchRepo, countEntryRepo: countEntryRepo,
            varianceRepo: varianceRepo, adjustmentOrderRepo: adjustmentOrderRepo,
            permissionService: permissionService, auditService: auditService,
            operationLogRepo: operationLogRepo
        )
        exceptionService = ExceptionService(
            exceptionCaseRepo: exceptionCaseRepo, checkInRepo: checkInRepo,
            permissionService: permissionService, auditService: auditService,
            operationLogRepo: operationLogRepo
        )
        appealService = AppealService(
            appealRepo: appealRepo, exceptionCaseRepo: exceptionCaseRepo,
            permissionService: permissionService, auditService: auditService,
            operationLogRepo: operationLogRepo
        )
        fileService = FileService(
            evidenceFileRepo: evidenceFileRepo, appealRepo: appealRepo,
            permissionService: permissionService, auditService: auditService,
            operationLogRepo: operationLogRepo
        )
        backgroundTaskService = BackgroundTaskService(
            slaService: slaService, leadService: leadService,
            carpoolService: carpoolService, inventoryService: inventoryService,
            fileService: fileService, exceptionService: exceptionService,
            auditService: auditService
        )
    }
}

import Foundation
import CommonCrypto

/// design.md 4.9, questions.md Q24-Q26
/// Handles file uploads, validation, SHA-256 fingerprinting, watermark, lifecycle.
/// Sandbox-only storage. No files ever leave the device.
final class FileService {

    private let evidenceFileRepo: EvidenceFileRepository
    private let appealRepo: AppealRepository
    private let permissionService: PermissionService
    private let auditService: AuditService
    private let operationLogRepo: OperationLogRepository

    /// Watermark enabled by admin. Default true per design.
    var watermarkEnabled: Bool = true

    init(
        evidenceFileRepo: EvidenceFileRepository,
        appealRepo: AppealRepository,
        permissionService: PermissionService,
        auditService: AuditService,
        operationLogRepo: OperationLogRepository
    ) {
        self.evidenceFileRepo = evidenceFileRepo
        self.appealRepo = appealRepo
        self.permissionService = permissionService
        self.auditService = auditService
        self.operationLogRepo = operationLogRepo
    }

    // MARK: - Upload File

    /// Validate format + size, compute SHA-256, store in sandbox.
    /// Allowed formats: JPG, PNG, MP4. Size limits: 10MB image, 50MB video.
    func uploadFile(
        by user: User,
        site: String,
        entityId: UUID,
        entityType: String,
        data: Data,
        fileType: EvidenceFileType,
        operationId: UUID
    ) -> ServiceResult<EvidenceFile> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        let module: PermissionModule = entityType == "Appeal" ? .appeals : .leads
        let functionKey = entityType == "Appeal" ? "appeals" : "leads"
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "create", module: module,
            site: site, functionKey: functionKey
        ) {
            return .failure(err)
        }

        // Format validation — declared type must be allowed
        guard [EvidenceFileType.jpg, .png, .mp4].contains(fileType) else {
            return .failure(.invalidFileFormat)
        }

        // Binary signature validation — verify file bytes match declared type
        guard FileService.validateMagicBytes(data: data, declaredType: fileType) else {
            return .failure(.invalidFileFormat)
        }

        // Size validation
        guard data.count <= fileType.maxSizeBytes else {
            return .failure(.fileTooLarge)
        }

        // SHA-256 fingerprint
        let hash = sha256(data: data)

        // Save to sandbox
        let fileName = "\(UUID().uuidString).\(fileType.rawValue)"
        let filePath = sandboxPath(for: fileName)

        do {
            try data.write(to: URL(fileURLWithPath: filePath))
        } catch {
            return .failure(ServiceError(code: "FILE_WRITE_FAIL", message: error.localizedDescription))
        }

        let evidenceFile = EvidenceFile(
            id: UUID(),
            siteId: site,
            entityId: entityId,
            entityType: entityType,
            filePath: filePath,
            fileType: fileType,
            fileSize: data.count,
            hash: hash,
            createdAt: Date(),
            pinnedByAdmin: false
        )

        do {
            try evidenceFileRepo.save(evidenceFile)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "file_uploaded", entityId: evidenceFile.id)
            return .success(evidenceFile)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Watermark (questions.md Q26)

    /// Apply visible watermark "DealerOps . Confidential" to preview.
    /// Original file is preserved. Watermark applies at display time.
    struct WatermarkResult {
        let originalPath: String
        let watermarkText: String
        let enabled: Bool
    }

    func getWatermarkInfo(by user: User, site: String, for fileId: UUID) -> ServiceResult<WatermarkResult> {
        guard let file = evidenceFileRepo.findById(fileId, siteId: site) else {
            return .failure(.fileNotFound)
        }

        if case .failure(let err) = authorizeFileAccess(file: file, user: user, action: "read", site: site) {
            return .failure(err)
        }
        return .success(WatermarkResult(
            originalPath: file.filePath,
            watermarkText: "DealerOps \u{2022} Confidential",
            enabled: watermarkEnabled
        ))
    }

    // MARK: - Pin File (admin only)

    func pinFile(by admin: User, site: String, fileId: UUID, operationId: UUID) -> ServiceResult<EvidenceFile> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.requireAdmin(user: admin) {
            return .failure(err)
        }

        guard var file = evidenceFileRepo.findById(fileId, siteId: site) else {
            return .failure(.fileNotFound)
        }

        file.pinnedByAdmin = true

        do {
            try evidenceFileRepo.save(file)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: admin.id, action: "file_pinned", entityId: fileId)
            return .success(file)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Delete File

    func deleteFile(by user: User, site: String, fileId: UUID, operationId: UUID) -> ServiceResult<Void> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        guard let file = evidenceFileRepo.findById(fileId, siteId: site) else {
            return .failure(.fileNotFound)
        }

        if case .failure(let err) = authorizeFileAccess(file: file, user: user, action: "delete", site: site) {
            return .failure(err)
        }

        // Remove physical file
        do { try FileManager.default.removeItem(atPath: file.filePath) } catch { ServiceLogger.persistenceError(ServiceLogger.files, operation: "remove_file", error: error) }

        do {
            try evidenceFileRepo.delete(fileId)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "file_deleted", entityId: fileId)
            return .success(())
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Lifecycle: Purge Rejected Appeal Media (questions.md Q25)

    /// Delete evidence for denied appeals older than 30 days unless pinned.
    /// Only purges files where:
    ///   1. entityType == "Appeal"
    ///   2. The linked appeal has status == .denied
    ///   3. The file is older than the threshold
    ///   4. The file is NOT pinned by admin
    /// System-initiated batch operation.
    func purgeRejectedAppealMedia(olderThan date: Date) -> Int {
        let files = evidenceFileRepo.findUnpinnedOlderThan(date)
        var purged = 0
        for file in files {
            // Only purge files linked to appeals
            guard file.entityType == "Appeal" else { continue }

            // Verify the linked appeal is actually denied
            guard let appeal = appealRepo.findById(file.entityId),
                  appeal.status == .denied else { continue }

            do { try FileManager.default.removeItem(atPath: file.filePath) } catch { ServiceLogger.persistenceError(ServiceLogger.files, operation: "remove_file", error: error) }
            do { try evidenceFileRepo.delete(file.id) } catch { ServiceLogger.persistenceError(ServiceLogger.files, operation: "delete_evidence_record", error: error) }
            auditService.log(actorId: UUID(), action: "file_purged_lifecycle", entityId: file.id)
            purged += 1
        }
        return purged
    }

    // MARK: - Query

    func findByEntity(by user: User, site: String, entityId: UUID, entityType: String) -> ServiceResult<[EvidenceFile]> {
        // Route module authorization by entity type
        let module: PermissionModule = entityType == "Appeal" ? .appeals : .leads
        let functionKey = entityType == "Appeal" ? "appeals" : "leads"
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: module,
            site: site, functionKey: functionKey
        ) {
            return .failure(err)
        }
        // Object-level: for appeal evidence, check submitter/reviewer/admin access
        if entityType == "Appeal" {
            if case .failure(let err) = authorizeAppealEvidenceAccess(appealId: entityId, user: user, siteId: site) {
                return .failure(err)
            }
        }
        return .success(evidenceFileRepo.findByEntity(entityId: entityId, entityType: entityType, siteId: site))
    }

    func findById(by user: User, site: String, _ id: UUID) -> ServiceResult<EvidenceFile?> {
        guard let file = evidenceFileRepo.findById(id, siteId: site) else {
            return .success(nil)
        }
        if case .failure(let err) = authorizeFileAccess(file: file, user: user, action: "read", site: site) {
            return .failure(err)
        }
        return .success(file)
    }

    // MARK: - Entity-Aware Authorization

    /// Route file access authorization through the correct module based on the file's entity type,
    /// and apply object-level checks for appeal evidence.
    private func authorizeFileAccess(file: EvidenceFile, user: User, action: String, site: String) -> ServiceResult<Void> {
        let module: PermissionModule = file.entityType == "Appeal" ? .appeals : .leads
        let functionKey = file.entityType == "Appeal" ? "appeals" : "leads"
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: action, module: module,
            site: site, functionKey: functionKey
        ) {
            return .failure(err)
        }
        // Object-level: for appeal evidence, check submitter/reviewer/admin
        if file.entityType == "Appeal" {
            return authorizeAppealEvidenceAccess(appealId: file.entityId, user: user, siteId: site)
        }
        return .success(())
    }

    /// Object-level authorization for appeal evidence.
    /// Allowed: admin, appeal submitter, assigned reviewer.
    private func authorizeAppealEvidenceAccess(appealId: UUID, user: User, siteId: String) -> ServiceResult<Void> {
        if user.role == .administrator { return .success(()) }
        guard let appeal = appealRepo.findById(appealId, siteId: siteId) else {
            return .failure(.entityNotFound)
        }
        if appeal.submittedBy == user.id { return .success(()) }
        if appeal.reviewerId == user.id { return .success(()) }
        return .failure(.permissionDenied)
    }

    // MARK: - Binary Signature Validation

    /// Validate file data header bytes against declared type.
    /// JPG: starts with FF D8 FF
    /// PNG: starts with 89 50 4E 47 0D 0A 1A 0A
    /// MP4: contains "ftyp" at byte offset 4
    static func validateMagicBytes(data: Data, declaredType: EvidenceFileType) -> Bool {
        guard data.count >= 12 else { return false }
        let bytes = [UInt8](data.prefix(12))

        switch declaredType {
        case .jpg:
            // JPEG: FF D8 FF
            return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF
        case .png:
            // PNG: 89 50 4E 47 0D 0A 1A 0A
            return bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47
                && bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A
        case .mp4:
            // MP4/MOV: "ftyp" at offset 4
            return bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70
        }
    }

    // MARK: - SHA-256

    func sha256(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Sandbox Path

    private func sandboxPath(for fileName: String) -> String {
        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let evidenceDir = (documents as NSString).appendingPathComponent("Evidence")

        // Ensure directory exists
        do { try FileManager.default.createDirectory(atPath: evidenceDir, withIntermediateDirectories: true, attributes: nil) } catch { ServiceLogger.persistenceError(ServiceLogger.files, operation: "create_evidence_dir", error: error) }

        return (evidenceDir as NSString).appendingPathComponent(fileName)
    }
}

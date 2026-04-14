import Foundation
import CommonCrypto

/// Tests for FileService: format validation, size limits, SHA-256.
final class FileServiceTests {

    private let testSite = "lot-a"

    private func makeService() -> (FileService, InMemoryEvidenceFileRepository, InMemoryAppealRepository) {
        let repo = InMemoryEvidenceFileRepository()
        let appealRepo = InMemoryAppealRepository()
        let permService = PermissionService(permissionScopeRepo: InMemoryPermissionScopeRepository())
        let auditService = AuditService(auditLogRepo: InMemoryAuditLogRepository())
        let opLogRepo = InMemoryOperationLogRepository()
        let service = FileService(
            evidenceFileRepo: repo, appealRepo: appealRepo, permissionService: permService,
            auditService: auditService, operationLogRepo: opLogRepo
        )
        return (service, repo, appealRepo)
    }

    func runAll() {
        print("--- FileServiceTests ---")
        testUploadJPGSuccess()
        testUploadPNGSuccess()
        testUploadMP4Success()
        testRejectOversizedImage()
        testRejectOversizedVideo()
        testSHA256Correctness()
        testWatermarkInfo()
        testPinFileAdminOnly()
        testPurgeUnpinnedAppealMedia()
        testRejectMismatchedMagicBytes()
        testRejectRenamedPayload()
        testCrossSiteFileAccessDenied()
    }

    // MARK: - Magic Byte Test Data

    /// Build test data with valid magic bytes for each format
    static func makeJPGData(size: Int = 1024) -> Data {
        // JPEG: FF D8 FF
        var data = Data([0xFF, 0xD8, 0xFF, 0xE0] + Array(repeating: UInt8(0x00), count: max(size - 4, 8)))
        return data
    }

    static func makePNGData(size: Int = 512) -> Data {
        // PNG: 89 50 4E 47 0D 0A 1A 0A
        var data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] + Array(repeating: UInt8(0x00), count: max(size - 8, 4)))
        return data
    }

    static func makeMP4Data(size: Int = 2048) -> Data {
        // MP4: "ftyp" at offset 4 -> bytes[4..7] = 0x66 0x74 0x79 0x70
        var data = Data([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70] + Array(repeating: UInt8(0x00), count: max(size - 8, 4)))
        return data
    }

    func testUploadJPGSuccess() {
        let (service, repo, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let data = FileServiceTests.makeJPGData()
        let result = service.uploadFile(by: admin, site: testSite, entityId: UUID(), entityType: "Appeal", data: data, fileType: .jpg, operationId: UUID())
        let file = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(file.fileType == .jpg)
        TestHelpers.assert(file.fileSize == data.count)
        TestHelpers.assert(!file.hash.isEmpty, "Hash should be computed")
        print("  PASS: testUploadJPGSuccess")
    }

    func testUploadPNGSuccess() {
        let (service, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let data = FileServiceTests.makePNGData()
        let result = service.uploadFile(by: admin, site: testSite, entityId: UUID(), entityType: "Lead", data: data, fileType: .png, operationId: UUID())
        _ = TestHelpers.assertSuccess(result)
        print("  PASS: testUploadPNGSuccess")
    }

    func testUploadMP4Success() {
        let (service, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let data = FileServiceTests.makeMP4Data()
        let result = service.uploadFile(by: admin, site: testSite, entityId: UUID(), entityType: "Appeal", data: data, fileType: .mp4, operationId: UUID())
        _ = TestHelpers.assertSuccess(result)
        print("  PASS: testUploadMP4Success")
    }

    func testRejectOversizedImage() {
        let (service, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let data = FileServiceTests.makeJPGData(size: 10 * 1024 * 1024 + 1)
        let result = service.uploadFile(by: admin, site: testSite, entityId: UUID(), entityType: "Appeal", data: data, fileType: .jpg, operationId: UUID())
        TestHelpers.assertFailure(result, code: "FILE_TOO_LARGE")
        print("  PASS: testRejectOversizedImage")
    }

    func testRejectOversizedVideo() {
        let (service, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let data = FileServiceTests.makeMP4Data(size: 50 * 1024 * 1024 + 1)
        let result = service.uploadFile(by: admin, site: testSite, entityId: UUID(), entityType: "Appeal", data: data, fileType: .mp4, operationId: UUID())
        TestHelpers.assertFailure(result, code: "FILE_TOO_LARGE")
        print("  PASS: testRejectOversizedVideo")
    }

    func testSHA256Correctness() {
        let (service, _, _) = makeService()
        let data = "Hello, DealerOps".data(using: .utf8)!
        let hash = service.sha256(data: data)
        TestHelpers.assert(hash.count == 64, "SHA-256 hex should be 64 chars, got \(hash.count)")
        let hash2 = service.sha256(data: data)
        TestHelpers.assert(hash == hash2, "SHA-256 should be deterministic")
        print("  PASS: testSHA256Correctness")
    }

    func testWatermarkInfo() {
        let (service, repo, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let data = FileServiceTests.makeJPGData(size: 100)
        let file = TestHelpers.assertSuccess(service.uploadFile(by: admin, site: testSite, entityId: UUID(), entityType: "Appeal", data: data, fileType: .jpg, operationId: UUID()))!
        let info = TestHelpers.assertSuccess(service.getWatermarkInfo(by: admin, site: testSite, for: file.id))!
        TestHelpers.assert(info.watermarkText.contains("DealerOps"), "Watermark should contain DealerOps")
        TestHelpers.assert(info.enabled, "Watermark should be enabled by default")
        print("  PASS: testWatermarkInfo")
    }

    func testPinFileAdminOnly() {
        let (service, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let clerk = TestHelpers.makeInventoryClerk()
        let data = FileServiceTests.makePNGData(size: 100)
        let file = TestHelpers.assertSuccess(service.uploadFile(by: admin, site: testSite, entityId: UUID(), entityType: "Appeal", data: data, fileType: .png, operationId: UUID()))!

        let clerkResult = service.pinFile(by: clerk, site: testSite, fileId: file.id, operationId: UUID())
        TestHelpers.assertFailure(clerkResult, code: "PERM_ADMIN_REQ")

        let adminResult = service.pinFile(by: admin, site: testSite, fileId: file.id, operationId: UUID())
        let pinned = TestHelpers.assertSuccess(adminResult)!
        TestHelpers.assert(pinned.pinnedByAdmin, "File should be pinned")
        print("  PASS: testPinFileAdminOnly")
    }

    func testPurgeUnpinnedAppealMedia() {
        let (service, repo, appealRepo) = makeService()

        // Create a denied appeal to link evidence to
        let deniedAppealId = UUID()
        let deniedAppeal = Appeal(id: deniedAppealId, siteId: testSite, exceptionId: UUID(), status: .denied, reviewerId: UUID(), submittedBy: UUID(), reason: "test", resolvedAt: Date())
        try! appealRepo.save(deniedAppeal)

        // Create an approved appeal (should NOT have its evidence purged)
        let approvedAppealId = UUID()
        let approvedAppeal = Appeal(id: approvedAppealId, siteId: testSite, exceptionId: UUID(), status: .approved, reviewerId: UUID(), submittedBy: UUID(), reason: "test", resolvedAt: Date())
        try! appealRepo.save(approvedAppeal)

        // Old unpinned file linked to denied appeal — should be purged
        let oldFile = EvidenceFile(
            id: UUID(), siteId: testSite, entityId: deniedAppealId, entityType: "Appeal",
            filePath: "/tmp/old.jpg", fileType: .jpg, fileSize: 100,
            hash: "abc", createdAt: Date().addingTimeInterval(-60 * 86400),
            pinnedByAdmin: false
        )
        try! repo.save(oldFile)

        // Old unpinned file linked to approved appeal — should NOT be purged
        let approvedFile = EvidenceFile(
            id: UUID(), siteId: testSite, entityId: approvedAppealId, entityType: "Appeal",
            filePath: "/tmp/approved.jpg", fileType: .jpg, fileSize: 100,
            hash: "ghi", createdAt: Date().addingTimeInterval(-60 * 86400),
            pinnedByAdmin: false
        )
        try! repo.save(approvedFile)

        // Pinned file linked to denied appeal — should NOT be purged (pinned)
        let pinnedFile = EvidenceFile(
            id: UUID(), siteId: testSite, entityId: deniedAppealId, entityType: "Appeal",
            filePath: "/tmp/pinned.jpg", fileType: .jpg, fileSize: 100,
            hash: "def", createdAt: Date().addingTimeInterval(-60 * 86400),
            pinnedByAdmin: true
        )
        try! repo.save(pinnedFile)

        let cutoff = Date().addingTimeInterval(-30 * 86400)
        let purged = service.purgeRejectedAppealMedia(olderThan: cutoff)
        TestHelpers.assert(purged == 1, "Should purge only 1 file (denied + unpinned), got \(purged)")
        TestHelpers.assert(repo.findById(pinnedFile.id) != nil, "Pinned file should survive")
        TestHelpers.assert(repo.findById(approvedFile.id) != nil, "Approved appeal file should survive")
        print("  PASS: testPurgeUnpinnedAppealMedia")
    }

    // MARK: - Binary Signature Validation Tests

    func testRejectMismatchedMagicBytes() {
        let (service, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()

        // PNG data declared as JPG — should be rejected
        let pngData = FileServiceTests.makePNGData()
        let result = service.uploadFile(by: admin, site: testSite, entityId: UUID(), entityType: "Appeal", data: pngData, fileType: .jpg, operationId: UUID())
        TestHelpers.assertFailure(result, code: "FILE_FORMAT")

        // JPG data declared as PNG — should be rejected
        let jpgData = FileServiceTests.makeJPGData()
        let result2 = service.uploadFile(by: admin, site: testSite, entityId: UUID(), entityType: "Appeal", data: jpgData, fileType: .png, operationId: UUID())
        TestHelpers.assertFailure(result2, code: "FILE_FORMAT")

        // Random bytes declared as MP4 — should be rejected
        let randomData = Data(repeating: 0xAB, count: 100)
        let result3 = service.uploadFile(by: admin, site: testSite, entityId: UUID(), entityType: "Appeal", data: randomData, fileType: .mp4, operationId: UUID())
        TestHelpers.assertFailure(result3, code: "FILE_FORMAT")

        print("  PASS: testRejectMismatchedMagicBytes")
    }

    func testRejectRenamedPayload() {
        let (service, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()

        // MP4 data declared as JPG — should be rejected (ftyp header != FF D8 FF)
        let mp4Data = FileServiceTests.makeMP4Data()
        let result = service.uploadFile(by: admin, site: testSite, entityId: UUID(), entityType: "Appeal", data: mp4Data, fileType: .jpg, operationId: UUID())
        TestHelpers.assertFailure(result, code: "FILE_FORMAT")

        // JPG data declared as MP4 — should be rejected (FF D8 FF != ftyp at offset 4)
        let jpgData = FileServiceTests.makeJPGData()
        let result2 = service.uploadFile(by: admin, site: testSite, entityId: UUID(), entityType: "Appeal", data: jpgData, fileType: .mp4, operationId: UUID())
        TestHelpers.assertFailure(result2, code: "FILE_FORMAT")

        print("  PASS: testRejectRenamedPayload")
    }

    // MARK: - Cross-Site Isolation Tests

    func testCrossSiteFileAccessDenied() {
        let (service, repo, _) = makeService()
        let admin = TestHelpers.makeAdmin()

        // Upload file on lot-a
        let data = FileServiceTests.makeJPGData()
        let file = TestHelpers.assertSuccess(service.uploadFile(by: admin, site: "lot-a", entityId: UUID(), entityType: "Appeal", data: data, fileType: .jpg, operationId: UUID()))!

        // Attempt to find file from lot-b — should return nil
        let result = service.findById(by: admin, site: "lot-b", file.id)
        let found = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(found == nil, "Cross-site file lookup should return nil")

        // Attempt to delete file from lot-b — should fail
        let deleteResult = service.deleteFile(by: admin, site: "lot-b", fileId: file.id, operationId: UUID())
        TestHelpers.assertFailure(deleteResult, code: "FILE_NOT_FOUND")

        // Verify file still exists on lot-a
        let originalResult = service.findById(by: admin, site: "lot-a", file.id)
        let original = TestHelpers.assertSuccess(originalResult)
        TestHelpers.assert(original != nil, "File should still exist on original site")

        print("  PASS: testCrossSiteFileAccessDenied")
    }
}

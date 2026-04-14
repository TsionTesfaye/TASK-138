import Foundation

/// design.md 3.17
struct EvidenceFile: Equatable {
    let id: UUID
    var siteId: String
    var entityId: UUID
    var entityType: String
    var filePath: String
    var fileType: EvidenceFileType
    var fileSize: Int
    var hash: String
    var createdAt: Date
    var pinnedByAdmin: Bool
}

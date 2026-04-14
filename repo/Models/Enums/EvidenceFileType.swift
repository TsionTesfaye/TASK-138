import Foundation

enum EvidenceFileType: String, CaseIterable, Codable {
    case jpg = "jpg"
    case png = "png"
    case mp4 = "mp4"

    var isImage: Bool {
        switch self {
        case .jpg, .png: return true
        case .mp4: return false
        }
    }

    var isVideo: Bool {
        return self == .mp4
    }

    var maxSizeBytes: Int {
        switch self {
        case .jpg, .png:
            return 10 * 1024 * 1024 // 10 MB
        case .mp4:
            return 50 * 1024 * 1024 // 50 MB
        }
    }
}

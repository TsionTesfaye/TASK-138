import Foundation

/// Simple image/video cache that can be cleared on memory warnings.
/// design.md 7: "release caches on warning", "memory-safe media handling"
final class MediaCache {
    static let shared = MediaCache()

    private var cache = NSCache<NSString, NSData>()

    init() {
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB max
        cache.countLimit = 100
    }

    func set(_ data: Data, forKey key: String) {
        cache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
    }

    func get(forKey key: String) -> Data? {
        cache.object(forKey: key as NSString) as Data?
    }

    func clear() {
        cache.removeAllObjects()
    }
}

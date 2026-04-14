import Foundation

protocol BusinessHoursConfigRepository {
    func get() -> BusinessHoursConfig
    func save(_ config: BusinessHoursConfig) throws
}

final class InMemoryBusinessHoursConfigRepository: BusinessHoursConfigRepository {
    private var config: BusinessHoursConfig = .default

    func get() -> BusinessHoursConfig { config }

    func save(_ config: BusinessHoursConfig) throws {
        self.config = config
    }
}

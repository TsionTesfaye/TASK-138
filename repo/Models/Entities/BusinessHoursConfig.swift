import Foundation

struct BusinessHoursConfig: Equatable {
    let id: UUID
    var startHour: Int  // default 9
    var endHour: Int    // default 17
    var workingDays: [Int]  // 2=Monday..6=Friday (Calendar weekday where 1=Sunday)

    static let `default` = BusinessHoursConfig(
        id: UUID(),
        startHour: 9,
        endHour: 17,
        workingDays: [2, 3, 4, 5, 6] // Mon-Fri
    )
}

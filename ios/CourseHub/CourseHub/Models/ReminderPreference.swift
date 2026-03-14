import Foundation

enum ReminderTime: String, Codable, CaseIterable {
    case morningOf = "morning_of"
    case dayBefore = "day_before"
    case twoDaysBefore = "two_days_before"

    var displayName: String {
        switch self {
        case .morningOf: return "Morning of"
        case .dayBefore: return "Day before"
        case .twoDaysBefore: return "2 days before"
        }
    }

    var dayOffset: Int {
        switch self {
        case .morningOf: return 0
        case .dayBefore: return -1
        case .twoDaysBefore: return -2
        }
    }
}

struct ReminderPreference: Codable {
    let dateId: String
    let classId: String
    let title: String
    let date: String
    var reminderEnabled: Bool
    var reminderTime: ReminderTime
}

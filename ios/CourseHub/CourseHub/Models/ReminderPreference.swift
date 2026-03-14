import Foundation

enum ReminderTime: String, Codable, CaseIterable {
    case oneHourBefore = "one_hour_before"
    case dayBefore = "day_before"
    case twoDaysBefore = "two_days_before"

    var displayName: String {
        switch self {
        case .oneHourBefore: return "1 hour before"
        case .dayBefore: return "24 hours before"
        case .twoDaysBefore: return "48 hours before"
        }
    }

    var hourOffset: Int {
        switch self {
        case .oneHourBefore: return -1
        case .dayBefore: return -24
        case .twoDaysBefore: return -48
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

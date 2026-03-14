import Foundation

enum ReminderTime: String, Codable, CaseIterable {
    case oneHourBefore = "one_hour_before"
    case dayBefore = "day_before"
    case twoDaysBefore = "two_days_before"
    case oneWeekBefore = "one_week_before"

    var displayName: String {
        switch self {
        case .oneHourBefore: return "1 hour"
        case .dayBefore: return "1 day"
        case .twoDaysBefore: return "2 days"
        case .oneWeekBefore: return "1 week"
        }
    }

    var hourOffset: Int {
        switch self {
        case .oneHourBefore: return -1
        case .dayBefore: return -24
        case .twoDaysBefore: return -48
        case .oneWeekBefore: return -168
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
    var customDate: String?
}

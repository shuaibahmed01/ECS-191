import Foundation

struct ImportantDate: Codable, Identifiable {
    let id: String
    let classId: String
    let classCode: String
    let title: String
    let date: String
    let description: String

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    var parsedDate: Date? {
        Self.dateTimeFormatter.date(from: date) ?? Self.dateFormatter.date(from: date)
    }

    static func parseDate(_ string: String) -> Date? {
        dateTimeFormatter.date(from: string) ?? dateFormatter.date(from: string)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case classId = "class_id"
        case classCode = "class_code"
        case title
        case date
        case description
    }
}

struct ImportantDatesResponse: Codable {
    let dates: [ImportantDate]
}

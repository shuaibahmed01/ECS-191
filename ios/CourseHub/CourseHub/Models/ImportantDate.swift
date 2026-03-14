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

    var parsedDate: Date? {
        Self.dateFormatter.date(from: date)
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

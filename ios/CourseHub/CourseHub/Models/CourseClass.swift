import Foundation

struct CourseClass: Codable, Identifiable {
    let id: String
    let classCode: String
    let className: String
    let quarter: String?
    let lectureTimes: [String]?
    let discussionTimes: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case classCode = "class_code"
        case className = "class_name"
        case quarter
        case lectureTimes = "lecture_times"
        case discussionTimes = "discussion_times"
    }
}

import Foundation

struct UserScheduleEntry: Codable, Identifiable {
    let id: String
    let classCode: String
    let className: String
    let quarter: String?
    let enrollmentId: String
    let lectureTimes: [String]?
    let discussionTimes: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case classCode = "class_code"
        case className = "class_name"
        case quarter
        case enrollmentId = "enrollment_id"
        case lectureTimes = "lecture_times"
        case discussionTimes = "discussion_times"
    }
}

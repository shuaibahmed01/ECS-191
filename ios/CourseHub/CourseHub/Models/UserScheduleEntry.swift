import Foundation

struct UserScheduleEntry: Codable, Identifiable {
    let id: Int
    let classCode: String
    let className: String
    let quarter: String
    let enrollmentId: Int

    enum CodingKeys: String, CodingKey {
        case id
        case classCode = "class_code"
        case className = "class_name"
        case quarter
        case enrollmentId = "enrollment_id"
    }
}

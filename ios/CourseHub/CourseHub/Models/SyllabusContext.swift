import Foundation

struct SyllabusContext: Codable {
    let classId: String
    let instructor: String
    let officeHours: String
    let gradingPolicy: String
    let importantDates: String
    let coursePolicies: String
    let rawSummary: String
    let uploadedBy: String
    let uploadedAt: String

    enum CodingKeys: String, CodingKey {
        case classId = "class_id"
        case instructor
        case officeHours = "office_hours"
        case gradingPolicy = "grading_policy"
        case importantDates = "important_dates"
        case coursePolicies = "course_policies"
        case rawSummary = "raw_summary"
        case uploadedBy = "uploaded_by"
        case uploadedAt = "uploaded_at"
    }
}

struct SyllabusUploadResponse: Codable {
    let syllabus: SyllabusContext
}

struct SyllabusContextResponse: Codable {
    let syllabus: SyllabusContext
}

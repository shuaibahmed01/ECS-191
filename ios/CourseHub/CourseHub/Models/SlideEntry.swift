import Foundation

struct SlideEntry: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let uploadedBy: String
    let uploadedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case uploadedBy = "uploaded_by"
        case uploadedAt = "uploaded_at"
    }
}

struct SlideListResponse: Codable {
    let slides: [SlideEntry]
}

struct SlideUploadResponse: Codable {
    let slide: SlideEntry
}

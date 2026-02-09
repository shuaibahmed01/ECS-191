import Foundation

struct ChatMessage: Codable, Identifiable {
    let id: Int
    let classId: String
    let senderId: String
    let senderName: String
    let content: String
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case id
        case classId = "class_id"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case content
        case timestamp
    }
}

import Foundation
import FirebaseFirestore

struct ChatMessage: Identifiable {
    let id: String
    let classId: String
    let senderId: String
    let senderName: String
    let content: String
    let timestamp: Date

    /// Initialize from a Firestore document snapshot.
    init?(document: DocumentSnapshot, classId: String) {
        guard let data = document.data() else { return nil }
        self.id = document.documentID
        self.classId = classId
        self.senderId = data["sender_id"] as? String ?? ""
        self.senderName = data["sender_name"] as? String ?? ""
        self.content = data["content"] as? String ?? ""
        if let ts = data["timestamp"] as? Timestamp {
            self.timestamp = ts.dateValue()
        } else {
            self.timestamp = Date()
        }
    }

    /// Initialize from server JSON response (used after POST).
    init(id: String, classId: String, senderId: String, senderName: String, content: String, timestamp: Date) {
        self.id = id
        self.classId = classId
        self.senderId = senderId
        self.senderName = senderName
        self.content = content
        self.timestamp = timestamp
    }
}

/// Codable wrapper for decoding server POST responses.
struct ChatMessageResponse: Codable {
    let id: String
    let classId: String
    let senderId: String
    let senderName: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case id
        case classId = "class_id"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case content
    }

    func toChatMessage() -> ChatMessage {
        ChatMessage(
            id: id,
            classId: classId,
            senderId: senderId,
            senderName: senderName,
            content: content,
            timestamp: Date()
        )
    }
}

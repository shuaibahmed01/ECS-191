import Foundation
import FirebaseFirestore

struct ChatMessage: Identifiable {
    let id: String
    let classId: String
    let senderId: String
    let senderName: String
    let content: String
    let timestamp: Date
    let attachmentUrl: String?
    let attachmentType: String?

    /// Initialize from a Firestore document snapshot.
    init?(document: DocumentSnapshot, classId: String) {
        guard let data = document.data() else { return nil }
        self.id = document.documentID
        self.classId = classId
        self.senderId = data["sender_id"] as? String ?? ""
        self.senderName = data["sender_name"] as? String ?? ""
        self.content = data["content"] as? String ?? ""
        self.attachmentUrl = data["attachment_url"] as? String
        self.attachmentType = data["attachment_type"] as? String
        if let ts = data["timestamp"] as? Timestamp {
            self.timestamp = ts.dateValue()
        } else {
            self.timestamp = Date()
        }
    }

    /// Initialize from server JSON response (used after POST).
    init(id: String, classId: String, senderId: String, senderName: String, content: String, timestamp: Date, attachmentUrl: String? = nil, attachmentType: String? = nil) {
        self.id = id
        self.classId = classId
        self.senderId = senderId
        self.senderName = senderName
        self.content = content
        self.timestamp = timestamp
        self.attachmentUrl = attachmentUrl
        self.attachmentType = attachmentType
    }
}

/// Codable wrapper for decoding server POST responses.
struct ChatMessageResponse: Codable {
    let id: String
    let classId: String
    let senderId: String
    let senderName: String
    let content: String
    let attachmentUrl: String?
    let attachmentType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case classId = "class_id"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case content
        case attachmentUrl = "attachment_url"
        case attachmentType = "attachment_type"
    }

    func toChatMessage() -> ChatMessage {
        ChatMessage(
            id: id,
            classId: classId,
            senderId: senderId,
            senderName: senderName,
            content: content,
            timestamp: Date(),
            attachmentUrl: attachmentUrl,
            attachmentType: attachmentType
        )
    }
}

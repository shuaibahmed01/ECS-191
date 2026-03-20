import Foundation
import FirebaseAuth
import FirebaseFirestore

@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var messageText: String = ""
    var isLoading: Bool = false
    var isSending: Bool = false
    var errorMessage: String?

    private let classId: String
    private var listener: ListenerRegistration?

    var currentUserName: String {
        Auth.auth().currentUser?.displayName ?? "Me"
    }

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    init(classId: String) {
        self.classId = classId
    }

    deinit {
        listener?.remove()
    }

    func startListening() {
        isLoading = true
        errorMessage = nil

        let db = Firestore.firestore()
        let query = db.collection("classes")
            .document(classId)
            .collection("messages")
            .order(by: "timestamp")

        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            self.isLoading = false

            if error != nil {
                self.errorMessage = "Unable to load messages. Please try again later."
                return
            }

            guard let snapshot else { return }

            self.messages = snapshot.documents.compactMap { doc in
                ChatMessage(document: doc, classId: self.classId)
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    @MainActor
    func sendMessage() async {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isSending = true
        errorMessage = nil

        do {
            _ = try await APIClient.shared.sendMessage(
                classId: classId,
                content: content
            )
            messageText = ""
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? "Something went wrong. Please try again later."
        }

        isSending = false
    }

    func isCurrentUser(message: ChatMessage) -> Bool {
        guard let userId = currentUserId else { return false }
        return message.senderId == userId
    }

    @MainActor
    func sendAttachmentLink(url: String, comment: String?) async {
        let trimmedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUrl.isEmpty else { return }
        isSending = true
        errorMessage = nil
        do {
            _ = try await APIClient.shared.sendMessage(
                classId: classId,
                content: comment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                attachmentUrl: trimmedUrl,
                attachmentType: "link"
            )
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? "Something went wrong. Please try again later."
        }
        isSending = false
    }

    @MainActor
    func sendPickedFile(data: Data, mimeType: String, comment: String? = nil) async {
        isSending = true
        errorMessage = nil
        do {
            let encoded = data.base64EncodedString()
            let upload = try await APIClient.shared.uploadAttachment(fileDataBase64: encoded, fileType: mimeType)
            _ = try await APIClient.shared.sendMessage(
                classId: classId,
                content: comment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                attachmentUrl: absoluteURL(upload.url),
                attachmentType: mimeToType(upload.type)
            )
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? "Something went wrong. Please try again later."
        }
        isSending = false
    }

    private func absoluteURL(_ pathOrUrl: String) -> String {
        if pathOrUrl.hasPrefix("http") { return pathOrUrl }
        return "http://localhost:5001\(pathOrUrl)"
    }

    private func mimeToType(_ mime: String) -> String {
        if mime.starts(with: "image/") { return "image" }
        if mime == "application/pdf" { return "pdf" }
        return "file"
    }
}

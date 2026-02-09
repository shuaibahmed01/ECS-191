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

            if let error {
                self.errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }

        isSending = false
    }

    func isCurrentUser(message: ChatMessage) -> Bool {
        guard let userId = currentUserId else { return false }
        return message.senderId == userId
    }
}

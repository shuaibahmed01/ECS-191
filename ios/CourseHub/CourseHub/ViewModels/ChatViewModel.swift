import Foundation
import FirebaseAuth

@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var messageText: String = ""
    var isLoading: Bool = false
    var isSending: Bool = false
    var errorMessage: String?

    private let classId: String

    var currentUserName: String {
        Auth.auth().currentUser?.displayName ?? "Me"
    }

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    init(classId: String) {
        self.classId = classId
    }

    @MainActor
    func loadMessages() async {
        isLoading = true
        errorMessage = nil

        do {
            messages = try await APIClient.shared.fetchMessages(classId: classId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func sendMessage() async {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isSending = true
        errorMessage = nil

        do {
            let newMessage = try await APIClient.shared.sendMessage(
                classId: classId,
                content: content
            )
            messages.append(newMessage)
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

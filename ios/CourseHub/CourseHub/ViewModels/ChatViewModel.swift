import Foundation

@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var messageText: String = ""
    var isLoading: Bool = false
    var isSending: Bool = false
    var errorMessage: String?

    private let classId: Int
    private let currentUserId = 1  // Hardcoded for M0
    let currentUserName = "Me"  // Hardcoded for M0

    init(classId: Int) {
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
                content: content,
                senderName: currentUserName
            )
            messages.append(newMessage)
            messageText = ""
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }

    func isCurrentUser(message: ChatMessage) -> Bool {
        return message.senderId == currentUserId
    }
}

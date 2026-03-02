import Foundation

@Observable
class CourseAgentViewModel {
    var messages: [AgentMessage] = []
    var messageText = ""
    var isLoading = false
    var isSending = false
    var errorMessage: String?
    var syllabusContext: SyllabusContext?
    var isSyllabusLoading = false

    private let classId: String

    init(classId: String) {
        self.classId = classId
    }

    @MainActor
    func loadHistory() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.getAgentHistory(classId: classId)
            messages = response.messages.map { msg in
                AgentMessage(role: msg.role, content: msg.content)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func loadSyllabus() async {
        isSyllabusLoading = true
        do {
            let response = try await APIClient.shared.getSyllabusContext(classId: classId)
            syllabusContext = response.syllabus
        } catch {
            // No syllabus uploaded — not an error, just leave nil
            syllabusContext = nil
        }
        isSyllabusLoading = false
    }

    @MainActor
    func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = AgentMessage(role: "user", content: text)
        messages.append(userMessage)
        messageText = ""
        isSending = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.sendAgentMessage(
                classId: classId,
                message: text
            )
            let agentMessage = AgentMessage(role: "assistant", content: response.response)
            messages.append(agentMessage)
        } catch {
            errorMessage = error.localizedDescription
            // Remove the optimistic user message on failure
            if messages.last?.id == userMessage.id {
                messages.removeLast()
            }
        }

        isSending = false
    }
}

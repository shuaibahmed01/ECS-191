import Foundation

struct AgentMessage: Identifiable {
    let id: String
    let role: String
    let content: String

    init(id: String = UUID().uuidString, role: String, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

struct AgentChatResponse: Codable {
    let response: String
}

struct AgentHistoryResponse: Codable {
    let messages: [AgentHistoryMessage]
}

struct AgentHistoryMessage: Codable {
    let role: String
    let content: String
}

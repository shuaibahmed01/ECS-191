import Foundation

struct AgentMessage: Identifiable {
    let id: String
    let role: String
    let content: String
    let citations: [AgentCitation]

    init(id: String = UUID().uuidString, role: String, content: String, citations: [AgentCitation] = []) {
        self.id = id
        self.role = role
        self.content = content
        self.citations = citations
    }
}

struct AgentCitation: Codable, Hashable {
    let field: String
    let preview: String?
}

struct AgentChatResponse: Codable {
    let response: String
    let citations: [AgentCitation]?
}

struct AgentHistoryResponse: Codable {
    let messages: [AgentHistoryMessage]
}

struct AgentHistoryMessage: Codable {
    let role: String
    let content: String
    let citations: [AgentCitation]?
}

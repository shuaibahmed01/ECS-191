import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            if code == 409 {
                return "Already enrolled in this class"
            }
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

struct ClassListResponse: Codable {
    let classes: [CourseClass]
}

struct UserClassListResponse: Codable {
    let classes: [UserScheduleEntry]
}

struct MessageListResponse: Codable {
    let messages: [ChatMessage]
}

class APIClient {
    static let shared = APIClient()

    private let baseURL = "http://localhost:5001/v1"
    private let userId = 1  // Hardcoded for M0

    private init() {}

    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(userId)", forHTTPHeaderField: "X-User-Id")

        if let body = body {
            request.httpBody = body
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func fetchClasses(query: String = "") async throws -> [CourseClass] {
        var endpoint = "/classes"
        if !query.isEmpty {
            endpoint += "?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        }
        let response: ClassListResponse = try await request(endpoint: endpoint)
        return response.classes
    }

    func enrollInClass(classId: Int) async throws -> UserScheduleEntry {
        let body = try JSONEncoder().encode(["class_id": classId])
        return try await request(
            endpoint: "/users/\(userId)/classes",
            method: "POST",
            body: body
        )
    }

    func fetchMyClasses() async throws -> [UserScheduleEntry] {
        let response: UserClassListResponse = try await request(
            endpoint: "/users/\(userId)/classes"
        )
        return response.classes
    }

    func unenroll(enrollmentId: Int) async throws {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/classes/\(enrollmentId)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("\(userId)", forHTTPHeaderField: "X-User-Id")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }

    func seedDatabase() async {
        guard let url = URL(string: "\(baseURL)/seed") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        try? await URLSession.shared.data(for: request)
    }

    func fetchMessages(classId: Int) async throws -> [ChatMessage] {
        let response: MessageListResponse = try await request(
            endpoint: "/classes/\(classId)/messages"
        )
        return response.messages
    }

    func sendMessage(classId: Int, content: String, senderName: String) async throws -> ChatMessage {
        let body = try JSONEncoder().encode([
            "content": content,
            "sender_name": senderName
        ])
        return try await request(
            endpoint: "/classes/\(classId)/messages",
            method: "POST",
            body: body
        )
    }
}

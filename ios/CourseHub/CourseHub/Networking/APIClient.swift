import Foundation
import FirebaseAuth

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            if code == 409 {
                return "Already enrolled in this class"
            } else if code == 401 {
                return "Not authenticated. Please sign in again."
            } else if code == 403 {
                return "Access denied"
            }
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .notAuthenticated:
            return "Not authenticated. Please sign in."
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
    let messages: [ChatMessageResponse]
}

class APIClient {
    static let shared = APIClient()

    private let baseURL = "http://localhost:5001/v1"

    private init() {}

    /// Gets the Firebase ID token for the current user
    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw APIError.notAuthenticated
        }
        return try await user.getIDToken()
    }

    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth header if required
        if requiresAuth {
            let token = try await getAuthToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

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
        let response: ClassListResponse = try await request(endpoint: endpoint, requiresAuth: false)
        return response.classes
    }

    func enrollInClass(classId: String) async throws -> UserScheduleEntry {
        let body = try JSONEncoder().encode(["class_id": classId])
        return try await request(
            endpoint: "/users/me/classes",
            method: "POST",
            body: body
        )
    }

    func fetchMyClasses() async throws -> [UserScheduleEntry] {
        let response: UserClassListResponse = try await request(
            endpoint: "/users/me/classes"
        )
        return response.classes
    }

    func unenroll(enrollmentId: String) async throws {
        guard let url = URL(string: "\(baseURL)/users/me/classes/\(enrollmentId)") else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let token = try await getAuthToken()
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }

    func sendMessage(classId: String, content: String) async throws -> ChatMessageResponse {
        let body = try JSONEncoder().encode([
            "content": content
        ])
        return try await request(
            endpoint: "/classes/\(classId)/messages",
            method: "POST",
            body: body
        )
    }

    // MARK: - Syllabus & Course Agent

    func uploadSyllabus(classId: String, fileDataBase64: String, fileType: String) async throws -> SyllabusUploadResponse {
        let body = try JSONEncoder().encode([
            "file_data": fileDataBase64,
            "file_type": fileType,
        ])
        return try await request(
            endpoint: "/classes/\(classId)/syllabus",
            method: "POST",
            body: body
        )
    }

    func getSyllabusContext(classId: String) async throws -> SyllabusContextResponse {
        return try await request(
            endpoint: "/classes/\(classId)/syllabus"
        )
    }

    func sendAgentMessage(classId: String, message: String) async throws -> AgentChatResponse {
        let body = try JSONEncoder().encode([
            "message": message,
        ])
        return try await request(
            endpoint: "/classes/\(classId)/agent/chat",
            method: "POST",
            body: body
        )
    }

    func getAgentHistory(classId: String) async throws -> AgentHistoryResponse {
        return try await request(
            endpoint: "/classes/\(classId)/agent/history"
        )
    }

    // MARK: - Forum

    func fetchPosts(courseId: String) async throws -> [ForumPost] {
        let response: PostListResponse = try await request(
            endpoint: "/courses/\(courseId)/posts"
        )
        return response.posts
    }

    func createPost(courseId: String, title: String, body: String) async throws -> ForumPost {
        let body = try JSONEncoder().encode([
            "title": title,
            "body": body,
        ])
        return try await request(
            endpoint: "/courses/\(courseId)/posts",
            method: "POST",
            body: body
        )
    }

    func fetchPostDetail(courseId: String, postId: String) async throws -> PostDetailResponse {
        return try await request(
            endpoint: "/courses/\(courseId)/posts/\(postId)"
        )
    }

    func toggleUpvote(courseId: String, postId: String) async throws -> UpvoteResponse {
        return try await request(
            endpoint: "/courses/\(courseId)/posts/\(postId)/upvote",
            method: "POST"
        )
    }

    func createComment(courseId: String, postId: String, body: String, parentCommentId: String? = nil) async throws -> ForumComment {
        var payload: [String: String] = ["body": body]
        if let parentId = parentCommentId {
            payload["parent_comment_id"] = parentId
        }
        let encoded = try JSONEncoder().encode(payload)
        return try await request(
            endpoint: "/courses/\(courseId)/posts/\(postId)/comments",
            method: "POST",
            body: encoded
        )
    }

    func registerUser(uid: String, email: String, displayName: String) async throws {
        let body = try JSONEncoder().encode([
            "uid": uid,
            "email": email,
            "display_name": displayName
        ])

        guard let url = URL(string: "\(baseURL)/users") else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let token = try await getAuthToken()
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = body

        let (_, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
}

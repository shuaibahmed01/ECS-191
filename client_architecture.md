# Client Architecture (iOS)

## Overview

The CourseHub iOS client is built with **Swift** and **SwiftUI**, following the **MVVM (Model-View-ViewModel)** pattern. It uses the modern `@Observable` macro (not the older `ObservableObject` protocol) and `async/await` for all networking. The app communicates with the Flask backend via a singleton `APIClient` that wraps `URLSession`.

## Project Structure

```
ios/CourseHub/
├── CourseHubApp.swift           # App entry point
├── Models/
│   ├── CourseClass.swift        # Class catalog model
│   ├── UserScheduleEntry.swift  # Enrollment model
│   ├── ChatMessage.swift        # Chat message model
│   └── User.swift               # User model
├── ViewModels/
│   ├── ClassListViewModel.swift     # Browse/search classes
│   ├── MyScheduleViewModel.swift    # User's enrolled classes
│   └── ChatViewModel.swift          # Chat messages + polling
├── Views/
│   ├── ClassListView.swift          # Browse classes tab
│   ├── MyScheduleView.swift         # My schedule tab
│   ├── ChatView.swift               # Group chat screen
│   └── MemberListView.swift         # Chat member list
└── Networking/
    └── APIClient.swift              # Singleton HTTP client
```

## Data Models

All models are Swift `Codable` structs for easy JSON serialization/deserialization.

### `CourseClass`

```swift
struct CourseClass: Codable, Identifiable {
    let id: Int
    let classCode: String
    let className: String
    let quarter: String

    enum CodingKeys: String, CodingKey {
        case id
        case classCode = "class_code"
        case className = "class_name"
        case quarter
    }
}
```

### `UserScheduleEntry`

```swift
struct UserScheduleEntry: Codable, Identifiable {
    let id: Int           // class id
    let classCode: String
    let className: String
    let quarter: String
    let enrollmentId: Int

    enum CodingKeys: String, CodingKey {
        case id
        case classCode = "class_code"
        case className = "class_name"
        case quarter
        case enrollmentId = "enrollment_id"
    }
}
```

### `ChatMessage`

```swift
struct ChatMessage: Codable, Identifiable {
    let id: Int
    let chatId: Int
    let userId: Int
    let content: String
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case id
        case chatId = "chat_id"
        case userId = "user_id"
        case content
        case timestamp
    }
}
```

### `User`

```swift
struct User: Codable, Identifiable {
    let id: Int
    let name: String
    let email: String
}
```

## Networking Layer

### `APIClient`

A singleton that wraps `URLSession` with `async/await`. Handles JSON encoding/decoding, sets the `X-User-Id` header on every request, and provides typed methods for each API endpoint.

```swift
@Observable
class APIClient {
    static let shared = APIClient()

    private let baseURL = "https://<project-id>.appspot.com/v1"
    private let session = URLSession.shared
    var userId: Int = 1  // Hardcoded for M0

    private init() {}

    // MARK: - Generic request helper

    private func request<T: Decodable>(
        _ method: String,
        path: String,
        body: [String: Any]? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        var components = URLComponents(string: baseURL + path)!
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("\(userId)", forHTTPHeaderField: "X-User-Id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let httpResponse = response as? HTTPURLResponse
            throw APIError.httpError(statusCode: httpResponse?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Class endpoints

    func fetchClasses() async throws -> [CourseClass] {
        let response: ClassListResponse = try await request("GET", path: "/classes")
        return response.classes
    }

    func fetchClass(id: Int) async throws -> CourseClass {
        return try await request("GET", path: "/classes/\(id)")
    }

    // MARK: - Enrollment endpoints

    func enrollInClass(classId: Int) async throws -> UserScheduleEntry {
        return try await request(
            "POST",
            path: "/users/\(userId)/classes",
            body: ["class_id": classId]
        )
    }

    func fetchMyClasses() async throws -> [UserScheduleEntry] {
        let response: UserClassListResponse = try await request(
            "GET",
            path: "/users/\(userId)/classes"
        )
        return response.classes
    }

    func unenroll(enrollmentId: Int) async throws {
        let _: EmptyResponse = try await request(
            "DELETE",
            path: "/users/\(userId)/classes/\(enrollmentId)"
        )
    }

    // MARK: - Chat endpoints

    func fetchMessages(classId: Int, limit: Int = 50, before: String? = nil) async throws -> [ChatMessage] {
        var queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let before = before {
            queryItems.append(URLQueryItem(name: "before", value: before))
        }
        let response: MessageListResponse = try await request(
            "GET",
            path: "/classes/\(classId)/chat/messages",
            queryItems: queryItems
        )
        return response.messages
    }

    func sendMessage(classId: Int, content: String) async throws -> ChatMessage {
        return try await request(
            "POST",
            path: "/classes/\(classId)/chat/messages",
            body: ["content": content]
        )
    }

    func fetchMembers(classId: Int) async throws -> [User] {
        let response: MemberListResponse = try await request(
            "GET",
            path: "/classes/\(classId)/chat/members"
        )
        return response.members
    }
}

// MARK: - Response wrappers

struct ClassListResponse: Decodable {
    let classes: [CourseClass]
}

struct UserClassListResponse: Decodable {
    let classes: [UserScheduleEntry]
}

struct MessageListResponse: Decodable {
    let messages: [ChatMessage]
}

struct MemberListResponse: Decodable {
    let members: [User]
}

struct EmptyResponse: Decodable {}

// MARK: - Error types

enum APIError: Error {
    case httpError(statusCode: Int)
}
```

## ViewModels

All ViewModels use the `@Observable` macro for SwiftUI reactivity.

### `ClassListViewModel`

Manages the class catalog and client-side search filtering.

```swift
@Observable
class ClassListViewModel {
    var allClasses: [CourseClass] = []
    var searchText: String = ""
    var isLoading = false
    var errorMessage: String?

    var filteredClasses: [CourseClass] {
        if searchText.isEmpty {
            return allClasses
        }
        let query = searchText.lowercased()
        return allClasses.filter {
            $0.classCode.lowercased().contains(query) ||
            $0.className.lowercased().contains(query)
        }
    }

    func loadClasses() async {
        isLoading = true
        errorMessage = nil
        do {
            allClasses = try await APIClient.shared.fetchClasses()
        } catch {
            errorMessage = "Failed to load classes: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func addClass(_ classId: Int) async -> Bool {
        do {
            _ = try await APIClient.shared.enrollInClass(classId: classId)
            return true
        } catch {
            errorMessage = "Failed to add class: \(error.localizedDescription)"
            return false
        }
    }
}
```

### `MyScheduleViewModel`

Manages the user's enrolled classes.

```swift
@Observable
class MyScheduleViewModel {
    var enrolledClasses: [UserScheduleEntry] = []
    var isLoading = false
    var errorMessage: String?

    func loadSchedule() async {
        isLoading = true
        errorMessage = nil
        do {
            enrolledClasses = try await APIClient.shared.fetchMyClasses()
        } catch {
            errorMessage = "Failed to load schedule: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func removeClass(enrollmentId: Int) async -> Bool {
        do {
            try await APIClient.shared.unenroll(enrollmentId: enrollmentId)
            enrolledClasses.removeAll { $0.enrollmentId == enrollmentId }
            return true
        } catch {
            errorMessage = "Failed to remove class: \(error.localizedDescription)"
            return false
        }
    }
}
```

### `ChatViewModel`

Manages chat messages for a specific class. Implements **polling** (every 5 seconds) to fetch new messages.

```swift
@Observable
class ChatViewModel {
    let classId: Int
    var messages: [ChatMessage] = []
    var members: [User] = []
    var newMessageText: String = ""
    var isLoading = false
    var errorMessage: String?

    private var isPolling = false

    init(classId: Int) {
        self.classId = classId
    }

    func loadInitialData() async {
        isLoading = true
        do {
            async let messagesResult = APIClient.shared.fetchMessages(classId: classId)
            async let membersResult = APIClient.shared.fetchMembers(classId: classId)
            messages = try await messagesResult
            members = try await membersResult
        } catch {
            errorMessage = "Failed to load chat: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func startPolling() async {
        isPolling = true
        while isPolling {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            guard isPolling else { break }
            do {
                messages = try await APIClient.shared.fetchMessages(classId: classId)
            } catch {
                // Silently continue polling on error
            }
        }
    }

    func stopPolling() {
        isPolling = false
    }

    func sendMessage() async {
        let content = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        // Optimistic UI: add message locally before server confirms
        let optimisticMessage = ChatMessage(
            id: -1,
            chatId: classId,
            userId: APIClient.shared.userId,
            content: content,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        messages.insert(optimisticMessage, at: 0)
        newMessageText = ""

        do {
            let serverMessage = try await APIClient.shared.sendMessage(
                classId: classId,
                content: content
            )
            // Replace optimistic message with server version
            if let index = messages.firstIndex(where: { $0.id == -1 }) {
                messages[index] = serverMessage
            }
        } catch {
            // Remove optimistic message on failure
            messages.removeAll { $0.id == -1 }
            errorMessage = "Failed to send message"
        }
    }
}
```

## Views

### Navigation Structure

```
TabView
├── Tab 1: "Browse Classes"
│   └── ClassListView
│       └── (tap class) → adds to schedule
├── Tab 2: "My Schedule"
│   └── MyScheduleView
│       └── (tap class) → ChatView
│           └── (tap members) → MemberListView
```

### `ClassListView`

```swift
struct ClassListView: View {
    @State private var viewModel = ClassListViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.filteredClasses) { course in
                HStack {
                    VStack(alignment: .leading) {
                        Text(course.classCode)
                            .font(.headline)
                        Text(course.className)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Add") {
                        Task { await viewModel.addClass(course.id) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search classes...")
            .navigationTitle("Browse Classes")
            .task { await viewModel.loadClasses() }
        }
    }
}
```

### `MyScheduleView`

```swift
struct MyScheduleView: View {
    @State private var viewModel = MyScheduleViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.enrolledClasses) { entry in
                NavigationLink(destination: ChatView(classId: entry.id, className: entry.classCode)) {
                    VStack(alignment: .leading) {
                        Text(entry.classCode)
                            .font(.headline)
                        Text(entry.className)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .swipeActions {
                    Button("Remove", role: .destructive) {
                        Task { await viewModel.removeClass(enrollmentId: entry.enrollmentId) }
                    }
                }
            }
            .navigationTitle("My Schedule")
            .task { await viewModel.loadSchedule() }
        }
    }
}
```

### `ChatView`

```swift
struct ChatView: View {
    let classId: Int
    let className: String
    @State private var viewModel: ChatViewModel

    init(classId: Int, className: String) {
        self.classId = classId
        self.className = className
        self._viewModel = State(initialValue: ChatViewModel(classId: classId))
    }

    var body: some View {
        VStack {
            // Messages list (newest at bottom)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.messages.reversed()) { message in
                        MessageBubble(message: message,
                                      isCurrentUser: message.userId == APIClient.shared.userId)
                    }
                }
                .padding()
            }

            // Message input bar
            HStack {
                TextField("Message...", text: $viewModel.newMessageText)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    Task { await viewModel.sendMessage() }
                }
                .disabled(viewModel.newMessageText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .navigationTitle(className)
        .task {
            await viewModel.loadInitialData()
        }
        .task {
            await viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }
}
```

### App Entry Point

```swift
@main
struct CourseHubApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ClassListView()
                    .tabItem {
                        Label("Browse", systemImage: "magnifyingglass")
                    }
                MyScheduleView()
                    .tabItem {
                        Label("My Schedule", systemImage: "calendar")
                    }
            }
        }
    }
}
```

## Key Patterns

### Using `.task` for Async Work

SwiftUI's `.task` modifier is the preferred way to trigger async work when a view appears. It automatically cancels the task when the view disappears.

```swift
.task {
    await viewModel.loadClasses()
}
```

### Client-Side Search

Since the class catalog is small (~13 classes), searching is done entirely on the client. The `ClassListViewModel` fetches all classes once and filters them using a computed property based on `searchText`.

### Optimistic UI for Chat

When a user sends a message, it appears immediately in the chat (with a temporary `id = -1`) before the server responds. If the server call succeeds, the temporary message is replaced with the server version. If it fails, the temporary message is removed.

### Polling for Chat Updates

The `ChatViewModel` polls for new messages every 5 seconds using a `Task.sleep` loop. Polling starts when `ChatView` appears (via `.task`) and stops when the view disappears (via `.onDisappear`).

## Error Handling

All ViewModels follow a consistent error handling pattern:

1. Set `isLoading = true` before the async call
2. Wrap the call in `do/catch`
3. On failure, set `errorMessage` with a user-friendly string
4. Set `isLoading = false` after the call (success or failure)

Views can display `errorMessage` in an alert or inline text, and show a loading indicator based on `isLoading`.

# Client Architecture (iOS)

## Overview

The CourseHub iOS client is built with **Swift** and **SwiftUI**, following the **MVVM (Model-View-ViewModel)** pattern. It uses the modern `@Observable` macro and `async/await` for networking. Authentication uses **Firebase Authentication** (email/password). Chat messages are received in real time via **Firestore snapshot listeners**, while all other data flows through a REST API backed by Flask.

## Project Structure

```
ios/CourseHub/
├── CourseHubApp.swift              # App entry point, Firebase init
├── Models/
│   ├── CourseClass.swift           # Course catalog model
│   ├── UserScheduleEntry.swift     # Enrollment model (extends CourseClass)
│   └── ChatMessage.swift           # Chat message model (Firestore + Codable)
├── ViewModels/
│   ├── AuthViewModel.swift         # Firebase Auth state management
│   ├── ClassListViewModel.swift    # Browse/search classes
│   ├── MyScheduleViewModel.swift   # User's enrolled classes
│   └── ChatViewModel.swift         # Real-time chat via Firestore listener
├── Views/
│   ├── LoginView.swift             # Sign in / sign up form
│   ├── MainTabView.swift           # Tab navigation (Schedule + Profile)
│   ├── ClassListView.swift         # Browse classes (shown as sheet)
│   ├── MyScheduleView.swift        # Enrolled classes list
│   ├── ClassDetailView.swift       # Class info + link to chat
│   └── ChatView.swift              # Group chat screen
└── Networking/
    └── APIClient.swift             # Singleton HTTP client with Firebase auth
```

## Data Models

### `CourseClass`

```swift
struct CourseClass: Codable, Identifiable {
    let id: String              // Firestore doc ID (e.g., "ecs_191")
    let classCode: String
    let className: String
    let lectureTimes: [String]
    let discussionTimes: [String]
}
```

### `UserScheduleEntry`

Extends `CourseClass` with an enrollment ID for unenroll operations.

```swift
struct UserScheduleEntry: Codable, Identifiable {
    let id: String
    let classCode: String
    let className: String
    let lectureTimes: [String]
    let discussionTimes: [String]
    let enrollmentId: String
}
```

### `ChatMessage`

Supports initialization from both Firestore document snapshots (for real-time reads) and server JSON responses (for POST confirmations).

```swift
struct ChatMessage: Identifiable {
    let id: String              // Firestore document ID
    let classId: String
    let senderId: String        // Firebase UID
    let senderName: String
    let content: String
    let timestamp: Date

    init?(document: DocumentSnapshot, classId: String)  // From Firestore listener
    init(id:classId:senderId:senderName:content:timestamp:)  // Manual init
}

struct ChatMessageResponse: Codable {
    // Decodes the server POST response (id, class_id, sender_id, sender_name, content)
    func toChatMessage() -> ChatMessage
}
```

## Networking Layer

### `APIClient`

A singleton that wraps `URLSession` with `async/await`. Uses Firebase ID tokens for authentication.

- **Base URL:** `http://localhost:5001/v1`
- **Auth:** Extracts Firebase ID token via `user.getIDToken()` and adds `Authorization: Bearer <token>` header
- **JSON:** Uses `JSONDecoder` with `.iso8601` date strategy

**Key methods:**

| Method | Endpoint | Description |
|--------|----------|-------------|
| `fetchClasses()` | `GET /v1/classes` | Browse all courses (no auth) |
| `enrollInClass(classId:)` | `POST /v1/users/me/classes` | Enroll in a class |
| `fetchMyClasses()` | `GET /v1/users/me/classes` | Get enrolled classes |
| `unenroll(enrollmentId:)` | `DELETE /v1/users/me/classes/:id` | Unenroll from a class |
| `sendMessage(classId:content:)` | `POST /v1/classes/:id/messages` | Send a chat message |
| `registerUser(uid:email:displayName:)` | `POST /v1/users` | Register user after Firebase signup |

Note: `fetchMessages` was removed -- the iOS client now reads messages directly from Firestore via snapshot listeners.

## ViewModels

### `AuthViewModel`

Manages Firebase Authentication state.

- Listens for auth state changes via `addStateDidChangeListener`
- Properties: `isAuthenticated`, `isLoading`, `currentUser`
- Methods: `signUp()`, `signIn()`, `signOut()`, `resetPassword()`
- Calls `APIClient.registerUser()` after successful signup to sync with backend

### `ClassListViewModel`

Manages the class catalog and client-side search filtering.

- Fetches all classes once, filters locally via computed `filteredClasses`
- Client-side search is sufficient since the catalog is small

### `MyScheduleViewModel`

Manages the user's enrolled classes.

- `loadSchedule()` fetches from `GET /v1/users/me/classes`
- `removeClass(enrollmentId:)` calls `DELETE` and removes from local list

### `ChatViewModel`

Manages real-time chat for a specific class using **Firestore snapshot listeners**.

```swift
@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var messageText: String = ""
    var isLoading: Bool = false
    var isSending: Bool = false
    var errorMessage: String?
    private var listener: ListenerRegistration?

    func startListening() {
        // Attaches a Firestore snapshot listener on
        // classes/{classId}/messages ordered by timestamp.
        // Updates `messages` array whenever data changes.
    }

    func stopListening() {
        // Removes the snapshot listener.
    }

    func sendMessage() async {
        // Sends message via APIClient.sendMessage() (server-mediated write).
        // The snapshot listener will pick up the new message automatically.
    }
}
```

**Key design:** The client does NOT poll or manually refresh. The Firestore snapshot listener provides real-time updates. When a message is sent via the server, the server writes to Firestore, and the listener fires with the updated data.

## Views

### Navigation Structure

```
CourseHubApp
├── (not authenticated) → LoginView
└── (authenticated) → MainTabView
    ├── Tab 1: "My Schedule"
    │   └── MyScheduleView
    │       └── (tap class) → ClassDetailView
    │           └── (tap chat) → ChatView
    │       └── (tap +) → ClassListView (sheet)
    └── Tab 2: "Profile"
        └── ProfileView (sign out)
```

### `ChatView`

- Uses `ScrollViewReader` for auto-scrolling to latest message
- `MessageBubble` subview with different styling for current user vs. others
- Message input with send button (disabled when empty or sending)
- `onAppear` starts the Firestore listener, `onDisappear` stops it
- No manual refresh button needed -- updates are real-time

### App Entry Point

```swift
@main
struct CourseHubApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            // Shows LoginView or MainTabView based on AuthViewModel.isAuthenticated
        }
    }
}
```

## Key Patterns

### Real-Time Chat via Firestore Listener

The `ChatViewModel` attaches a `addSnapshotListener` on `classes/{classId}/messages` ordered by `timestamp`. This replaces the previous HTTP polling approach. The listener:
- Fires immediately with all existing messages
- Fires again whenever any message is added, modified, or removed
- Is removed in `deinit` and `onDisappear` to avoid leaks

### Server-Mediated Writes

Messages are sent via `POST /v1/classes/:id/messages` to the Flask server, which:
1. Verifies the Firebase token
2. Checks enrollment
3. Writes to Firestore with `SERVER_TIMESTAMP`

This ensures only enrolled users can send messages. The Firestore snapshot listener on all connected clients then picks up the new message.

### Firebase Authentication

The `APIClient` extracts a Firebase ID token via `Auth.auth().currentUser?.getIDToken()` and adds it as a Bearer token to every authenticated request. Tokens are refreshed automatically by the Firebase SDK.

## Error Handling

All ViewModels follow a consistent pattern:
1. Set `isLoading = true` before the async call
2. Wrap the call in `do/catch`
3. On failure, set `errorMessage` with a user-friendly string
4. Set `isLoading = false` after the call

Views display `errorMessage` in alerts and show loading indicators based on `isLoading`.

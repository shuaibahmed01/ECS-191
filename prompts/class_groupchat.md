# Feature Spec: Class Groupchat

## Overview

The "Class Groupchat" feature provides a group chat for every class in the catalog. When a user enrolls in a class (via the [Add Class](add_class.md) feature), they are **automatically** added to that class's group chat. There is no separate GroupChat entity -- **chat membership is derived from class enrollment** (enrollment records under `users/{uid}/enrollments`). The chat uses **real-time Firestore snapshot listeners** on the iOS client for instant message delivery, with **server-mediated writes** for sending messages.

## User Stories

1. **As a student**, I want to be automatically added to a group chat when I enroll in a class, so that I can immediately communicate with classmates.
2. **As a student**, I want to view messages in a class group chat so that I can stay up to date with class discussions.
3. **As a student**, I want to send messages to a class group chat so that I can communicate with my classmates.
4. **As a student**, I want messages to appear in real time without manual refresh so that conversations feel instant.
5. **As a student**, when I drop a class (unenroll), I should lose access to that class's group chat so that membership stays in sync with enrollment.

## How Auto-Join Works

There is **no separate join/leave action** for the group chat. The logic is:

1. User enrolls in a class --> enrollment record is created --> user can now access the chat
2. User unenrolls from a class --> enrollment record is deleted --> user can no longer access the chat
3. The chat endpoint checks enrollment before allowing access:
   - `is_user_enrolled(user_id, class_id)` returns `True` --> allow access
   - `is_user_enrolled(user_id, class_id)` returns `False` --> return `403 Forbidden`

**Key insight:** `class_id` = chat ID. Every class implicitly has a group chat. The "members" of the chat are simply all users enrolled in that class.

## UI Wireframes

### ChatView (accessed by tapping a class in My Schedule)

```
+-----------------------------+
|  < My Schedule   ECS 191    |
+-----------------------------+
|                             |
|  +--------------------+     |
|  | Shuaib:            |     |
|  | Hey everyone!      |     |
|  | 10:28 AM           |     |
|  +--------------------+     |
|                             |
|     +--------------------+  |
|     | You:               |  |
|     | Hey! Who's working |  |
|     | on the project?    |  |
|     | 10:30 AM           |  |
|     +--------------------+  |
|                             |
|  +--------------------+     |
|  | Isa:               |     |
|  | I am! Want to      |     |
|  | meet up?           |     |
|  | 10:31 AM           |     |
|  +--------------------+     |
|                             |
|  +-------------------+ +--+ |
|  | Message...        | |>>| |
|  +-------------------+ +--+ |
+-----------------------------+
```

### Empty Chat State

```
+-----------------------------+
|  < My Schedule   ECS 191    |
+-----------------------------+
|                             |
|                             |
|     No messages yet.        |
|     Be the first to say     |
|     something!              |
|                             |
|                             |
|  +-------------------+ +--+ |
|  | Message...        | |>>| |
|  +-------------------+ +--+ |
+-----------------------------+
```

## Architecture

### Real-Time Messaging with Firestore

Messages are stored in Firestore as a subcollection under each class:

```
classes/{class_id}/messages/{message_id}
```

**Reading messages (iOS client):**
- The `ChatViewModel` attaches a Firestore **snapshot listener** on the `messages` subcollection, ordered by `timestamp`.
- When any message is added, modified, or removed, the listener fires and the UI updates instantly.
- The listener is attached in `onAppear` and removed in `onDisappear`.

**Sending messages (server-mediated):**
- The iOS client sends a `POST /v1/classes/:class_id/messages` request to the Flask backend.
- The server verifies authentication and enrollment, then writes the message to Firestore with `SERVER_TIMESTAMP`.
- The Firestore snapshot listener on all connected clients picks up the new message in real time.

### Client-Server Sequence Diagram

#### Loading Chat (Real-Time Listener)

```
+----------+                    +----------+                    +-----------+
|  Client  |                    | Firestore|                    |           |
+----+-----+                    +----+-----+                    |           |
     |                               |                          |           |
     |  (User taps class in          |                          |           |
     |   My Schedule)                |                          |           |
     |                               |                          |           |
     |  addSnapshotListener(         |                          |           |
     |    classes/{id}/messages,     |                          |           |
     |    order_by: timestamp)       |                          |           |
     |------------------------------>|                          |           |
     |                               |                          |           |
     |  (Initial snapshot with       |                          |           |
     |   all existing messages)      |                          |           |
     |<------------------------------|                          |           |
     |                               |                          |           |
     |  (Display messages)           |                          |           |
     |                               |                          |           |
     |  --- listener stays active ---|                          |           |
     |                               |                          |           |
     |  (New message arrives)        |                          |           |
     |<------------------------------|                          |           |
     |                               |                          |           |
     |  (UI updates instantly)       |                          |           |
     |                               |                          |           |
```

#### Sending a Message

```
+----------+                    +----------+                    +-----------+
|  Client  |                    |  Server  |                    | Firestore |
+----+-----+                    +----+-----+                    +-----+-----+
     |                               |                                |
     |  (User types message          |                                |
     |   and taps Send)              |                                |
     |                               |                                |
     |  POST /v1/classes/:id/        |                                |
     |    messages                   |                                |
     |  Authorization: Bearer <token>|                                |
     |  {content: "Hello!"}          |                                |
     |------------------------------>|                                |
     |                               |  Check enrollment              |
     |                               |  (Firestore query)            |
     |                               |------------------------------->|
     |                               |              [enrolled = yes] |
     |                               |<-------------------------------|
     |                               |  Write message to             |
     |                               |  classes/{id}/messages        |
     |                               |  (with SERVER_TIMESTAMP)      |
     |                               |------------------------------->|
     |                               |                     [stored]  |
     |                               |<-------------------------------|
     |     201 {id, class_id,        |                                |
     |          sender_id, ...}      |                                |
     |<------------------------------|                                |
     |                               |                                |
     |  (Snapshot listener fires     |                                |
     |   with the new message --     |                                |
     |   UI updates automatically)   |                                |
     |<---------------------------------------------------------------|
     |                               |                                |
```

## Data Models

### Firestore Schema

| Collection | Document | Fields |
|-----------|----------|--------|
| `classes/{class_id}/messages/{msg_id}` | Message | `sender_id` (string, Firebase UID), `sender_name` (string), `content` (string), `timestamp` (Firestore server timestamp) |
| `users/{uid}/enrollments/{enroll_id}` | Enrollment | `class_id` (string), `enrolled_at` (timestamp) |
| `users/{uid}` | User | `uid`, `email`, `display_name` |

### iOS Model

```swift
struct ChatMessage: Identifiable {
    let id: String          // Firestore document ID
    let classId: String
    let senderId: String    // Firebase UID
    let senderName: String
    let content: String
    let timestamp: Date
}
```

## API Endpoints Used

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/v1/classes/:class_id/messages` | Fetch messages (server endpoint, also used for initial load) |
| `POST` | `/v1/classes/:class_id/messages` | Send a message (server-mediated write to Firestore) |

The iOS client also reads directly from Firestore via snapshot listeners for real-time updates.

See [API Reference](api.md) for full request/response details.

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| **Not enrolled in class** | Server returns `403 Forbidden` with `{"error": "Not enrolled in this class"}`. Firestore security rules should also restrict read access. |
| **Empty chat (no messages)** | Snapshot listener returns empty array. Client could show a placeholder message. |
| **Blank/whitespace-only message** | Client disables Send button when input is empty/whitespace. Server also validates and returns `400 Bad Request`. |
| **Drop class while in chat** | If the user unenrolls, server POST will return 403. Firestore reads may still work until security rules are tightened. |
| **Network failure sending message** | Error alert is shown to the user. Message is not added locally until confirmed by Firestore listener. |
| **Very long message** | No explicit limit. Server stores the full content. The UI wraps text naturally. |
| **Multiple users sending simultaneously** | Firestore handles concurrent writes. Snapshot listener delivers all messages in timestamp order. |

## Test Cases

### API Tests

| # | Test Case | Method | Endpoint | Expected |
|---|-----------|--------|----------|----------|
| 1 | Get messages (enrolled) | GET | `/v1/classes/:id/messages` | `200`, returns messages array |
| 2 | Get messages (not enrolled) | GET | `/v1/classes/:id/messages` | `403`, error message |
| 3 | Get messages empty chat | GET | `/v1/classes/:id/messages` | `200`, returns `{"messages": []}` |
| 4 | Send message (enrolled) | POST | `/v1/classes/:id/messages` | `201`, returns message object |
| 5 | Send message (not enrolled) | POST | `/v1/classes/:id/messages` | `403`, error message |
| 6 | Send empty message | POST | `/v1/classes/:id/messages` | `400`, error "content is required" |
| 7 | Message has correct fields | POST | `/v1/classes/:id/messages` | Response includes id, class_id, sender_id, sender_name, content |
| 8 | Posted message persists | POST then GET | `/v1/classes/:id/messages` | Message appears in subsequent GET |

### End-to-End Tests

| # | Test Case | Expected |
|---|-----------|----------|
| 9 | Enroll, send message, verify in chat | User enrolls in class, sends message, snapshot listener shows message |
| 10 | Unenroll, verify chat access revoked | User unenrolls from class, POST messages returns 403 |
| 11 | Two users chat in real time | User A and User B both enroll, both send messages, both see all messages via snapshot listeners |
| 12 | Server restart, messages persist | Restart server, messages still available from Firestore |

### UI Tests

| # | Test Case | Expected |
|---|-----------|----------|
| 13 | Chat view shows messages | Messages displayed in chronological order with sender name and timestamp |
| 14 | Send button disabled for empty input | Send button is grayed out when text field is empty |
| 15 | Real-time update | Message sent from one device appears on another without manual refresh |

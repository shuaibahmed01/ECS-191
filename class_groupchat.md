# Feature Spec: Class Groupchat

## Overview

The "Class Groupchat" feature provides a group chat for every class in the catalog. When a user enrolls in a class (via the [Add Class](add_class.md) feature), they are **automatically** added to that class's group chat. There is no separate GroupChat entity -- **chat membership is derived from class enrollment** (`UserClass` records). The chat uses HTTP polling (every 5 seconds) to fetch new messages.

## User Stories

1. **As a student**, I want to be automatically added to a group chat when I enroll in a class, so that I can immediately communicate with classmates.
2. **As a student**, I want to view messages in a class group chat so that I can stay up to date with class discussions.
3. **As a student**, I want to send messages to a class group chat so that I can communicate with my classmates.
4. **As a student**, I want to see who else is in the group chat (class members) so that I know who I am talking to.
5. **As a student**, when I drop a class (unenroll), I should lose access to that class's group chat so that membership stays in sync with enrollment.

## How Auto-Join Works

There is **no separate join/leave action** for the group chat. The logic is:

1. User enrolls in a class --> `UserClass` record is created --> user can now access the chat
2. User unenrolls from a class --> `UserClass` record is deleted --> user can no longer access the chat
3. The chat endpoint checks enrollment before allowing access:
   - `is_user_enrolled(user_id, class_id)` returns `True` --> allow access
   - `is_user_enrolled(user_id, class_id)` returns `False` --> return `403 Forbidden`

**Key insight:** `chat_id` = `class_id`. Every class implicitly has a group chat. The "members" of the chat are simply all users with a `UserClass` record for that `class_id`.

## UI Wireframes

### ChatView (accessed by tapping a class in My Schedule)

```
┌─────────────────────────────┐
│  < My Schedule   ECS 191    │
│                   [Members] │
├─────────────────────────────┤
│                             │
│  ┌────────────────────┐     │
│  │ Shuaib:            │     │
│  │ Hey everyone!      │     │
│  │ 10:28 AM           │     │
│  └────────────────────┘     │
│                             │
│     ┌────────────────────┐  │
│     │ You:               │  │
│     │ Hey! Who's working │  │
│     │ on the project?    │  │
│     │ 10:30 AM           │  │
│     └────────────────────┘  │
│                             │
│  ┌────────────────────┐     │
│  │ Isa:               │     │
│  │ I am! Want to      │     │
│  │ meet up?           │     │
│  │ 10:31 AM           │     │
│  └────────────────────┘     │
│                             │
│  ┌───────────────────┐ ┌──┐ │
│  │ Message...        │ │>>│ │
│  └───────────────────┘ └──┘ │
└─────────────────────────────┘
```

### MemberListView (accessed by tapping "Members" button)

```
┌─────────────────────────────┐
│  < ECS 191      Members (3) │
├─────────────────────────────┤
│                             │
│  ┌─────────────────────────┐│
│  │ Shuaib Ahmed            ││
│  │ sahmed@ucdavis.edu      ││
│  ├─────────────────────────┤│
│  │ Isa Bukhari             ││
│  │ ibukhari@ucdavis.edu    ││
│  ├─────────────────────────┤│
│  │ Afifah Hadi             ││
│  │ ahadi@ucdavis.edu       ││
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

### Empty Chat State

```
┌─────────────────────────────┐
│  < My Schedule   ECS 191    │
│                   [Members] │
├─────────────────────────────┤
│                             │
│                             │
│     No messages yet.        │
│     Be the first to say     │
│     something!              │
│                             │
│                             │
│  ┌───────────────────┐ ┌──┐ │
│  │ Message...        │ │>>│ │
│  └───────────────────┘ └──┘ │
└─────────────────────────────┘
```

## Client-Server Sequence Diagram

### Loading Chat and Polling

```
┌──────────┐                    ┌──────────┐                    ┌───────────┐
│  Client  │                    │  Server  │                    │ Datastore │
└────┬─────┘                    └────┬─────┘                    └─────┬─────┘
     │                               │                                │
     │  (User taps class in          │                                │
     │   My Schedule)                │                                │
     │                               │                                │
     │  GET /v1/classes/:id/         │                                │
     │    chat/messages              │                                │
     │  X-User-Id: 1                │                                │
     │──────────────────────────────>│                                │
     │                               │  Check enrollment              │
     │                               │  Query(UserClass,              │
     │                               │    user_id=1, class_id=:id)   │
     │                               │───────────────────────────────>│
     │                               │              [enrolled = yes] │
     │                               │<───────────────────────────────│
     │                               │  Query(Message,                │
     │                               │    chat_id=:id, order=-ts)    │
     │                               │───────────────────────────────>│
     │                               │           [message entities]  │
     │                               │<───────────────────────────────│
     │     {messages: [...]}         │                                │
     │<──────────────────────────────│                                │
     │                               │                                │
     │  GET /v1/classes/:id/         │                                │
     │    chat/members               │                                │
     │──────────────────────────────>│                                │
     │                               │  Query(UserClass,              │
     │                               │    class_id=:id) + get Users  │
     │                               │───────────────────────────────>│
     │                               │             [member entities] │
     │                               │<───────────────────────────────│
     │     {members: [...]}          │                                │
     │<──────────────────────────────│                                │
     │                               │                                │
     │  (Display messages + members) │                                │
     │                               │                                │
     │  ┌─── Polling Loop ──────────────────────────────────────────┐ │
     │  │                            │                              │ │
     │  │  (Wait 5 seconds)          │                              │ │
     │  │                            │                              │ │
     │  │  GET /v1/classes/:id/      │                              │ │
     │  │    chat/messages           │                              │ │
     │  │────────────────────────────>                              │ │
     │  │     {messages: [...]}      │                              │ │
     │  │<────────────────────────────                              │ │
     │  │                            │                              │ │
     │  │  (Update UI with new msgs) │                              │ │
     │  │                            │                              │ │
     │  └─── Repeat until view ──────────────────────────────────────┘ │
     │       disappears             │                                │
     │                               │                                │
```

### Sending a Message

```
┌──────────┐                    ┌──────────┐                    ┌───────────┐
│  Client  │                    │  Server  │                    │ Datastore │
└────┬─────┘                    └────┬─────┘                    └─────┬─────┘
     │                               │                                │
     │  (User types message          │                                │
     │   and taps Send)              │                                │
     │                               │                                │
     │  ** Optimistic UI:            │                                │
     │     Message appears           │                                │
     │     instantly (id = -1) **    │                                │
     │                               │                                │
     │  POST /v1/classes/:id/        │                                │
     │    chat/messages              │                                │
     │  {content: "Hello!"}          │                                │
     │──────────────────────────────>│                                │
     │                               │  Check enrollment              │
     │                               │───────────────────────────────>│
     │                               │              [enrolled = yes] │
     │                               │<───────────────────────────────│
     │                               │  Put(Message entity)          │
     │                               │───────────────────────────────>│
     │                               │                     [stored]  │
     │                               │<───────────────────────────────│
     │     201 {id, chat_id,         │                                │
     │          user_id, content,    │                                │
     │          timestamp}           │                                │
     │<──────────────────────────────│                                │
     │                               │                                │
     │  ** Replace optimistic        │                                │
     │     message with server       │                                │
     │     version **                │                                │
     │                               │                                │
```

### Sending Fails (Optimistic UI Rollback)

```
┌──────────┐                    ┌──────────┐
│  Client  │                    │  Server  │
└────┬─────┘                    └────┬─────┘
     │                               │
     │  ** Optimistic UI:            │
     │     Message appears (id=-1)** │
     │                               │
     │  POST /v1/classes/:id/        │
     │    chat/messages              │
     │──────────────────────────────>│
     │       500 or network error    │
     │<──────────────────────────────│
     │                               │
     │  ** Remove optimistic         │
     │     message (id=-1)           │
     │     Show error alert **       │
     │                               │
```

## Messaging Design

### Polling Strategy

- The client polls `GET /v1/classes/:class_id/chat/messages` every **5 seconds**.
- Polling starts when `ChatView` appears (via `.task` modifier).
- Polling stops when `ChatView` disappears (via `.onDisappear`).
- On each poll, the full message list (up to the limit) is re-fetched and replaces the local state.
- Poll errors are silently ignored (the next poll will retry).

### Optimistic UI

When the user sends a message:

1. A temporary message (`id = -1`) is immediately inserted at the top of the local message list.
2. The text field is cleared.
3. The `POST` request is sent to the server.
4. **On success:** The temporary message is replaced with the server's response (which has a real `id` and `timestamp`).
5. **On failure:** The temporary message is removed, and an error message is shown.

### Pagination

Messages are fetched newest-first with a `limit` parameter (default 50). To load older messages, the client passes the `before` parameter set to the `timestamp` of the oldest currently loaded message. This enables infinite scroll / "load more" behavior.

```
# First page (newest 50 messages)
GET /v1/classes/123/chat/messages?limit=50

# Next page (50 messages before the oldest loaded message)
GET /v1/classes/123/chat/messages?limit=50&before=2026-01-15T10:00:00.000000
```

## Data Models

| Entity | Field | Type | Description |
|--------|-------|------|-------------|
| **Message** | `id` | int (auto) | Datastore key ID |
| | `chat_id` | int | Same as `class_id` -- identifies which class chat this belongs to |
| | `user_id` | int | The user who sent the message |
| | `content` | string | The message text |
| | `timestamp` | string | ISO 8601 timestamp of when the message was created |
| **UserClass** | `id` | int (auto) | Datastore key ID |
| | `user_id` | int | Reference to User |
| | `class_id` | int | Reference to Class (also = chat_id for chat membership) |
| **User** | `id` | int (auto) | Datastore key ID |
| | `name` | string | Display name (shown in chat) |
| | `email` | string | Email address (shown in member list) |

## API Endpoints Used

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/v1/classes/:class_id/chat/messages` | Fetch messages (supports `limit`, `before` params) |
| `POST` | `/v1/classes/:class_id/chat/messages` | Send a message |
| `GET` | `/v1/classes/:class_id/chat/members` | List all chat members |

See [API Reference](api.md) for full request/response details.

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| **Not enrolled in class** | Server returns `403 Forbidden` with `{"error": "Not enrolled in this class"}`. Client shows an error and navigates back. |
| **Empty chat (no messages)** | `GET .../chat/messages` returns `{"messages": []}`. Client shows "No messages yet. Be the first to say something!" placeholder. |
| **Blank/whitespace-only message** | Client disables Send button when input is empty/whitespace. Server also validates and returns `400 Bad Request`. |
| **Drop class while in chat** | If the user unenrolls from a class (from My Schedule), the next poll to the chat endpoint returns `403`. Client navigates back to My Schedule. |
| **User sends message, then polls** | The poll replaces the local message list, so the sent message (now with a real ID from the server) will appear naturally in the poll results. |
| **Network failure during poll** | Polling silently continues on the next interval. Messages stay as they were. |
| **Network failure sending message** | Optimistic message is removed. Error alert is shown to the user. |
| **Very long message** | No explicit limit in M0. Server stores the full content. The UI wraps text naturally. |
| **Many messages (pagination)** | Client fetches the first 50 messages. "Load more" or infinite scroll fetches older messages using the `before` parameter. |
| **Multiple users sending simultaneously** | Each poll fetches the latest messages. All messages appear in chronological order regardless of who sent them. |

## Test Cases

### API Tests

| # | Test Case | Method | Endpoint | Expected |
|---|-----------|--------|----------|----------|
| 1 | Get messages (enrolled) | GET | `/v1/classes/:id/chat/messages` | `200`, returns messages array |
| 2 | Get messages (not enrolled) | GET | `/v1/classes/:id/chat/messages` | `403`, error message |
| 3 | Get messages with limit | GET | `/v1/classes/:id/chat/messages?limit=10` | `200`, returns at most 10 messages |
| 4 | Get messages with before | GET | `/v1/classes/:id/chat/messages?before=<ts>` | `200`, returns only older messages |
| 5 | Get messages empty chat | GET | `/v1/classes/:id/chat/messages` | `200`, returns `{"messages": []}` |
| 6 | Send message (enrolled) | POST | `/v1/classes/:id/chat/messages` | `201`, returns message object |
| 7 | Send message (not enrolled) | POST | `/v1/classes/:id/chat/messages` | `403`, error message |
| 8 | Send empty message | POST | `/v1/classes/:id/chat/messages` | `400`, error "Message content cannot be empty" |
| 9 | Send whitespace-only message | POST | `/v1/classes/:id/chat/messages` | `400`, error "Message content cannot be empty" |
| 10 | Get members (enrolled) | GET | `/v1/classes/:id/chat/members` | `200`, returns members array |
| 11 | Get members (not enrolled) | GET | `/v1/classes/:id/chat/members` | `403`, error message |
| 12 | Message has correct fields | POST | `/v1/classes/:id/chat/messages` | Response includes id, chat_id, user_id, content, timestamp |

### End-to-End Tests

| # | Test Case | Expected |
|---|-----------|----------|
| 13 | Enroll, send message, verify in chat | User enrolls in class, sends message, polls and sees own message |
| 14 | Unenroll, verify chat access revoked | User unenrolls from class, next GET messages returns 403 |
| 15 | Two users chat | User A and User B both enroll, both send messages, both see all messages on poll |

### UI Tests

| # | Test Case | Expected |
|---|-----------|----------|
| 16 | Chat view shows messages | Messages displayed in chronological order with sender name and timestamp |
| 17 | Send button disabled for empty input | Send button is grayed out when text field is empty |
| 18 | Members button shows member list | Tapping Members navigates to MemberListView with correct member count |

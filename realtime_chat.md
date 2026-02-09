# Real-Time Firestore Chat: Architecture + Implementation Tasks

## Goal
Replace the in-memory chat with real-time, persistent chat using Firestore.

## Current State (Reality)
- Classes, users, enrollments: Firestore
- Chat messages: in-memory (lost on server restart)
- Chat endpoints: `/v1/classes/<class_id>/messages`

## Target Architecture

### Firestore Data Model
Use a subcollection per class:
- `classes/{class_id}/messages/{message_id}`

Message fields:
- `sender_id` (string, Firebase UID)
- `sender_name` (string)
- `content` (string)
- `timestamp` (Firestore server timestamp)

Notes:
- Collections are created automatically on first write.
- `class_id` should match the IDs used in `courses` (e.g., `ecs_170`).

## Implementation Plan

### 1. Server: Store Messages in Firestore
Files:
- `server/services/datastore_service.py`
- `server/api/chat.py`

Tasks:
- Remove in-memory message storage.
- Implement `get_messages_for_class(class_id)` to read Firestore messages ordered by `timestamp`.
- Implement `create_message(...)` to write a message doc with `serverTimestamp`.
- Keep enrollment check using existing `is_user_enrolled`.

### 2. iOS: Real-Time Listener
Files (expected):
- `ios/CourseHub/CourseHub/ViewModels/`
- `ios/CourseHub/CourseHub/Views/`

Tasks:
- Add Firestore SDK (if not already present).
- In chat view model:
  - Query `classes/<class_id>/messages` ordered by `timestamp`.
  - Attach a snapshot listener.
  - Update UI when messages change.
- Remove any polling logic.

### 3. Sending Messages
Pick one write path:
- **Server-mediated (recommended):** keep POST `/v1/classes/<class_id>/messages`
- **Direct Firestore write:** client writes to Firestore directly

Recommendation: start with server-mediated writes, then move to direct writes if needed.

### 4. Security Rules (Firestore)
Goal: only enrolled users can read/write messages.

Rule strategy options:
1. Add membership docs:
   - `classes/{class_id}/members/{uid}`
   - Allow read/write if `exists(/classes/{class_id}/members/{uid})`
2. Keep server-mediated writes and allow client reads only.

Recommendation:
- Short-term: server-mediated writes + client read access
- Long-term: add `members` collection for strong rule enforcement

### 5. Seed Data (Optional)
If you want demo messages:
- Create a script to insert sample messages into Firestore.
- Remove the current `/v1/seed` in-memory behavior.

## Testing Checklist
1. Start server and iOS app.
2. Enroll two users in same class.
3. Open chat on both devices.
4. Send a message from one device.
5. Confirm the other device updates instantly.
6. Restart server and confirm messages persist.

## Acceptance Criteria
- Messages persist across server restarts.
- Messages appear in real time without manual refresh.
- Only enrolled users can read/write class messages.
- No regressions in class listing or enrollment.

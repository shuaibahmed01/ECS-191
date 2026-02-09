# API Reference

## Overview

The CourseHub REST API is served under the `/v1/` prefix. All endpoints accept and return JSON. Authentication uses Firebase ID tokens.

**Base URL (local):** `http://localhost:5001/v1`

## Authentication

Protected endpoints require a Firebase ID token in the Authorization header:

```
Authorization: Bearer <firebase_id_token>
```

The server verifies the token with Firebase and extracts the user ID from it.

## Common Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | For protected endpoints | `Bearer <firebase_id_token>` |
| `Content-Type` | For POST/PUT | Must be `application/json` |

## Error Response Format

All error responses follow this structure:

```json
{
  "error": "Human-readable error message"
}
```

## Status Code Summary

| Code | Meaning |
|------|---------|
| `200` | Success |
| `201` | Created (new resource) |
| `204` | No Content (successful deletion) |
| `400` | Bad Request (invalid input) |
| `401` | Unauthorized (missing or invalid token) |
| `403` | Forbidden (not enrolled in class) |
| `404` | Not Found |
| `409` | Conflict (duplicate enrollment) |
| `500` | Internal Server Error |

---

## Endpoints

### Classes (Public)

#### `GET /v1/classes`

List all classes in the catalog. Optionally filter by search query. **No authentication required.**

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `q` | string | No | Search query (matches class_code or class_name, case-insensitive) |

**Response: `200 OK`**

```json
{
  "classes": [
    {
      "id": "ecs_191",
      "class_code": "ECS 191",
      "class_name": "Design Project",
      "lecture_times": ["11:00 - 12:20 PM, TR"],
      "discussion_times": ["2:10 - 3:00 PM, T"]
    },
    {
      "id": "ecs_170",
      "class_code": "ECS 170",
      "class_name": "Introduction to Artificial Intelligence",
      "lecture_times": ["12:10 - 1:00 PM, MWF"],
      "discussion_times": ["5:10 - 6:00 PM, R"]
    }
  ]
}
```

---

#### `GET /v1/classes/:class_id`

Get details for a single class. **No authentication required.**

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `class_id` | string | The Firestore document ID of the class (e.g., `ecs_191`) |

**Response: `200 OK`**

```json
{
  "id": "ecs_191",
  "class_code": "ECS 191",
  "class_name": "Design Project"
}
```

**Response: `404 Not Found`**

```json
{
  "error": "Class not found"
}
```

---

### User Registration (Protected)

#### `POST /v1/users`

Register a new user in the database. Called after Firebase account creation.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**

```json
{
  "uid": "firebase_user_id",
  "email": "user@example.com",
  "display_name": "John Doe"
}
```

**Response: `201 Created`**

```json
{
  "uid": "firebase_user_id",
  "email": "user@example.com",
  "display_name": "John Doe"
}
```

**Response: `403 Forbidden`** (UID mismatch)

```json
{
  "error": "UID mismatch"
}
```

---

### Enrollment (Protected)

#### `POST /v1/users/me/classes`

Enroll the authenticated user in a class. This also grants access to the class group chat.

**Headers:** `Authorization: Bearer <token>`

**Request Body:**

```json
{
  "class_id": "ecs_191"
}
```

**Response: `201 Created`**

```json
{
  "id": "ecs_191",
  "class_code": "ECS 191",
  "class_name": "Design Project",
  "enrollment_id": "enroll_abc123"
}
```

**Response: `404 Not Found`**

```json
{
  "error": "Class not found"
}
```

**Response: `409 Conflict`** (already enrolled)

```json
{
  "error": "Already enrolled in this class"
}
```

---

#### `GET /v1/users/me/classes`

Get all classes the authenticated user is enrolled in.

**Headers:** `Authorization: Bearer <token>`

**Response: `200 OK`**

```json
{
  "classes": [
    {
      "id": "ecs_191",
      "class_code": "ECS 191",
      "class_name": "Design Project",
      "enrollment_id": "enroll_abc123"
    }
  ]
}
```

---

#### `DELETE /v1/users/me/classes/:enrollment_id`

Unenroll the authenticated user from a class. This also removes access to the class group chat.

**Headers:** `Authorization: Bearer <token>`

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `enrollment_id` | string | The Firestore document ID of the enrollment record |

**Response: `204 No Content`**

(Empty body)

**Response: `404 Not Found`**

```json
{
  "error": "Enrollment not found"
}
```

---

### Chat (Protected + Enrollment Required)

All chat endpoints require the user to be authenticated AND enrolled in the class. If not enrolled, the server returns `403 Forbidden`.

#### `GET /v1/classes/:class_id/messages`

Get chat messages for a class group chat. Messages are stored in Firestore under `classes/{class_id}/messages` and returned sorted by timestamp.

**Headers:** `Authorization: Bearer <token>`

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `class_id` | string | The Firestore document ID of the class (e.g., `ecs_032a`) |

**Response: `200 OK`**

```json
{
  "messages": [
    {
      "id": "msg_abc123",
      "class_id": "ecs_032a",
      "sender_id": "firebase_uid_123",
      "sender_name": "Alice Chen",
      "content": "Hey everyone! Anyone want to form a study group?",
      "timestamp": "2026-01-15T10:30:00Z"
    },
    {
      "id": "msg_def456",
      "class_id": "ecs_032a",
      "sender_id": "firebase_uid_456",
      "sender_name": "Bob Martinez",
      "content": "I'm in! When were you thinking?",
      "timestamp": "2026-01-15T10:35:00Z"
    }
  ]
}
```

**Response: `403 Forbidden`**

```json
{
  "error": "Not enrolled in this class"
}
```

---

#### `POST /v1/classes/:class_id/messages`

Send a message to the class group chat. The message is written to Firestore under `classes/{class_id}/messages` with a server timestamp. The iOS client receives the new message in real time via its Firestore snapshot listener.

**Headers:** `Authorization: Bearer <token>`

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `class_id` | string | The Firestore document ID of the class (e.g., `ecs_032a`) |

**Request Body:**

```json
{
  "content": "Hey everyone!"
}
```

**Response: `201 Created`**

```json
{
  "id": "msg_ghi789",
  "class_id": "ecs_032a",
  "sender_id": "firebase_uid_123",
  "sender_name": "John Doe",
  "content": "Hey everyone!",
  "timestamp": ""
}
```

**Response: `400 Bad Request`** (empty message)

```json
{
  "error": "content is required"
}
```

**Response: `403 Forbidden`**

```json
{
  "error": "Not enrolled in this class"
}
```

---

### Health Check

#### `GET /health`

Check if the server is running. **No authentication required.**

**Response: `200 OK`**

```json
{
  "status": "healthy"
}
```

---

## Endpoint Summary Table

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| `GET` | `/v1/classes` | List all classes | No |
| `GET` | `/v1/classes/:id` | Get single class | No |
| `POST` | `/v1/users` | Register new user | Yes |
| `GET` | `/v1/users/me/classes` | Get enrolled classes | Yes |
| `POST` | `/v1/users/me/classes` | Enroll in a class | Yes |
| `DELETE` | `/v1/users/me/classes/:id` | Unenroll from a class | Yes |
| `GET` | `/v1/classes/:id/messages` | Get chat messages | Yes + Enrolled |
| `POST` | `/v1/classes/:id/messages` | Send a chat message | Yes + Enrolled |
| `GET` | `/health` | Health check | No |

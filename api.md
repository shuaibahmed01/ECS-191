# API Reference

## Overview

The CourseHub REST API is served from Google App Engine under the `/v1/` prefix. All endpoints accept and return JSON. Authentication for Milestone 0 uses a simplified `X-User-Id` header.

**Base URL:** `https://<project-id>.appspot.com/v1`

## Authentication (M0)

Every request must include the `X-User-Id` header:

```
X-User-Id: 12345
```

The server trusts this header without verification for Milestone 0. This will be replaced with proper authentication in a later milestone.

## Common Headers

| Header | Required | Description |
|--------|----------|-------------|
| `X-User-Id` | Yes | The ID of the authenticated user |
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
| `403` | Forbidden (not enrolled in class) |
| `404` | Not Found |
| `409` | Conflict (duplicate enrollment) |
| `500` | Internal Server Error |

---

## Endpoints

### Classes

#### `GET /v1/classes`

List all classes in the catalog. Optionally filter by search query.

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `q` | string | No | Search query (matches class_code or class_name, case-insensitive) |

**Response: `200 OK`**

```json
{
  "classes": [
    {
      "id": 5634161670881280,
      "class_code": "ECS 191",
      "class_name": "Software Design Project",
      "quarter": "W26"
    },
    {
      "id": 5634161670881281,
      "class_code": "ECS 170",
      "class_name": "Intro to Artificial Intelligence",
      "quarter": "W26"
    }
  ]
}
```

**Example Request:**

```bash
curl -H "X-User-Id: 1" \
  "https://<project-id>.appspot.com/v1/classes?q=ECS%20191"
```

---

#### `GET /v1/classes/:class_id`

Get details for a single class.

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `class_id` | int | The Datastore key ID of the class |

**Response: `200 OK`**

```json
{
  "id": 5634161670881280,
  "class_code": "ECS 191",
  "class_name": "Software Design Project",
  "quarter": "W26"
}
```

**Response: `404 Not Found`**

```json
{
  "error": "Class not found"
}
```

---

### Enrollment

#### `POST /v1/users/:user_id/classes`

Enroll the user in a class. This also grants the user access to the class group chat.

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `user_id` | int | The user's ID |

**Request Body:**

```json
{
  "class_id": 5634161670881280
}
```

**Response: `201 Created`**

```json
{
  "id": 5741031244955648,
  "user_id": 1,
  "class_id": 5634161670881280
}
```

**Response: `409 Conflict`** (already enrolled)

```json
{
  "error": "Already enrolled"
}
```

**Example Request:**

```bash
curl -X POST \
  -H "X-User-Id: 1" \
  -H "Content-Type: application/json" \
  -d '{"class_id": 5634161670881280}' \
  "https://<project-id>.appspot.com/v1/users/1/classes"
```

---

#### `GET /v1/users/:user_id/classes`

Get all classes the user is enrolled in.

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `user_id` | int | The user's ID |

**Response: `200 OK`**

```json
{
  "classes": [
    {
      "id": 5634161670881280,
      "class_code": "ECS 191",
      "class_name": "Software Design Project",
      "quarter": "W26",
      "enrollment_id": 5741031244955648
    },
    {
      "id": 5634161670881281,
      "class_code": "ECS 170",
      "class_name": "Intro to Artificial Intelligence",
      "quarter": "W26",
      "enrollment_id": 5741031244955649
    }
  ]
}
```

---

#### `DELETE /v1/users/:user_id/classes/:enrollment_id`

Unenroll the user from a class. This also removes the user from the class group chat.

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `user_id` | int | The user's ID |
| `enrollment_id` | int | The Datastore key ID of the UserClass enrollment entity |

**Response: `204 No Content`**

(Empty body)

**Response: `404 Not Found`**

```json
{
  "error": "Enrollment not found"
}
```

**Example Request:**

```bash
curl -X DELETE \
  -H "X-User-Id: 1" \
  "https://<project-id>.appspot.com/v1/users/1/classes/5741031244955648"
```

---

### Chat

All chat endpoints require the user to be enrolled in the class. If not enrolled, the server returns `403 Forbidden`.

#### `GET /v1/classes/:class_id/chat/messages`

Get chat messages for a class group chat. Messages are returned newest first.

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `class_id` | int | The Datastore key ID of the class |

**Query Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `limit` | int | No | 50 | Maximum number of messages to return |
| `before` | string | No | - | ISO 8601 timestamp; only return messages before this time (for pagination) |

**Response: `200 OK`**

```json
{
  "messages": [
    {
      "id": 5678901234567890,
      "chat_id": 5634161670881280,
      "user_id": 1,
      "content": "Hey everyone! Who's working on the project?",
      "timestamp": "2026-01-15T10:30:00.000000"
    },
    {
      "id": 5678901234567891,
      "chat_id": 5634161670881280,
      "user_id": 2,
      "content": "I am! Want to meet up?",
      "timestamp": "2026-01-15T10:28:00.000000"
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

**Example Request:**

```bash
curl -H "X-User-Id: 1" \
  "https://<project-id>.appspot.com/v1/classes/5634161670881280/chat/messages?limit=20"
```

**Pagination Example:**

```bash
# Fetch the next page of messages (before the oldest message's timestamp)
curl -H "X-User-Id: 1" \
  "https://<project-id>.appspot.com/v1/classes/5634161670881280/chat/messages?limit=20&before=2026-01-15T10:28:00.000000"
```

---

#### `POST /v1/classes/:class_id/chat/messages`

Send a message to the class group chat.

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `class_id` | int | The Datastore key ID of the class |

**Request Body:**

```json
{
  "content": "Hey everyone! Who's working on the project?"
}
```

**Response: `201 Created`**

```json
{
  "id": 5678901234567890,
  "chat_id": 5634161670881280,
  "user_id": 1,
  "content": "Hey everyone! Who's working on the project?",
  "timestamp": "2026-01-15T10:30:00.000000"
}
```

**Response: `400 Bad Request`** (empty or blank message)

```json
{
  "error": "Message content cannot be empty"
}
```

**Response: `403 Forbidden`**

```json
{
  "error": "Not enrolled in this class"
}
```

**Example Request:**

```bash
curl -X POST \
  -H "X-User-Id: 1" \
  -H "Content-Type: application/json" \
  -d '{"content": "Hey everyone! Who'\''s working on the project?"}' \
  "https://<project-id>.appspot.com/v1/classes/5634161670881280/chat/messages"
```

---

#### `GET /v1/classes/:class_id/chat/members`

List all members of a class group chat (i.e., all users enrolled in the class).

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `class_id` | int | The Datastore key ID of the class |

**Response: `200 OK`**

```json
{
  "members": [
    {
      "id": 1,
      "name": "Shuaib Ahmed",
      "email": "sahmed@ucdavis.edu"
    },
    {
      "id": 2,
      "name": "Isa Bukhari",
      "email": "ibukhari@ucdavis.edu"
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

### Seed (Development Only)

#### `POST /v1/seed`

Populate the database with seed data (~13 UC Davis CS classes). This endpoint is idempotent -- it skips classes that already exist.

**Request Body:** None

**Response: `200 OK`**

```json
{
  "message": "Seeded 13 classes"
}
```

**Example Request:**

```bash
curl -X POST \
  "https://<project-id>.appspot.com/v1/seed"
```

---

## Endpoint Summary Table

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| `GET` | `/v1/classes` | List all classes (optional `?q=` search) | Yes |
| `GET` | `/v1/classes/:class_id` | Get single class | Yes |
| `POST` | `/v1/users/:user_id/classes` | Enroll in a class | Yes |
| `GET` | `/v1/users/:user_id/classes` | Get user's enrolled classes | Yes |
| `DELETE` | `/v1/users/:user_id/classes/:enrollment_id` | Unenroll from a class | Yes |
| `GET` | `/v1/classes/:class_id/chat/messages` | Get chat messages | Yes + Enrolled |
| `POST` | `/v1/classes/:class_id/chat/messages` | Send a chat message | Yes + Enrolled |
| `GET` | `/v1/classes/:class_id/chat/members` | List chat members | Yes + Enrolled |
| `POST` | `/v1/seed` | Seed database (dev only) | No |

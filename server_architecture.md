# Server Architecture

## Overview

The CourseHub backend is a Python Flask application. It follows a **Blueprint-based route handler** pattern with a **service layer** for all business logic and database access. The database is **Firestore** (Native mode), accessed via the `firebase-admin` SDK. Authentication uses **Firebase Authentication** -- the server verifies Firebase ID tokens on protected endpoints.

## Directory Structure

```
server/
├── main.py                      # Flask app factory, registers blueprints
├── requirements.txt             # Python dependencies
├── api/
│   ├── __init__.py
│   ├── classes.py               # Blueprint: class listing
│   ├── users.py                 # Blueprint: user registration & enrollment
│   └── chat.py                  # Blueprint: messaging endpoints
├── services/
│   ├── __init__.py
│   ├── datastore_service.py     # All Firestore CRUD operations
│   └── auth_service.py          # Firebase token verification & @require_auth decorator
└── tests/
    ├── __init__.py
    ├── conftest.py              # Pytest fixtures with mocked Firestore
    ├── test_auth.py             # Authentication & enrollment tests
    └── test_chat.py             # Chat endpoint tests
```

## Module Details

### `main.py` -- Flask App Factory

Creates the Flask app, initializes Firebase, and registers blueprints.

```python
from flask import Flask, jsonify
from api.classes import classes_bp
from api.chat import chat_bp
from api.users import users_bp
from services.auth_service import init_firebase

def create_app():
    app = Flask(__name__)
    init_firebase()

    app.register_blueprint(classes_bp, url_prefix="/v1")
    app.register_blueprint(chat_bp, url_prefix="/v1")
    app.register_blueprint(users_bp, url_prefix="/v1")

    @app.route("/health", methods=["GET"])
    def health():
        return jsonify({"status": "healthy"})

    return app

app = create_app()
```

### `services/auth_service.py` -- Authentication

Initializes the Firebase Admin SDK and provides token verification.

- `init_firebase()` -- Initializes Firebase Admin with default credentials or environment variable
- `verify_token(id_token)` -- Verifies a Firebase ID token and returns decoded claims
- `@require_auth` -- Decorator that extracts the Bearer token, verifies it, and sets `g.user_id`, `g.user_email`, `g.user_name` on Flask's request context

### `services/datastore_service.py` -- Database Abstraction Layer

This is the **only module** that directly interacts with Firestore. All route handlers call functions here. Every function **returns plain Python dicts**, never raw Firestore documents.

**Key functions:**

| Function | Description |
|----------|-------------|
| `get_all_classes(query="")` | Fetch all courses from the `courses` collection, optionally filtered |
| `get_class_by_id(class_id)` | Fetch a single course by Firestore doc ID |
| `enroll_user(user_id, class_id)` | Create enrollment under `users/{uid}/enrollments` |
| `get_user_classes(user_id)` | Get all classes a user is enrolled in |
| `unenroll_user(user_id, enrollment_id)` | Delete an enrollment document |
| `is_user_enrolled(user_id, class_id)` | Check if user has an enrollment for a class |
| `get_messages_for_class(class_id)` | Read messages from `classes/{class_id}/messages`, ordered by timestamp |
| `create_message(class_id, sender_id, sender_name, content)` | Write a message to Firestore with `SERVER_TIMESTAMP` |
| `create_user(uid, email, display_name)` | Create or update a user profile in `users/{uid}` |
| `get_user_by_id(uid)` | Fetch a user profile by Firebase UID |

### `api/classes.py` -- Class Listing Blueprint

```python
# GET /v1/classes         -- List all classes (public, no auth)
# GET /v1/classes/<id>    -- Get single class (public, no auth)
```

### `api/users.py` -- User & Enrollment Blueprint

```python
# POST   /v1/users                              -- Register user (requires auth)
# GET    /v1/users/me/classes                    -- Get enrolled classes (requires auth)
# POST   /v1/users/me/classes                    -- Enroll in class (requires auth)
# DELETE /v1/users/me/classes/<enrollment_id>    -- Unenroll (requires auth)
```

### `api/chat.py` -- Chat Blueprint

```python
# GET  /v1/classes/<class_id>/messages   -- Get messages (requires auth + enrollment)
# POST /v1/classes/<class_id>/messages   -- Send message (requires auth + enrollment)
```

Both endpoints use the `@require_auth` decorator and check `is_user_enrolled()` before allowing access.

## Firestore Data Model

| Collection Path | Fields | Description |
|----------------|--------|-------------|
| `courses/{doc_id}` | `code`, `name`, `lecture_times`, `discussion_times` | Course catalog (doc ID is sanitized code, e.g., `ecs_170`) |
| `users/{uid}` | `uid`, `email`, `display_name` | User profile (doc ID = Firebase UID) |
| `users/{uid}/enrollments/{doc_id}` | `class_id`, `enrolled_at` | Enrollment records (auto-generated doc IDs) |
| `classes/{class_id}/messages/{doc_id}` | `sender_id`, `sender_name`, `content`, `timestamp` | Chat messages (auto-generated doc IDs, server timestamp) |

## Database Abstraction Strategy

The database is abstracted so it can be swapped with minimal changes:

1. **Only `datastore_service.py` touches the Firestore client.**
2. **Service functions return plain Python dicts**, never raw Firestore documents.
3. **Blueprints never import Firestore directly** -- they only call service functions.

```
+--------------+     +----------------------+     +-------------------+
|  api/         |     |  services/            |     |  Firestore        |
|  (Blueprints) |---->|  datastore_service.py |---->|  (Native Mode)    |
|               |     |  returns dicts        |     |                   |
+--------------+     +----------------------+     +-------------------+
```

## Authentication

All protected endpoints require a Firebase ID token in the `Authorization` header:

```
Authorization: Bearer <firebase_id_token>
```

The `@require_auth` decorator:
1. Extracts the token from the header
2. Calls `firebase_admin.auth.verify_id_token()` to validate it
3. Sets `g.user_id`, `g.user_email`, `g.user_name` for use in the route handler
4. Returns `401 Unauthorized` if the token is missing or invalid

## Requirements

```
Flask==3.0.*
gunicorn==21.*
pytest==8.*
firebase-admin==6.*
```

The `firebase-admin` package includes `google-cloud-firestore` as a transitive dependency.

## Testing

Tests use `pytest` with a fully mocked Firestore backend.

- **`tests/conftest.py`**: Creates a mock Firestore DB that stores enrollments, users, and messages in Python dicts. Patches `_get_db()` and `init_firebase()` so no real Firebase connection is needed.
- **`tests/test_auth.py`**: Tests for public vs. protected endpoints, enrollment with auth.
- **`tests/test_chat.py`**: Tests for GET/POST messages, enrollment-based access control, message persistence.

The `AuthClient` test helper patches `verify_token` to simulate authenticated requests without real Firebase tokens.

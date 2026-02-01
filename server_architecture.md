# Server Architecture

## Overview

The CourseHub backend is a Python 3.12 Flask application deployed on Google App Engine (Standard Environment). It follows the professor's prescribed architecture: **Blueprint-based route handlers**, a **service layer** for all business logic and database access, and a **models module** for entity definitions. The database is Firestore in Datastore Mode, accessed via the `google-cloud-datastore` package.

## Directory Structure

```
server/
├── main.py                      # Flask app factory, registers blueprints
├── models.py                    # Entity kind constants + helper functions
├── seed_data.py                 # Hardcoded class list + seed function
├── app.yaml                     # GAE config (Python 3.12, gunicorn)
├── requirements.txt             # Python dependencies
├── test_api.py                  # API integration tests
├── conftest.py                  # Pytest fixtures
├── api/
│   ├── __init__.py
│   ├── classes.py               # Blueprint: class listing + enrollment
│   └── chat.py                  # Blueprint: messaging endpoints
└── services/
    ├── __init__.py
    └── datastore_service.py     # All Datastore CRUD operations
```

## Module Details

### `main.py` -- Flask App Factory

The entry point for the application. Creates the Flask app, registers blueprints, and configures any middleware.

```python
from flask import Flask, jsonify
from api.classes import classes_bp
from api.chat import chat_bp
from seed_data import seed_database

def create_app():
    app = Flask(__name__)

    # Register blueprints under /v1 prefix
    app.register_blueprint(classes_bp, url_prefix="/v1")
    app.register_blueprint(chat_bp, url_prefix="/v1")

    @app.route("/v1/seed", methods=["POST"])
    def seed():
        """POST /v1/seed -- Populate DB with seed data (dev only)."""
        count = seed_database()
        return jsonify({"message": f"Seeded {count} classes"}), 200

    return app

app = create_app()
```

### `models.py` -- Entity Definitions

Defines entity Kind constants and helper functions for creating Datastore entities. This project uses `google-cloud-datastore` (NOT NDB), so entities are plain dictionaries, not ORM model instances.

```python
from google.cloud import datastore

# Entity Kind constants
KIND_CLASS = "Class"
KIND_USER = "User"
KIND_USER_CLASS = "UserClass"
KIND_MESSAGE = "Message"

client = datastore.Client()

def make_class_entity(class_code, class_name, quarter):
    """Create a Class entity."""
    key = client.key(KIND_CLASS)
    entity = datastore.Entity(key=key)
    entity.update({
        "class_code": class_code,
        "class_name": class_name,
        "quarter": quarter,
    })
    return entity

def make_user_entity(name, email):
    """Create a User entity."""
    key = client.key(KIND_USER)
    entity = datastore.Entity(key=key)
    entity.update({
        "name": name,
        "email": email,
    })
    return entity

def make_user_class_entity(user_id, class_id):
    """Create a UserClass (enrollment) entity."""
    key = client.key(KIND_USER_CLASS)
    entity = datastore.Entity(key=key)
    entity.update({
        "user_id": user_id,
        "class_id": class_id,
    })
    return entity

def make_message_entity(chat_id, user_id, content, timestamp):
    """Create a Message entity. chat_id is the class_id."""
    key = client.key(KIND_MESSAGE)
    entity = datastore.Entity(key=key)
    entity.update({
        "chat_id": chat_id,
        "user_id": user_id,
        "content": content,
        "timestamp": timestamp,
    })
    return entity
```

**Data Model Summary:**

| Kind | Fields | Description |
|------|--------|-------------|
| `Class` | `class_code`, `class_name`, `quarter` | A course in the catalog (seed data) |
| `User` | `name`, `email` | A student using the app |
| `UserClass` | `user_id`, `class_id` | Enrollment join -- also defines chat membership |
| `Message` | `chat_id`, `user_id`, `content`, `timestamp` | A chat message (`chat_id` = `class_id`) |

### `api/classes.py` -- Class & Enrollment Blueprint

Handles all endpoints related to browsing the class catalog and managing enrollment.

```python
from flask import Blueprint, request, jsonify
from services.datastore_service import (
    get_all_classes,
    get_class_by_id,
    enroll_user,
    get_user_classes,
    unenroll_user,
)

classes_bp = Blueprint("classes", __name__)

@classes_bp.route("/classes", methods=["GET"])
def list_classes():
    """GET /v1/classes -- List all classes, optional ?q= search."""
    q = request.args.get("q", "")
    classes = get_all_classes(query=q)
    return jsonify({"classes": classes}), 200

@classes_bp.route("/classes/<int:class_id>", methods=["GET"])
def get_class(class_id):
    """GET /v1/classes/:class_id -- Get a single class."""
    cls = get_class_by_id(class_id)
    if not cls:
        return jsonify({"error": "Class not found"}), 404
    return jsonify(cls), 200

@classes_bp.route("/users/<int:user_id>/classes", methods=["POST"])
def add_class(user_id):
    """POST /v1/users/:user_id/classes -- Enroll in a class."""
    data = request.get_json()
    class_id = data.get("class_id")
    enrollment = enroll_user(user_id, class_id)
    if enrollment is None:
        return jsonify({"error": "Already enrolled"}), 409
    return jsonify(enrollment), 201

@classes_bp.route("/users/<int:user_id>/classes", methods=["GET"])
def list_user_classes(user_id):
    """GET /v1/users/:user_id/classes -- Get user's enrolled classes."""
    classes = get_user_classes(user_id)
    return jsonify({"classes": classes}), 200

@classes_bp.route("/users/<int:user_id>/classes/<int:enrollment_id>", methods=["DELETE"])
def remove_class(user_id, enrollment_id):
    """DELETE /v1/users/:user_id/classes/:enrollment_id -- Unenroll."""
    success = unenroll_user(user_id, enrollment_id)
    if not success:
        return jsonify({"error": "Enrollment not found"}), 404
    return "", 204
```

### `api/chat.py` -- Chat Blueprint

Handles messaging endpoints for class group chats.

```python
from flask import Blueprint, request, jsonify
from services.datastore_service import (
    get_chat_messages,
    send_message,
    get_chat_members,
    is_user_enrolled,
)

chat_bp = Blueprint("chat", __name__)

@chat_bp.route("/classes/<int:class_id>/chat/messages", methods=["GET"])
def list_messages(class_id):
    """GET /v1/classes/:class_id/chat/messages -- Get chat messages."""
    user_id = request.headers.get("X-User-Id")
    if not is_user_enrolled(user_id, class_id):
        return jsonify({"error": "Not enrolled in this class"}), 403

    limit = request.args.get("limit", 50, type=int)
    before = request.args.get("before", None)
    messages = get_chat_messages(class_id, limit=limit, before=before)
    return jsonify({"messages": messages}), 200

@chat_bp.route("/classes/<int:class_id>/chat/messages", methods=["POST"])
def create_message(class_id):
    """POST /v1/classes/:class_id/chat/messages -- Send a message."""
    user_id = request.headers.get("X-User-Id")
    if not is_user_enrolled(user_id, class_id):
        return jsonify({"error": "Not enrolled in this class"}), 403

    data = request.get_json()
    content = data.get("content", "").strip()
    if not content:
        return jsonify({"error": "Message content cannot be empty"}), 400

    message = send_message(class_id, user_id, content)
    return jsonify(message), 201

@chat_bp.route("/classes/<int:class_id>/chat/members", methods=["GET"])
def list_members(class_id):
    """GET /v1/classes/:class_id/chat/members -- List chat members."""
    user_id = request.headers.get("X-User-Id")
    if not is_user_enrolled(user_id, class_id):
        return jsonify({"error": "Not enrolled in this class"}), 403

    members = get_chat_members(class_id)
    return jsonify({"members": members}), 200
```

### `services/datastore_service.py` -- Database Abstraction Layer

This is the **only module** (along with `models.py`) that directly interacts with the Datastore client. All other modules call functions here. Every function **returns plain Python dicts**, never raw Datastore entities. This makes it easy to swap the database later.

```python
from google.cloud import datastore
from models import (
    KIND_CLASS, KIND_USER, KIND_USER_CLASS, KIND_MESSAGE,
    make_user_class_entity, make_message_entity,
)
import datetime

client = datastore.Client()

def entity_to_dict(entity):
    """Convert a Datastore entity to a plain dict with its id."""
    d = dict(entity)
    d["id"] = entity.key.id
    return d

# --- Class operations ---

def get_all_classes(query=""):
    """Return all classes, optionally filtered by search query."""
    q = client.query(kind=KIND_CLASS)
    results = list(q.fetch())
    classes = [entity_to_dict(e) for e in results]
    if query:
        query_lower = query.lower()
        classes = [
            c for c in classes
            if query_lower in c["class_code"].lower()
            or query_lower in c["class_name"].lower()
        ]
    return classes

def get_class_by_id(class_id):
    """Return a single class by ID, or None."""
    key = client.key(KIND_CLASS, class_id)
    entity = client.get(key)
    return entity_to_dict(entity) if entity else None

# --- Enrollment operations ---

def enroll_user(user_id, class_id):
    """Enroll a user in a class. Returns enrollment dict or None if duplicate."""
    # Check for duplicate
    q = client.query(kind=KIND_USER_CLASS)
    q.add_filter("user_id", "=", user_id)
    q.add_filter("class_id", "=", class_id)
    if list(q.fetch(limit=1)):
        return None  # Already enrolled

    entity = make_user_class_entity(user_id, class_id)
    client.put(entity)
    return entity_to_dict(entity)

def get_user_classes(user_id):
    """Return all classes a user is enrolled in."""
    q = client.query(kind=KIND_USER_CLASS)
    q.add_filter("user_id", "=", user_id)
    enrollments = list(q.fetch())
    # Fetch full class details for each enrollment
    classes = []
    for enrollment in enrollments:
        cls = get_class_by_id(enrollment["class_id"])
        if cls:
            cls["enrollment_id"] = enrollment.key.id
            classes.append(cls)
    return classes

def unenroll_user(user_id, enrollment_id):
    """Remove an enrollment. Returns True on success, False if not found."""
    key = client.key(KIND_USER_CLASS, enrollment_id)
    entity = client.get(key)
    if not entity or entity["user_id"] != user_id:
        return False
    client.delete(key)
    return True

def is_user_enrolled(user_id, class_id):
    """Check if a user is enrolled in a class."""
    q = client.query(kind=KIND_USER_CLASS)
    q.add_filter("user_id", "=", int(user_id))
    q.add_filter("class_id", "=", int(class_id))
    return len(list(q.fetch(limit=1))) > 0

# --- Chat operations ---

def get_chat_messages(class_id, limit=50, before=None):
    """Return chat messages for a class, newest first."""
    q = client.query(kind=KIND_MESSAGE)
    q.add_filter("chat_id", "=", class_id)
    q.order = ["-timestamp"]
    if before:
        q.add_filter("timestamp", "<", before)
    results = list(q.fetch(limit=limit))
    return [entity_to_dict(e) for e in results]

def send_message(class_id, user_id, content):
    """Create and store a new chat message."""
    entity = make_message_entity(
        chat_id=class_id,
        user_id=int(user_id),
        content=content,
        timestamp=datetime.datetime.utcnow().isoformat(),
    )
    client.put(entity)
    return entity_to_dict(entity)

def get_chat_members(class_id):
    """Return all users enrolled in a class (i.e., chat members)."""
    q = client.query(kind=KIND_USER_CLASS)
    q.add_filter("class_id", "=", class_id)
    enrollments = list(q.fetch())
    members = []
    for enrollment in enrollments:
        key = client.key(KIND_USER, enrollment["user_id"])
        user = client.get(key)
        if user:
            members.append(entity_to_dict(user))
    return members
```

### `seed_data.py` -- Seed Data

Contains a hardcoded list of ~13 UC Davis CS classes and a function to populate the database.

```python
from google.cloud import datastore
from models import KIND_CLASS, make_class_entity

SEED_CLASSES = [
    {"class_code": "ECS 032A", "class_name": "Introduction to Programming", "quarter": "W26"},
    {"class_code": "ECS 032B", "class_name": "Introduction to Data Structures", "quarter": "W26"},
    {"class_code": "ECS 036A", "class_name": "Programming & Problem Solving", "quarter": "W26"},
    {"class_code": "ECS 036B", "class_name": "Software Development & OOP", "quarter": "W26"},
    {"class_code": "ECS 036C", "class_name": "Data Structures & Algorithms", "quarter": "W26"},
    {"class_code": "ECS 050", "class_name": "Computer Organization & Machine-Dependent Programming", "quarter": "W26"},
    {"class_code": "ECS 120", "class_name": "Theory of Computation", "quarter": "W26"},
    {"class_code": "ECS 122A", "class_name": "Algorithm Design & Analysis", "quarter": "W26"},
    {"class_code": "ECS 140A", "class_name": "Programming Languages", "quarter": "W26"},
    {"class_code": "ECS 150", "class_name": "Operating Systems", "quarter": "W26"},
    {"class_code": "ECS 160", "class_name": "Software Engineering", "quarter": "W26"},
    {"class_code": "ECS 170", "class_name": "Intro to Artificial Intelligence", "quarter": "W26"},
    {"class_code": "ECS 191", "class_name": "Software Design Project", "quarter": "W26"},
]

client = datastore.Client()

def seed_database():
    """Insert all seed classes into Datastore (idempotent -- skips existing)."""
    q = client.query(kind=KIND_CLASS)
    existing = {e["class_code"] for e in q.fetch()}

    for cls_data in SEED_CLASSES:
        if cls_data["class_code"] not in existing:
            entity = make_class_entity(**cls_data)
            client.put(entity)

    return len(SEED_CLASSES)
```

### `app.yaml` -- GAE Configuration

```yaml
runtime: python312
instance_class: F1
entrypoint: gunicorn -b :$PORT main:app

env_variables:
  GOOGLE_CLOUD_PROJECT: "coursehub-project-id"
```

### `requirements.txt`

```
Flask==3.0.*
gunicorn==21.*
google-cloud-datastore==2.*
```

## Database Abstraction Strategy

The database is abstracted so it can be swapped with minimal changes:

1. **Only two files touch the Datastore client:** `models.py` and `services/datastore_service.py`.
2. **Service functions return plain Python dicts**, never raw Datastore entities.
3. **Blueprints (route handlers) never import Datastore directly** -- they only call service functions.
4. **To swap the database**, replace `datastore_service.py` with a new service module (e.g., `postgres_service.py`) that exposes the same function signatures and returns the same dict shapes.

```
┌──────────────┐     ┌──────────────────────┐     ┌─────────────────────────┐
│  api/         │     │  services/            │     │  Firestore              │
│  (Blueprints) │────>│  datastore_service.py │────>│  (Datastore Mode)       │
│               │     │  returns dicts        │     │                         │
└──────────────┘     └──────────────────────┘     └─────────────────────────┘
                              │
                              v
                     Only file to swap
                     when changing DB
```

## Authentication (M0 Simplified)

For Milestone 0, there is no login/signup flow. Instead, every request includes an `X-User-Id` header that identifies the user:

```
X-User-Id: 12345
```

The server trusts this header without verification. This will be replaced with proper authentication (e.g., Firebase Auth or JWT tokens) in a later milestone.

## Testing

Tests are written with `pytest` and use the Flask test client.

- **`test_api.py`**: Integration tests for all API endpoints
- **`conftest.py`**: Shared fixtures (e.g., test client, seeded database)

```python
# conftest.py example
import pytest
from main import create_app

@pytest.fixture
def app():
    app = create_app()
    app.config["TESTING"] = True
    return app

@pytest.fixture
def client(app):
    return app.test_client()
```

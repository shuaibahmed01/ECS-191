"""In-memory data service for CourseHub (M0 implementation)."""

from datetime import datetime, timezone
from seed_data import SEED_CLASSES, SEED_MESSAGES

# In-memory storage
_classes = {}        # id -> class dict
_enrollments = {}    # id -> enrollment dict
_messages = {}       # id -> message dict
_users = {}          # uid (string) -> user dict
_next_enrollment_id = 1
_next_message_id = 1


def seed_classes_in_memory():
    """Load seed data into memory."""
    global _classes
    _classes = {c["id"]: c.copy() for c in SEED_CLASSES}
    seed_messages_in_memory()
    return len(_classes)


def seed_messages_in_memory():
    """Load seed messages into memory."""
    global _messages, _next_message_id
    _messages = {m["id"]: m.copy() for m in SEED_MESSAGES}
    if SEED_MESSAGES:
        _next_message_id = max(m["id"] for m in SEED_MESSAGES) + 1
    else:
        _next_message_id = 1


def get_all_classes(query=""):
    """Return all classes, optionally filtered by query string."""
    classes = list(_classes.values())
    if query:
        query_lower = query.lower()
        classes = [
            c for c in classes
            if query_lower in c["class_code"].lower()
            or query_lower in c["class_name"].lower()
        ]
    return classes


def get_class_by_id(class_id):
    """Return a single class by ID, or None if not found."""
    return _classes.get(class_id)


def enroll_user(user_id, class_id):
    """
    Create an enrollment for a user in a class.
    Returns the enrollment dict, or None if already enrolled.
    """
    global _next_enrollment_id

    # Check if class exists
    if class_id not in _classes:
        return None

    # Check if already enrolled
    if is_user_enrolled(user_id, class_id):
        return None

    enrollment = {
        "id": _next_enrollment_id,
        "user_id": user_id,
        "class_id": class_id
    }
    _enrollments[_next_enrollment_id] = enrollment
    _next_enrollment_id += 1

    return enrollment


def get_user_classes(user_id):
    """Return all classes a user is enrolled in, with enrollment_id."""
    user_enrollments = [
        e for e in _enrollments.values()
        if e["user_id"] == user_id
    ]

    result = []
    for enrollment in user_enrollments:
        class_data = _classes.get(enrollment["class_id"])
        if class_data:
            entry = class_data.copy()
            entry["enrollment_id"] = enrollment["id"]
            result.append(entry)

    return result


def unenroll_user(user_id, enrollment_id):
    """
    Delete an enrollment.
    Returns True if successful, False if not found or not owned by user.
    """
    enrollment = _enrollments.get(enrollment_id)
    if not enrollment:
        return False
    if enrollment["user_id"] != user_id:
        return False

    del _enrollments[enrollment_id]
    return True


def is_user_enrolled(user_id, class_id):
    """Check if a user is enrolled in a specific class."""
    for enrollment in _enrollments.values():
        if enrollment["user_id"] == user_id and enrollment["class_id"] == class_id:
            return True
    return False


def get_messages_for_class(class_id):
    """Return all messages for a class, sorted by timestamp."""
    messages = [
        m for m in _messages.values()
        if m["class_id"] == class_id
    ]
    messages.sort(key=lambda m: m["timestamp"])
    return messages


def create_message(class_id, sender_id, sender_name, content):
    """
    Create a new message in a class chat.
    Returns the message dict.
    """
    global _next_message_id

    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    message = {
        "id": _next_message_id,
        "class_id": class_id,
        "sender_id": sender_id,
        "sender_name": sender_name,
        "content": content,
        "timestamp": timestamp
    }
    _messages[_next_message_id] = message
    _next_message_id += 1

    return message


def create_user(uid, email, display_name):
    """
    Create or update a user in the database.
    Returns the user dict.
    """
    user = {
        "uid": uid,
        "email": email,
        "display_name": display_name
    }
    _users[uid] = user
    return user


def get_user_by_id(uid):
    """Return a user by their Firebase UID, or None if not found."""
    return _users.get(uid)

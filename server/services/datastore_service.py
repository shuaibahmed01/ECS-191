"""Data service for CourseHub with Firestore for enrollments and courses."""

from datetime import datetime, timezone
from seed_data import SEED_MESSAGES
from firebase_admin import firestore

# In-memory storage (for messages)
_messages = {}       # id -> message dict
_next_message_id = 1

# Firestore client (initialized lazily)
_db = None

def _get_db():
    """Get Firestore client, initializing if needed."""
    global _db
    if _db is None:
        _db = firestore.client()
    return _db


def seed_messages_in_memory():
    """Load seed messages into memory."""
    global _messages, _next_message_id
    _messages = {m["id"]: m.copy() for m in SEED_MESSAGES}
    if SEED_MESSAGES:
        _next_message_id = max(m["id"] for m in SEED_MESSAGES) + 1
    else:
        _next_message_id = 1


def get_all_classes(query=""):
    """Return all classes from Firestore, optionally filtered by query string."""
    db = _get_db()
    docs = db.collection("courses").stream()

    classes = []
    for doc in docs:
        data = doc.to_dict()
        classes.append({
            "id": doc.id,
            "class_code": data.get("code", ""),
            "class_name": data.get("name", ""),
            "lecture_times": data.get("lecture_times", []),
            "discussion_times": data.get("discussion_times", []),
        })

    if query:
        query_lower = query.lower()
        classes = [
            c for c in classes
            if query_lower in c["class_code"].lower()
            or query_lower in c["class_name"].lower()
        ]
    return classes


def get_class_by_id(class_id):
    """Return a single class by Firestore document ID, or None if not found."""
    db = _get_db()
    doc = db.collection("courses").document(class_id).get()
    if not doc.exists:
        return None
    data = doc.to_dict()
    return {
        "id": doc.id,
        "class_code": data.get("code", ""),
        "class_name": data.get("name", ""),
        "lecture_times": data.get("lecture_times", []),
        "discussion_times": data.get("discussion_times", []),
    }


def enroll_user(user_id, class_id):
    """
    Create an enrollment for a user in a class.
    Returns the enrollment dict, or None if already enrolled.
    """
    db = _get_db()

    # Check if class exists
    if get_class_by_id(class_id) is None:
        return None

    # Check if already enrolled
    if is_user_enrolled(user_id, class_id):
        return None

    # Create enrollment in Firestore
    enrollment_ref = db.collection('users').document(user_id).collection('enrollments').document()
    enrollment_data = {
        "class_id": class_id,
        "enrolled_at": firestore.SERVER_TIMESTAMP
    }
    enrollment_ref.set(enrollment_data)

    return {
        "id": enrollment_ref.id,
        "user_id": user_id,
        "class_id": class_id
    }


def get_user_classes(user_id):
    """Return all classes a user is enrolled in, with enrollment_id."""
    db = _get_db()

    # Get enrollments from Firestore
    enrollments_ref = db.collection('users').document(user_id).collection('enrollments')
    enrollments = enrollments_ref.stream()

    result = []
    for enrollment in enrollments:
        enrollment_data = enrollment.to_dict()
        class_data = get_class_by_id(enrollment_data["class_id"])
        if class_data:
            entry = class_data.copy()
            entry["enrollment_id"] = enrollment.id
            result.append(entry)

    return result


def unenroll_user(user_id, enrollment_id):
    """
    Delete an enrollment.
    Returns True if successful, False if not found or not owned by user.
    """
    db = _get_db()

    # Get the enrollment document
    enrollment_ref = db.collection('users').document(user_id).collection('enrollments').document(str(enrollment_id))
    enrollment_doc = enrollment_ref.get()

    if not enrollment_doc.exists:
        return False

    # Delete the enrollment
    enrollment_ref.delete()
    return True


def is_user_enrolled(user_id, class_id):
    """Check if a user is enrolled in a specific class."""
    db = _get_db()

    # Query Firestore for matching enrollment
    enrollments_ref = db.collection('users').document(user_id).collection('enrollments')
    query = enrollments_ref.where("class_id", "==", class_id).limit(1)
    results = list(query.stream())

    return len(results) > 0


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
    Create or update a user in Firestore.
    Returns the user dict.
    """
    db = _get_db()
    user = {
        "uid": uid,
        "email": email,
        "display_name": display_name
    }
    db.collection('users').document(uid).set(user, merge=True)
    return user


def get_user_by_id(uid):
    """Return a user by their Firebase UID, or None if not found."""
    db = _get_db()
    doc = db.collection('users').document(uid).get()
    if not doc.exists:
        return None
    return doc.to_dict()

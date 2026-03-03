"""Data service for CourseHub with Firestore for enrollments, courses, and messages."""

from firebase_admin import firestore

# Firestore client (initialized lazily)
_db = None

def _get_db():
    """Get Firestore client, initializing if needed."""
    global _db
    if _db is None:
        _db = firestore.client()
    return _db


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

def _slugify_code(code: str) -> str:
    """
    Convert a human-readable class code into a Firestore-safe document ID.
    Example: 'MGT 120' -> 'mgt_120'
    """
    import re
    slug = code.strip().lower()
    slug = re.sub(r"\s+", "_", slug)
    slug = re.sub(r"[^a-z0-9_]", "", slug)
    return slug

def create_class(code: str, name: str, lecture_times=None, discussion_times=None):
    """
    Create or upsert a class in the courses collection.
    Returns the created class dict. If the class already exists, returns the existing data.
    """
    db = _get_db()
    lecture_times = lecture_times or []
    discussion_times = discussion_times or []

    class_id = _slugify_code(code) or _slugify_code(name)
    if not class_id:
        raise ValueError("Invalid class identifier")

    doc_ref = db.collection("courses").document(class_id)
    existing = doc_ref.get()
    data = {
        "code": code,
        "name": name,
        "lecture_times": lecture_times,
        "discussion_times": discussion_times,
    }
    # Upsert to allow users to fix typos or add times later
    doc_ref.set(data, merge=True)

    return {
        "id": class_id,
        "class_code": code,
        "class_name": name,
        "lecture_times": lecture_times,
        "discussion_times": discussion_times,
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
    db = _get_db()
    messages_ref = db.collection("classes").document(class_id).collection("messages")
    query = messages_ref.order_by("timestamp")
    docs = query.stream()

    messages = []
    for doc in docs:
        data = doc.to_dict()
        ts = data.get("timestamp")
        if hasattr(ts, 'isoformat'):
            timestamp_str = ts.strftime("%Y-%m-%dT%H:%M:%SZ")
        else:
            timestamp_str = str(ts) if ts else ""

        messages.append({
            "id": doc.id,
            "class_id": class_id,
            "sender_id": data.get("sender_id", ""),
            "sender_name": data.get("sender_name", ""),
            "content": data.get("content", ""),
            "attachment_url": data.get("attachment_url", ""),
            "attachment_type": data.get("attachment_type", ""),
            "timestamp": timestamp_str,
        })
    return messages


def create_message(class_id, sender_id, sender_name, content, attachment_url=None, attachment_type=None):
    """
    Create a new message in a class chat.
    Returns the message dict.
    """
    db = _get_db()
    messages_ref = db.collection("classes").document(class_id).collection("messages")

    message_data = {
        "sender_id": sender_id,
        "sender_name": sender_name,
        "content": content or "",
        "timestamp": firestore.SERVER_TIMESTAMP,
    }
    if attachment_url:
        message_data["attachment_url"] = attachment_url
    if attachment_type:
        message_data["attachment_type"] = attachment_type
    doc_ref = messages_ref.add(message_data)
    # .add() returns a tuple of (timestamp, doc_ref)
    new_doc_ref = doc_ref[1]

    return {
        "id": new_doc_ref.id,
        "class_id": class_id,
        "sender_id": sender_id,
        "sender_name": sender_name,
        "content": content,
        "attachment_url": attachment_url or "",
        "attachment_type": attachment_type or "",
        "timestamp": "",  # server timestamp not yet resolved
    }


def get_enrolled_class_ids(user_id):
    """Return a list of class_ids the user is enrolled in."""
    classes = get_user_classes(user_id)
    return [c["id"] for c in classes]


def get_recent_messages_for_class(class_id, limit=100):
    """Return up to `limit` most recent messages for a class."""
    db = _get_db()
    messages_ref = db.collection("classes").document(class_id).collection("messages")
    query = messages_ref.order_by("timestamp", direction=firestore.Query.DESCENDING).limit(limit)
    docs = query.stream()
    result = []
    for doc in docs:
        data = doc.to_dict()
        result.append({
            "id": doc.id,
            "class_id": class_id,
            "sender_id": data.get("sender_id", ""),
            "sender_name": data.get("sender_name", ""),
            "content": data.get("content", ""),
            "attachment_url": data.get("attachment_url", ""),
            "attachment_type": data.get("attachment_type", ""),
        })
    return result


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

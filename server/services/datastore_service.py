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
            "timestamp": timestamp_str,
        })
    return messages


def create_message(class_id, sender_id, sender_name, content):
    """
    Create a new message in a class chat.
    Returns the message dict.
    """
    db = _get_db()
    messages_ref = db.collection("classes").document(class_id).collection("messages")

    message_data = {
        "sender_id": sender_id,
        "sender_name": sender_name,
        "content": content,
        "timestamp": firestore.SERVER_TIMESTAMP,
    }
    doc_ref = messages_ref.add(message_data)
    # .add() returns a tuple of (timestamp, doc_ref)
    new_doc_ref = doc_ref[1]

    return {
        "id": new_doc_ref.id,
        "class_id": class_id,
        "sender_id": sender_id,
        "sender_name": sender_name,
        "content": content,
        "timestamp": "",  # server timestamp not yet resolved
    }


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


# ── Forum (course-wide posts / comments / upvotes) ─────────────────────

def get_posts_for_course(course_id):
    """Return all posts for a course, newest first."""
    db = _get_db()
    posts_ref = db.collection("courses").document(course_id).collection("posts")
    query = posts_ref.order_by("created_at", direction=firestore.Query.DESCENDING)
    docs = query.stream()

    posts = []
    for doc in docs:
        data = doc.to_dict()
        ts = data.get("created_at")
        if hasattr(ts, 'isoformat'):
            timestamp_str = ts.strftime("%Y-%m-%dT%H:%M:%SZ")
        else:
            timestamp_str = str(ts) if ts else ""

        posts.append({
            "id": doc.id,
            "course_id": course_id,
            "author_id": data.get("author_id", ""),
            "author_name": data.get("author_name", ""),
            "title": data.get("title", ""),
            "body": data.get("body", ""),
            "upvote_count": data.get("upvote_count", 0),
            "comment_count": data.get("comment_count", 0),
            "created_at": timestamp_str,
        })
    return posts


def create_post(course_id, author_id, author_name, title, body):
    """Create a new forum post. Returns the post dict."""
    db = _get_db()
    posts_ref = db.collection("courses").document(course_id).collection("posts")

    post_data = {
        "author_id": author_id,
        "author_name": author_name,
        "title": title,
        "body": body,
        "upvote_count": 0,
        "comment_count": 0,
        "created_at": firestore.SERVER_TIMESTAMP,
    }
    result = posts_ref.add(post_data)
    new_doc_ref = result[1]

    return {
        "id": new_doc_ref.id,
        "course_id": course_id,
        "author_id": author_id,
        "author_name": author_name,
        "title": title,
        "body": body,
        "upvote_count": 0,
        "comment_count": 0,
        "created_at": "",
    }


def get_post_by_id(course_id, post_id):
    """Return a single post by ID, or None if not found."""
    db = _get_db()
    doc = (
        db.collection("courses")
        .document(course_id)
        .collection("posts")
        .document(post_id)
        .get()
    )
    if not doc.exists:
        return None
    data = doc.to_dict()
    ts = data.get("created_at")
    if hasattr(ts, 'isoformat'):
        timestamp_str = ts.strftime("%Y-%m-%dT%H:%M:%SZ")
    else:
        timestamp_str = str(ts) if ts else ""

    return {
        "id": doc.id,
        "course_id": course_id,
        "author_id": data.get("author_id", ""),
        "author_name": data.get("author_name", ""),
        "title": data.get("title", ""),
        "body": data.get("body", ""),
        "upvote_count": data.get("upvote_count", 0),
        "comment_count": data.get("comment_count", 0),
        "created_at": timestamp_str,
    }


def check_user_upvoted(course_id, post_id, user_id):
    """Check if a user has upvoted a post."""
    db = _get_db()
    doc = (
        db.collection("courses")
        .document(course_id)
        .collection("posts")
        .document(post_id)
        .collection("upvotes")
        .document(user_id)
        .get()
    )
    return doc.exists


def toggle_upvote(course_id, post_id, user_id):
    """Toggle upvote on a post. Returns (upvoted: bool, new_count: int)."""
    db = _get_db()
    post_ref = (
        db.collection("courses")
        .document(course_id)
        .collection("posts")
        .document(post_id)
    )
    upvote_ref = post_ref.collection("upvotes").document(user_id)
    upvote_doc = upvote_ref.get()

    if upvote_doc.exists:
        upvote_ref.delete()
        post_ref.update({"upvote_count": firestore.Increment(-1)})
        # Read back updated count
        updated = post_ref.get()
        new_count = updated.to_dict().get("upvote_count", 0)
        return False, new_count
    else:
        upvote_ref.set({"user_id": user_id})
        post_ref.update({"upvote_count": firestore.Increment(1)})
        updated = post_ref.get()
        new_count = updated.to_dict().get("upvote_count", 0)
        return True, new_count


def get_comments_for_post(course_id, post_id):
    """Return all comments for a post, ordered by path for threading."""
    db = _get_db()
    comments_ref = (
        db.collection("courses")
        .document(course_id)
        .collection("posts")
        .document(post_id)
        .collection("comments")
    )
    query = comments_ref.order_by("path")
    docs = query.stream()

    comments = []
    for doc in docs:
        data = doc.to_dict()
        ts = data.get("created_at")
        if hasattr(ts, 'isoformat'):
            timestamp_str = ts.strftime("%Y-%m-%dT%H:%M:%SZ")
        else:
            timestamp_str = str(ts) if ts else ""

        comments.append({
            "id": doc.id,
            "post_id": post_id,
            "author_id": data.get("author_id", ""),
            "author_name": data.get("author_name", ""),
            "body": data.get("body", ""),
            "parent_comment_id": data.get("parent_comment_id"),
            "path": data.get("path", ""),
            "created_at": timestamp_str,
        })
    return comments


def create_comment(course_id, post_id, author_id, author_name, body, parent_comment_id=None):
    """Create a comment on a post. Returns the comment dict."""
    db = _get_db()
    comments_ref = (
        db.collection("courses")
        .document(course_id)
        .collection("posts")
        .document(post_id)
        .collection("comments")
    )

    # Generate doc first to know its ID for the path
    new_doc_ref = comments_ref.document()
    comment_id = new_doc_ref.id

    # Build path for threading
    if parent_comment_id:
        parent_doc = comments_ref.document(parent_comment_id).get()
        if parent_doc.exists:
            parent_path = parent_doc.to_dict().get("path", parent_comment_id)
            path = f"{parent_path}/{comment_id}"
        else:
            path = comment_id
    else:
        path = comment_id

    comment_data = {
        "author_id": author_id,
        "author_name": author_name,
        "body": body,
        "parent_comment_id": parent_comment_id,
        "path": path,
        "created_at": firestore.SERVER_TIMESTAMP,
    }
    new_doc_ref.set(comment_data)

    # Increment comment count on the post
    post_ref = (
        db.collection("courses")
        .document(course_id)
        .collection("posts")
        .document(post_id)
    )
    post_ref.update({"comment_count": firestore.Increment(1)})

    return {
        "id": comment_id,
        "post_id": post_id,
        "author_id": author_id,
        "author_name": author_name,
        "body": body,
        "parent_comment_id": parent_comment_id,
        "path": path,
        "created_at": "",
    }

"""Model constants and helper functions for CourseHub."""

# Datastore Kind constants
KIND_CLASS = "Class"
KIND_USER = "User"
KIND_USER_CLASS = "UserClass"
KIND_MESSAGE = "Message"


def create_class_dict(id, class_code, class_name, quarter):
    """Create a class dictionary."""
    return {
        "id": id,
        "class_code": class_code,
        "class_name": class_name,
        "quarter": quarter
    }


def create_enrollment_dict(id, user_id, class_id):
    """Create an enrollment dictionary."""
    return {
        "id": id,
        "user_id": user_id,
        "class_id": class_id
    }

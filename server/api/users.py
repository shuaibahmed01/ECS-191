"""User management API endpoints."""

from flask import Blueprint, jsonify, request, g
from services.auth_service import require_auth
from services.datastore_service import (
    create_user,
    get_user_by_id,
    enroll_user,
    get_user_classes,
    unenroll_user,
    get_class_by_id,
)
from services.syllabus_service import get_syllabus_context

users_bp = Blueprint("users", __name__)


@users_bp.route("/users", methods=["POST"])
@require_auth
def register_user():
    """Register a new user in the database."""
    data = request.get_json()

    if not data:
        return jsonify({"error": "Request body is required"}), 400

    uid = data.get("uid")
    email = data.get("email")
    display_name = data.get("display_name")

    if not uid or not email or not display_name:
        return jsonify({"error": "uid, email, and display_name are required"}), 400

    # Verify the token UID matches the request UID
    if g.user_id != uid:
        return jsonify({"error": "UID mismatch"}), 403

    user = create_user(uid, email, display_name)
    return jsonify(user), 201


@users_bp.route("/users/me/classes", methods=["GET"])
@require_auth
def get_my_classes():
    """Get all classes the authenticated user is enrolled in."""
    classes = get_user_classes(g.user_id)
    return jsonify({"classes": classes})


@users_bp.route("/users/me/classes", methods=["POST"])
@require_auth
def enroll_in_class():
    """Enroll the authenticated user in a class."""
    data = request.get_json()

    if not data or "class_id" not in data:
        return jsonify({"error": "class_id is required"}), 400

    class_id = data["class_id"]

    # Check if class exists
    class_data = get_class_by_id(class_id)
    if not class_data:
        return jsonify({"error": "Class not found"}), 404

    enrollment = enroll_user(g.user_id, class_id)

    if enrollment is None:
        return jsonify({"error": "Already enrolled in this class"}), 409

    # Return the class data with enrollment_id
    result = class_data.copy()
    result["enrollment_id"] = enrollment["id"]
    return jsonify(result), 201


@users_bp.route("/users/me/classes/<enrollment_id>", methods=["DELETE"])
@require_auth
def unenroll_from_class(enrollment_id):
    """Unenroll the authenticated user from a class."""
    success = unenroll_user(g.user_id, str(enrollment_id))

    if not success:
        return jsonify({"error": "Enrollment not found"}), 404

    return "", 204


@users_bp.route("/users/me/important-dates", methods=["GET"])
@require_auth
def get_important_dates():
    """Return aggregated parsed dates across all enrolled classes, sorted by date."""
    classes = get_user_classes(g.user_id)
    dates = []
    for cls in classes:
        class_id = cls["id"]
        class_code = cls.get("class_code", "")
        syllabus = get_syllabus_context(class_id)
        if not syllabus:
            continue
        parsed = syllabus.get("parsed_dates", [])
        if not isinstance(parsed, list):
            continue
        for idx, entry in enumerate(parsed):
            dates.append({
                "id": f"{class_id}_{idx}",
                "class_id": class_id,
                "class_code": class_code,
                "title": entry.get("title", ""),
                "date": entry.get("date", ""),
                "description": entry.get("description", ""),
            })
    dates = [d for d in dates if d["date"]]
    dates.sort(key=lambda d: d["date"])
    return jsonify({"dates": dates})

"""Classes API blueprint for CourseHub."""

from flask import Blueprint, request, jsonify
from services.datastore_service import (
    get_all_classes,
    get_class_by_id,
    enroll_user,
    get_user_classes,
    unenroll_user
)

classes_bp = Blueprint("classes", __name__)


@classes_bp.route("/classes", methods=["GET"])
def list_classes():
    """List all classes, with optional search query."""
    query = request.args.get("q", "")
    classes = get_all_classes(query)
    return jsonify({"classes": classes})


@classes_bp.route("/classes/<int:class_id>", methods=["GET"])
def get_class(class_id):
    """Get a single class by ID."""
    class_data = get_class_by_id(class_id)
    if not class_data:
        return jsonify({"error": "Class not found"}), 404
    return jsonify(class_data)


@classes_bp.route("/users/<int:user_id>/classes", methods=["POST"])
def enroll_in_class(user_id):
    """Enroll a user in a class."""
    data = request.get_json()
    if not data or "class_id" not in data:
        return jsonify({"error": "class_id is required"}), 400

    class_id = data["class_id"]

    # Check if class exists
    class_data = get_class_by_id(class_id)
    if not class_data:
        return jsonify({"error": "Class not found"}), 404

    enrollment = enroll_user(user_id, class_id)
    if not enrollment:
        return jsonify({"error": "Already enrolled in this class"}), 409

    # Return the class data with enrollment_id
    result = class_data.copy()
    result["enrollment_id"] = enrollment["id"]
    return jsonify(result), 201


@classes_bp.route("/users/<int:user_id>/classes", methods=["GET"])
def list_user_classes(user_id):
    """List all classes a user is enrolled in."""
    classes = get_user_classes(user_id)
    return jsonify({"classes": classes})


@classes_bp.route("/users/<int:user_id>/classes/<int:enrollment_id>", methods=["DELETE"])
def unenroll_from_class(user_id, enrollment_id):
    """Unenroll a user from a class."""
    success = unenroll_user(user_id, enrollment_id)
    if not success:
        return jsonify({"error": "Enrollment not found"}), 404
    return "", 204

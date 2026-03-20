"""Classes API blueprint for CourseHub."""

from flask import Blueprint, request, jsonify
from services.datastore_service import get_all_classes, get_class_by_id, create_class
from services.auth_service import require_auth

classes_bp = Blueprint("classes", __name__)


@classes_bp.route("/classes", methods=["GET"])
def list_classes():
    """List all classes, with optional search query. No auth required."""
    try:
        query = request.args.get("q", "")
        classes = get_all_classes(query)
        return jsonify({"classes": classes})
    except Exception:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Unable to load classes. Please try again later."}), 500


@classes_bp.route("/classes", methods=["POST"])
@require_auth
def create_custom_class():
    """
    Create or update a class in the catalog.
    Auth required to attribute changes to a user.
    """
    data = request.get_json() or {}
    code = data.get("class_code", "").strip()
    name = data.get("class_name", "").strip()
    lecture_times = data.get("lecture_times") or []
    discussion_times = data.get("discussion_times") or []

    if not code or not name:
        return jsonify({"error": "class_code and class_name are required"}), 400

    try:
        cls = create_class(code, name, lecture_times, discussion_times)
        # If class already existed, treat as 200 OK; otherwise 201 Created is fine.
        # We cannot easily detect existence without an extra read, so return 201 for idempotence.
        return jsonify(cls), 201
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Failed to create class. Please try again later."}), 500


@classes_bp.route("/classes/<class_id>", methods=["GET"])
def get_class(class_id):
    """Get a single class by ID. No auth required."""
    try:
        class_data = get_class_by_id(class_id)
        if not class_data:
            return jsonify({"error": "Class not found"}), 404
        return jsonify(class_data)
    except Exception:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Unable to load class. Please try again later."}), 500

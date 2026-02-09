"""Classes API blueprint for CourseHub."""

from flask import Blueprint, request, jsonify
from services.datastore_service import get_all_classes, get_class_by_id

classes_bp = Blueprint("classes", __name__)


@classes_bp.route("/classes", methods=["GET"])
def list_classes():
    """List all classes, with optional search query. No auth required."""
    query = request.args.get("q", "")
    classes = get_all_classes(query)
    return jsonify({"classes": classes})


@classes_bp.route("/classes/<class_id>", methods=["GET"])
def get_class(class_id):
    """Get a single class by ID. No auth required."""
    class_data = get_class_by_id(class_id)
    if not class_data:
        return jsonify({"error": "Class not found"}), 404
    return jsonify(class_data)

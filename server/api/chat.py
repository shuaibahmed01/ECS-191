"""Chat API blueprint for CourseHub."""

from flask import Blueprint, jsonify, request
from services.datastore_service import get_messages_for_class, create_message

chat_bp = Blueprint("chat", __name__)


@chat_bp.route("/classes/<int:class_id>/messages", methods=["GET"])
def get_messages(class_id):
    """Get all messages for a class."""
    messages = get_messages_for_class(class_id)
    return jsonify({"messages": messages})


@chat_bp.route("/classes/<int:class_id>/messages", methods=["POST"])
def post_message(class_id):
    """Post a new message to a class chat."""
    data = request.get_json()

    if not data:
        return jsonify({"error": "Request body is required"}), 400

    content = data.get("content")
    sender_name = data.get("sender_name")

    if not content:
        return jsonify({"error": "content is required"}), 400
    if not sender_name:
        return jsonify({"error": "sender_name is required"}), 400

    # Get sender_id from header (default to 1 for M0)
    sender_id = request.headers.get("X-User-Id", 1, type=int)

    message = create_message(class_id, sender_id, sender_name, content)
    return jsonify(message), 201

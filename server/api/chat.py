"""Chat API blueprint for CourseHub."""

from flask import Blueprint, jsonify, request, g
from services.datastore_service import (
    get_messages_for_class,
    create_message,
    get_user_by_id,
    is_user_enrolled,
)
from services.auth_service import require_auth

chat_bp = Blueprint("chat", __name__)


@chat_bp.route("/classes/<class_id>/messages", methods=["GET"])
@require_auth
def get_messages(class_id):
    """Get all messages for a class. Requires authentication and enrollment."""
    # Check if user is enrolled in the class
    if not is_user_enrolled(g.user_id, class_id):
        return jsonify({"error": "Not enrolled in this class"}), 403

    messages = get_messages_for_class(class_id)
    return jsonify({"messages": messages})


@chat_bp.route("/classes/<class_id>/messages", methods=["POST"])
@require_auth
def post_message(class_id):
    """Post a new message to a class chat. Requires authentication and enrollment."""
    # Check if user is enrolled in the class
    if not is_user_enrolled(g.user_id, class_id):
        return jsonify({"error": "Not enrolled in this class"}), 403

    data = request.get_json()

    if not data:
        return jsonify({"error": "Request body is required"}), 400

    content = data.get("content")
    attachment_url = data.get("attachment_url")
    attachment_type = data.get("attachment_type")

    if not content and not attachment_url:
        return jsonify({"error": "content or attachment_url is required"}), 400

    # Get sender info from authenticated user
    sender_id = g.user_id
    user = get_user_by_id(sender_id)
    sender_name = user["display_name"] if user else g.user_name or "Unknown"

    message = create_message(class_id, sender_id, sender_name, content, attachment_url, attachment_type)
    return jsonify(message), 201

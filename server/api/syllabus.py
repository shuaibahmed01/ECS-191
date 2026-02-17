"""Syllabus & Course Agent API blueprint for CourseHub."""

from flask import Blueprint, jsonify, request, g
from services.syllabus_service import (
    extract_syllabus,
    save_syllabus_context,
    get_syllabus_context,
    update_syllabus_context,
    chat_with_agent,
    save_agent_chat_history,
    get_agent_chat_history,
    extract_slides,
    save_slide,
    get_slides,
    delete_slide,
)
from services.datastore_service import is_user_enrolled, get_class_by_id
from services.auth_service import require_auth

syllabus_bp = Blueprint("syllabus", __name__)

MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB base64 limit


@syllabus_bp.route("/classes/<class_id>/syllabus", methods=["POST"])
@require_auth
def upload_syllabus(class_id):
    """Upload and process a syllabus PDF or image. Requires auth + enrollment."""
    if not is_user_enrolled(g.user_id, class_id):
        return jsonify({"error": "Not enrolled in this class"}), 403

    data = request.get_json()
    if not data:
        return jsonify({"error": "Request body is required"}), 400

    file_data = data.get("file_data")
    file_type = data.get("file_type")

    if not file_data or not file_type:
        return jsonify({"error": "file_data and file_type are required"}), 400

    # Validate file type
    allowed_types = ["application/pdf", "image/jpeg", "image/png", "image/webp"]
    if file_type not in allowed_types:
        return jsonify({"error": f"Unsupported file type. Allowed: {allowed_types}"}), 400

    # Check size (base64 string length)
    if len(file_data) > MAX_FILE_SIZE:
        return jsonify({"error": "File too large. Maximum 10MB"}), 400

    # Get class name for context
    class_info = get_class_by_id(class_id)
    class_name = class_info["class_name"] if class_info else class_id

    try:
        extracted = extract_syllabus(file_data, file_type, class_id, class_name)
        save_syllabus_context(class_id, g.user_id, extracted)
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": f"Failed to process syllabus: {str(e)}"}), 500

    context = get_syllabus_context(class_id)
    return jsonify({"syllabus": context}), 201


@syllabus_bp.route("/classes/<class_id>/syllabus", methods=["PUT"])
@require_auth
def update_syllabus(class_id):
    """Update specific syllabus fields. Requires auth + enrollment."""
    if not is_user_enrolled(g.user_id, class_id):
        return jsonify({"error": "Not enrolled in this class"}), 403

    # Ensure syllabus exists before allowing edits
    existing = get_syllabus_context(class_id)
    if not existing:
        return jsonify({"error": "No syllabus uploaded for this class"}), 404

    data = request.get_json()
    if not data:
        return jsonify({"error": "Request body is required"}), 400

    allowed_fields = {"instructor", "office_hours", "grading_policy", "important_dates", "course_policies"}
    updates = {k: v for k, v in data.items() if k in allowed_fields and isinstance(v, str)}

    if not updates:
        return jsonify({"error": "No valid fields to update"}), 400

    update_syllabus_context(class_id, g.user_id, updates)

    context = get_syllabus_context(class_id)
    return jsonify({"syllabus": context})


@syllabus_bp.route("/classes/<class_id>/syllabus", methods=["GET"])
@require_auth
def get_syllabus(class_id):
    """Get extracted syllabus context. Requires auth + enrollment."""
    if not is_user_enrolled(g.user_id, class_id):
        return jsonify({"error": "Not enrolled in this class"}), 403

    context = get_syllabus_context(class_id)
    if not context:
        return jsonify({"error": "No syllabus uploaded for this class"}), 404

    return jsonify({"syllabus": context})


@syllabus_bp.route("/classes/<class_id>/agent/chat", methods=["POST"])
@require_auth
def agent_chat(class_id):
    """Send a message to the course agent. Requires auth + enrollment."""
    if not is_user_enrolled(g.user_id, class_id):
        return jsonify({"error": "Not enrolled in this class"}), 403

    data = request.get_json()
    if not data:
        return jsonify({"error": "Request body is required"}), 400

    message = data.get("message")
    if not message:
        return jsonify({"error": "message is required"}), 400

    # Load existing conversation history
    history = get_agent_chat_history(class_id, g.user_id)

    try:
        response_text = chat_with_agent(class_id, g.user_id, message, history)
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": f"Agent error: {str(e)}"}), 500

    # Append new messages to history and save
    history.append({"role": "user", "content": message})
    history.append({"role": "assistant", "content": response_text})
    save_agent_chat_history(class_id, g.user_id, history)

    return jsonify({"response": response_text})


@syllabus_bp.route("/classes/<class_id>/agent/history", methods=["GET"])
@require_auth
def agent_history(class_id):
    """Get agent chat history. Requires auth + enrollment."""
    if not is_user_enrolled(g.user_id, class_id):
        return jsonify({"error": "Not enrolled in this class"}), 403

    history = get_agent_chat_history(class_id, g.user_id)
    return jsonify({"messages": history})


# ── Slides endpoints ──────────────────────────────────────────────────────────


@syllabus_bp.route("/classes/<class_id>/slides", methods=["POST"])
@require_auth
def upload_slides(class_id):
    """Upload and process lecture slides. Requires auth + enrollment."""
    if not is_user_enrolled(g.user_id, class_id):
        return jsonify({"error": "Not enrolled in this class"}), 403

    data = request.get_json()
    if not data:
        return jsonify({"error": "Request body is required"}), 400

    file_data = data.get("file_data")
    file_type = data.get("file_type")
    title = data.get("title")

    if not file_data or not file_type or not title:
        return jsonify({"error": "file_data, file_type, and title are required"}), 400

    allowed_types = ["application/pdf", "image/jpeg", "image/png", "image/webp"]
    if file_type not in allowed_types:
        return jsonify({"error": f"Unsupported file type. Allowed: {allowed_types}"}), 400

    if len(file_data) > MAX_FILE_SIZE:
        return jsonify({"error": "File too large. Maximum 10MB"}), 400

    class_info = get_class_by_id(class_id)
    class_name = class_info["class_name"] if class_info else class_id

    try:
        summary = extract_slides(file_data, file_type, class_id, class_name, title)
        slide_id = save_slide(class_id, g.user_id, title, summary)
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": f"Failed to process slides: {str(e)}"}), 500

    return jsonify({
        "slide": {
            "id": slide_id,
            "title": title,
            "summary": summary,
            "uploaded_by": g.user_id,
            "uploaded_at": "",
        }
    }), 201


@syllabus_bp.route("/classes/<class_id>/slides", methods=["GET"])
@require_auth
def list_slides(class_id):
    """List all slide summaries for a class. Requires auth + enrollment."""
    if not is_user_enrolled(g.user_id, class_id):
        return jsonify({"error": "Not enrolled in this class"}), 403

    slides = get_slides(class_id)
    return jsonify({"slides": slides})


@syllabus_bp.route("/classes/<class_id>/slides/<slide_id>", methods=["DELETE"])
@require_auth
def remove_slide(class_id, slide_id):
    """Delete a slide entry. Requires auth + enrollment."""
    if not is_user_enrolled(g.user_id, class_id):
        return jsonify({"error": "Not enrolled in this class"}), 403

    delete_slide(class_id, slide_id)
    return jsonify({"message": "Slide deleted"})

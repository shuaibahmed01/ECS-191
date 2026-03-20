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
    generate_flashcards,
    save_flashcards,
    get_flashcards,
    generate_practice_exam,
    save_practice_exam,
    get_practice_exams,
    get_practice_exam,
    grade_practice_exam,
    get_exam_attempts,
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
    except ValueError as e:
        # Validation error (e.g. file is not a real syllabus)
        return jsonify({"error": str(e)}), 422
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Failed to process syllabus. Please try again later."}), 500

    context = get_syllabus_context(class_id)
    return jsonify({"syllabus": context}), 201


@syllabus_bp.route("/classes/<class_id>/syllabus", methods=["PUT"])
@require_auth
def update_syllabus(class_id):
    """Update specific syllabus fields. Requires auth + enrollment."""
    try:
        if not is_user_enrolled(g.user_id, class_id):
            return jsonify({"error": "Not enrolled in this class"}), 403

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
    except Exception:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Unable to update syllabus. Please try again later."}), 500


@syllabus_bp.route("/classes/<class_id>/syllabus", methods=["GET"])
@require_auth
def get_syllabus(class_id):
    """Get extracted syllabus context. Requires auth + enrollment."""
    try:
        if not is_user_enrolled(g.user_id, class_id):
            return jsonify({"error": "Not enrolled in this class"}), 403

        context = get_syllabus_context(class_id)
        if not context:
            return jsonify({"error": "No syllabus uploaded for this class"}), 404

        return jsonify({"syllabus": context})
    except Exception:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Unable to load syllabus. Please try again later."}), 500


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
        response_text, citations = chat_with_agent(class_id, g.user_id, message, history)
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "The course agent is temporarily unavailable. Please try again later."}), 500

    # Append new messages to history and save
    history.append({"role": "user", "content": message})
    history.append({"role": "assistant", "content": response_text, "citations": citations})
    save_agent_chat_history(class_id, g.user_id, history)

    return jsonify({"response": response_text, "citations": citations})


@syllabus_bp.route("/classes/<class_id>/agent/history", methods=["GET"])
@require_auth
def agent_history(class_id):
    """Get agent chat history. Requires auth + enrollment."""
    try:
        if not is_user_enrolled(g.user_id, class_id):
            return jsonify({"error": "Not enrolled in this class"}), 403

        history = get_agent_chat_history(class_id, g.user_id)
        return jsonify({"messages": history})
    except Exception:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Unable to load chat history. Please try again later."}), 500


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
        return jsonify({"error": "Failed to process slides. Please try again later."}), 500

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
    try:
        if not is_user_enrolled(g.user_id, class_id):
            return jsonify({"error": "Not enrolled in this class"}), 403

        slides = get_slides(class_id)
        return jsonify({"slides": slides})
    except Exception:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Unable to load slides. Please try again later."}), 500


@syllabus_bp.route("/classes/<class_id>/slides/<slide_id>", methods=["DELETE"])
@require_auth
def remove_slide(class_id, slide_id):
    """Delete a slide entry. Requires auth + enrollment."""
    try:
        if not is_user_enrolled(g.user_id, class_id):
            return jsonify({"error": "Not enrolled in this class"}), 403

        delete_slide(class_id, slide_id)
        return jsonify({"message": "Slide deleted"})
    except Exception:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Unable to delete slide. Please try again later."}), 500


# ── Flashcard endpoints ───────────────────────────────────────────────────────


@syllabus_bp.route("/classes/<class_id>/slides/<slide_id>/flashcards", methods=["POST"])
@require_auth
def create_flashcards(class_id, slide_id):
    """Generate flashcards from a slide. Idempotent: returns existing if already generated."""
    if not is_user_enrolled(g.user_id, class_id):
        return jsonify({"error": "Not enrolled in this class"}), 403

    # Return existing flashcards if already generated
    existing = get_flashcards(class_id, slide_id)
    if existing:
        return jsonify({"flashcards": existing})

    try:
        cards = generate_flashcards(class_id, slide_id)
        save_flashcards(class_id, slide_id, cards)
    except ValueError as e:
        return jsonify({"error": str(e)}), 404
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Failed to generate flashcards. Please try again later."}), 500

    data = get_flashcards(class_id, slide_id)
    return jsonify({"flashcards": data}), 201


@syllabus_bp.route("/classes/<class_id>/slides/<slide_id>/flashcards", methods=["GET"])
@require_auth
def fetch_flashcards(class_id, slide_id):
    """Fetch existing flashcards for a slide."""
    try:
        if not is_user_enrolled(g.user_id, class_id):
            return jsonify({"error": "Not enrolled in this class"}), 403

        data = get_flashcards(class_id, slide_id)
        if not data:
            return jsonify({"error": "No flashcards generated for this slide"}), 404

        return jsonify({"flashcards": data})
    except Exception:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Unable to load flashcards. Please try again later."}), 500


# ── Practice exam endpoints ──────────────────────────────────────────────────


@syllabus_bp.route("/classes/<class_id>/practice-exams", methods=["POST"])
@require_auth
def create_practice_exam(class_id):
    """Generate a new practice exam from selected slides."""
    if not is_user_enrolled(g.user_id, class_id):
        return jsonify({"error": "Not enrolled in this class"}), 403

    data = request.get_json()
    if not data:
        return jsonify({"error": "Request body is required"}), 400

    title = data.get("title")
    slide_ids = data.get("slide_ids")
    if not title or not slide_ids:
        return jsonify({"error": "title and slide_ids are required"}), 400

    description = data.get("description", "")
    question_count = data.get("question_count", 10)
    question_type = data.get("question_type", "mixed")

    if question_type not in ("multiple_choice", "short_answer", "mixed"):
        return jsonify({"error": "question_type must be multiple_choice, short_answer, or mixed"}), 400

    try:
        questions = generate_practice_exam(
            class_id, slide_ids, title, description, question_count, question_type
        )
        exam_id = save_practice_exam(
            class_id, g.user_id, title, description, slide_ids, questions, question_type
        )
    except ValueError as e:
        return jsonify({"error": str(e)}), 422
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Failed to generate practice exam. Please try again later."}), 500

    exam = get_practice_exam(class_id, exam_id)
    return jsonify({"exam": exam}), 201


@syllabus_bp.route("/classes/<class_id>/practice-exams", methods=["GET"])
@require_auth
def list_practice_exams(class_id):
    """List all practice exams for a class."""
    try:
        if not is_user_enrolled(g.user_id, class_id):
            return jsonify({"error": "Not enrolled in this class"}), 403

        exams = get_practice_exams(class_id)
        return jsonify({"exams": exams})
    except Exception:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Unable to load practice exams. Please try again later."}), 500


@syllabus_bp.route("/classes/<class_id>/practice-exams/<exam_id>", methods=["GET"])
@require_auth
def fetch_practice_exam(class_id, exam_id):
    """Get a single practice exam with questions."""
    try:
        if not is_user_enrolled(g.user_id, class_id):
            return jsonify({"error": "Not enrolled in this class"}), 403

        exam = get_practice_exam(class_id, exam_id)
        if not exam:
            return jsonify({"error": "Exam not found"}), 404

        return jsonify({"exam": exam})
    except Exception:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Unable to load practice exam. Please try again later."}), 500


@syllabus_bp.route("/classes/<class_id>/practice-exams/<exam_id>/submit", methods=["POST"])
@require_auth
def submit_practice_exam(class_id, exam_id):
    """Submit answers for grading."""
    if not is_user_enrolled(g.user_id, class_id):
        return jsonify({"error": "Not enrolled in this class"}), 403

    data = request.get_json()
    if not data:
        return jsonify({"error": "Request body is required"}), 400

    answers = data.get("answers")
    if answers is None:
        return jsonify({"error": "answers are required"}), 400

    try:
        results = grade_practice_exam(class_id, exam_id, g.user_id, answers)
    except ValueError as e:
        return jsonify({"error": str(e)}), 404
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Failed to grade exam. Please try again later."}), 500

    return jsonify({"results": results})


@syllabus_bp.route("/classes/<class_id>/practice-exams/<exam_id>/attempts", methods=["GET"])
@require_auth
def list_exam_attempts(class_id, exam_id):
    """List a user's past attempts for an exam."""
    try:
        if not is_user_enrolled(g.user_id, class_id):
            return jsonify({"error": "Not enrolled in this class"}), 403

        attempts = get_exam_attempts(class_id, exam_id, g.user_id)
        return jsonify({"attempts": attempts})
    except Exception:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Unable to load exam attempts. Please try again later."}), 500

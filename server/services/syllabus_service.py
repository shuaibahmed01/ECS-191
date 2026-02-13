"""Syllabus extraction and course agent service using Anthropic API."""

import os
import base64
import json
from firebase_admin import firestore

import anthropic

# Firestore client (initialized lazily)
_db = None
_anthropic_client = None

CLAUDE_MODEL = "claude-sonnet-4-20250514"
MAX_CHAT_MESSAGES = 20


def _get_db():
    """Get Firestore client, initializing if needed."""
    global _db
    if _db is None:
        _db = firestore.client()
    return _db


def _get_anthropic():
    """Get Anthropic client, initializing if needed."""
    global _anthropic_client
    if _anthropic_client is None:
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            raise ValueError("ANTHROPIC_API_KEY environment variable is not set")
        _anthropic_client = anthropic.Anthropic(api_key=api_key)
    return _anthropic_client


def extract_syllabus(file_data_b64, file_type, class_id, class_name):
    """
    Call Claude with a PDF/image syllabus and extract structured fields.

    Args:
        file_data_b64: Base64-encoded file data
        file_type: MIME type (e.g. "application/pdf", "image/jpeg")
        class_id: Firestore class document ID
        class_name: Human-readable class name

    Returns:
        dict with extracted fields
    """
    client = _get_anthropic()

    # Build the content block for the file
    if file_type == "application/pdf":
        file_content = {
            "type": "document",
            "source": {
                "type": "base64",
                "media_type": "application/pdf",
                "data": file_data_b64,
            },
        }
    else:
        # Image (JPEG, PNG, etc.)
        file_content = {
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": file_type,
                "data": file_data_b64,
            },
        }

    extraction_prompt = f"""Analyze this course syllabus for {class_name} and extract the following information.
Return your response as a JSON object with these exact keys:
- "instructor": The instructor/professor name and contact info
- "office_hours": Office hours schedule and location
- "grading_policy": Grading breakdown and policies
- "important_dates": Key dates (midterms, finals, project deadlines, holidays)
- "course_policies": Attendance, late work, academic integrity, and other policies
- "raw_summary": A comprehensive plain-text summary of the entire syllabus

If any field is not found in the syllabus, use "Not specified" as the value.
Return ONLY the JSON object, no other text."""

    response = client.messages.create(
        model=CLAUDE_MODEL,
        max_tokens=4096,
        messages=[
            {
                "role": "user",
                "content": [
                    file_content,
                    {"type": "text", "text": extraction_prompt},
                ],
            }
        ],
    )

    # Parse the JSON response
    response_text = response.content[0].text
    # Strip markdown code fences if present
    if response_text.startswith("```"):
        lines = response_text.split("\n")
        # Remove first and last lines (``` markers)
        lines = lines[1:-1]
        response_text = "\n".join(lines)

    extracted = json.loads(response_text)
    return extracted


def save_syllabus_context(class_id, user_id, extracted_data):
    """
    Write extracted syllabus data to syllabus_context/{class_id}.

    Args:
        class_id: Firestore class document ID
        user_id: UID of the uploading user
        extracted_data: dict from extract_syllabus()
    """
    db = _get_db()
    doc_ref = db.collection("syllabus_context").document(class_id)
    doc_ref.set({
        "class_id": class_id,
        "instructor": extracted_data.get("instructor", "Not specified"),
        "office_hours": extracted_data.get("office_hours", "Not specified"),
        "grading_policy": extracted_data.get("grading_policy", "Not specified"),
        "important_dates": extracted_data.get("important_dates", "Not specified"),
        "course_policies": extracted_data.get("course_policies", "Not specified"),
        "raw_summary": extracted_data.get("raw_summary", ""),
        "uploaded_by": user_id,
        "uploaded_at": firestore.SERVER_TIMESTAMP,
    })


def get_syllabus_context(class_id):
    """
    Read syllabus context from Firestore.

    Returns:
        dict with syllabus fields, or None if not found.
    """
    db = _get_db()
    doc = db.collection("syllabus_context").document(class_id).get()
    if not doc.exists:
        return None
    data = doc.to_dict()
    # Convert timestamp to string
    ts = data.get("uploaded_at")
    if hasattr(ts, "isoformat"):
        data["uploaded_at"] = ts.strftime("%Y-%m-%dT%H:%M:%SZ")
    elif ts is not None:
        data["uploaded_at"] = str(ts)
    else:
        data["uploaded_at"] = ""
    return data


def chat_with_agent(class_id, user_id, user_message, conversation_history):
    """
    Send a message to the course agent. Uses syllabus context as system prompt.

    Args:
        class_id: Firestore class document ID
        user_id: UID of the user
        user_message: The user's new message
        conversation_history: List of prior messages [{"role": "user"/"assistant", "content": "..."}]

    Returns:
        The assistant's response text
    """
    client = _get_anthropic()

    # Load syllabus context
    syllabus = get_syllabus_context(class_id)
    if not syllabus:
        return "No syllabus has been uploaded for this course yet. Please upload a syllabus first so I can help answer your questions."

    system_prompt = f"""You are a helpful course assistant for a university class. You answer student questions using the course syllabus as your primary reference.

Here is the syllabus information:

Instructor: {syllabus.get('instructor', 'Not specified')}
Office Hours: {syllabus.get('office_hours', 'Not specified')}
Grading Policy: {syllabus.get('grading_policy', 'Not specified')}
Important Dates: {syllabus.get('important_dates', 'Not specified')}
Course Policies: {syllabus.get('course_policies', 'Not specified')}

Full Syllabus Summary:
{syllabus.get('raw_summary', '')}

Instructions:
- Answer questions based on the syllabus information above.
- If the answer is not in the syllabus, say so clearly.
- Be concise and helpful.
- If a student asks about something not covered in the syllabus, suggest they contact the instructor."""

    # Build messages list from history + new message
    messages = []
    for msg in conversation_history:
        messages.append({
            "role": msg["role"],
            "content": msg["content"],
        })
    messages.append({"role": "user", "content": user_message})

    response = client.messages.create(
        model=CLAUDE_MODEL,
        max_tokens=1024,
        system=system_prompt,
        messages=messages,
    )

    return response.content[0].text


def save_agent_chat_history(class_id, user_id, messages):
    """
    Write conversation history to syllabus_context/{class_id}/agent_chats/{user_id}.
    Caps at MAX_CHAT_MESSAGES most recent messages.
    """
    db = _get_db()
    # Keep only the most recent messages
    capped = messages[-MAX_CHAT_MESSAGES:]
    doc_ref = (
        db.collection("syllabus_context")
        .document(class_id)
        .collection("agent_chats")
        .document(user_id)
    )
    doc_ref.set({"messages": capped, "updated_at": firestore.SERVER_TIMESTAMP})


def get_agent_chat_history(class_id, user_id):
    """
    Read conversation history from Firestore.

    Returns:
        List of message dicts [{"role": "...", "content": "..."}], or empty list.
    """
    db = _get_db()
    doc = (
        db.collection("syllabus_context")
        .document(class_id)
        .collection("agent_chats")
        .document(user_id)
        .get()
    )
    if not doc.exists:
        return []
    data = doc.to_dict()
    return data.get("messages", [])

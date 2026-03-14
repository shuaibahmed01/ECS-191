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
- "parsed_dates": Array of objects with "title" (str), "date" (YYYY-MM-DD), "description" (str). Only include dates that can be resolved to a specific calendar date. If none, return [].

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

    # Validate that the uploaded file actually contained syllabus content.
    # If most fields came back as "Not specified", the file likely wasn't a syllabus.
    not_specified_count = sum(
        1
        for key in ("instructor", "office_hours", "grading_policy", "important_dates", "course_policies")
        if extracted.get(key, "").strip().lower() in ("not specified", "not specified.", "")
    )
    if not_specified_count >= 4:
        raise ValueError(
            "The uploaded file does not appear to be a valid course syllabus. "
            "Please upload a PDF or photo of your actual course syllabus."
        )

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
        "parsed_dates": extracted_data.get("parsed_dates", []) if isinstance(extracted_data.get("parsed_dates"), list) else [],
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


def update_syllabus_context(class_id, user_id, updates):
    """
    Update specific fields of an existing syllabus context.

    Args:
        class_id: Firestore class document ID
        user_id: UID of the editing user
        updates: dict of field names to new values (only editable fields allowed)
    """
    db = _get_db()
    doc_ref = db.collection("syllabus_context").document(class_id)

    allowed_fields = {"instructor", "office_hours", "grading_policy", "important_dates", "course_policies"}
    filtered = {k: v for k, v in updates.items() if k in allowed_fields}

    if not filtered:
        return

    filtered["uploaded_by"] = user_id
    filtered["uploaded_at"] = firestore.SERVER_TIMESTAMP
    doc_ref.update(filtered)


def chat_with_agent(class_id, user_id, user_message, conversation_history):
    """
    Send a message to the course agent. Uses syllabus context as system prompt.

    Args:
        class_id: Firestore class document ID
        user_id: UID of the user
        user_message: The user's new message
        conversation_history: List of prior messages [{"role": "user"/"assistant", "content": "..."}]

    Returns:
        tuple[str, list[dict]]: (assistant response, citations)
    """
    client = _get_anthropic()

    # Load syllabus context
    syllabus = get_syllabus_context(class_id)
    if not syllabus:
        return "No syllabus has been uploaded for this course yet. Please upload a syllabus first so I can help answer your questions."

    # Load slide summaries
    slides = get_slides(class_id)
    slides_section = ""
    if slides:
        slides_section = "\n\nLecture Slides:\n"
        for slide in slides:
            slides_section += f"\n--- {slide['title']} ---\n{slide['summary']}\n"

    system_prompt = f"""You are a helpful course assistant for a university class. You answer student questions using the course syllabus and lecture slides as your primary references.

Here is the syllabus information:

Instructor: {syllabus.get('instructor', 'Not specified')}
Office Hours: {syllabus.get('office_hours', 'Not specified')}
Grading Policy: {syllabus.get('grading_policy', 'Not specified')}
Important Dates: {syllabus.get('important_dates', 'Not specified')}
Course Policies: {syllabus.get('course_policies', 'Not specified')}

Full Syllabus Summary:
{syllabus.get('raw_summary', '')}{slides_section}

Instructions:
- Answer questions based on the syllabus and lecture slide information above.
- If the answer is not in the syllabus or slides, say so clearly.
- Be concise and helpful.
- If a student asks about something not covered in the syllabus or slides, suggest they contact the instructor."""

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

    text = response.content[0].text
    citations = _derive_citations(text, syllabus)
    return text, citations


def _derive_citations(answer_text: str, syllabus_ctx: dict) -> list[dict]:
    """
    Heuristic citation extraction: map common keywords to syllabus fields and
    return lightweight citation objects the client can render and deep-link.
    """
    if not syllabus_ctx:
        return []
    answer_lower = (answer_text or "").lower()
    field_map = [
        ("office_hours", ["office hour", "office-hour", "officehours", "oh", "ohs"]),
        ("grading_policy", ["grade", "grading", "points", "percentage", "rubric"]),
        ("important_dates", ["exam", "midterm", "final", "deadline", "due", "date", "schedule"]),
        ("course_policies", ["policy", "late", "integrity", "plagiarism", "attendance"]),
        ("instructor", ["instructor", "professor", "prof", "lecturer", "ta", "teaching assistant"]),
    ]
    citations = []
    for field, keywords in field_map:
        if any(k in answer_lower for k in keywords):
            preview = str(syllabus_ctx.get(field, ""))[:180]
            if preview:
                citations.append({
                    "field": field,
                    "preview": preview
                })
    # De-duplicate by field
    seen = set()
    unique = []
    for c in citations:
        f = c["field"]
        if f in seen:
            continue
        seen.add(f)
        unique.append(c)
    return unique


def extract_slides(file_data_b64, file_type, class_id, class_name, title):
    """
    Call Claude with a PDF/image of lecture slides and extract a concise summary.

    Args:
        file_data_b64: Base64-encoded file data
        file_type: MIME type (e.g. "application/pdf", "image/jpeg")
        class_id: Firestore class document ID
        class_name: Human-readable class name
        title: User-provided slide title (e.g. "Week 3 - Sorting")

    Returns:
        str: concise summary of the slide content
    """
    client = _get_anthropic()

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
        file_content = {
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": file_type,
                "data": file_data_b64,
            },
        }

    extraction_prompt = f"""Analyze these lecture slides for {class_name} (titled "{title}").
Extract a concise summary containing:
- Main topics covered
- Key definitions and concepts
- Important formulas, algorithms, or frameworks mentioned
- Any examples or case studies referenced

Keep the summary concise (under 500 words). Focus on the key takeaways a student would need.
Return ONLY the summary text, no JSON or markdown formatting."""

    response = client.messages.create(
        model=CLAUDE_MODEL,
        max_tokens=2048,
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

    return response.content[0].text


def save_slide(class_id, user_id, title, summary):
    """
    Write a slide entry to slides/{class_id}/entries/{auto_id}.

    Returns:
        str: the auto-generated slide document ID
    """
    db = _get_db()
    entries_ref = db.collection("slides").document(class_id).collection("entries")
    doc_ref = entries_ref.add({
        "title": title,
        "summary": summary,
        "uploaded_by": user_id,
        "uploaded_at": firestore.SERVER_TIMESTAMP,
    })
    return doc_ref[1].id


def get_slides(class_id):
    """
    Return all slide entries for a class, sorted by upload time.

    Returns:
        list of dicts with id, title, summary, uploaded_by, uploaded_at
    """
    db = _get_db()
    entries_ref = (
        db.collection("slides")
        .document(class_id)
        .collection("entries")
        .order_by("uploaded_at")
    )
    docs = entries_ref.stream()

    slides = []
    for doc in docs:
        data = doc.to_dict()
        ts = data.get("uploaded_at")
        if hasattr(ts, "isoformat"):
            ts_str = ts.strftime("%Y-%m-%dT%H:%M:%SZ")
        elif ts is not None:
            ts_str = str(ts)
        else:
            ts_str = ""
        slides.append({
            "id": doc.id,
            "title": data.get("title", ""),
            "summary": data.get("summary", ""),
            "uploaded_by": data.get("uploaded_by", ""),
            "uploaded_at": ts_str,
        })
    return slides


def delete_slide(class_id, slide_id):
    """Delete a single slide entry."""
    db = _get_db()
    db.collection("slides").document(class_id).collection("entries").document(slide_id).delete()


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


# ── Flashcard generation ──────────────────────────────────────────────────────


def generate_flashcards(class_id, slide_id):
    """
    Generate study flashcards from a slide's summary using Claude.

    Returns:
        list of {"question": ..., "answer": ...} dicts
    """
    db = _get_db()
    doc = (
        db.collection("slides")
        .document(class_id)
        .collection("entries")
        .document(slide_id)
        .get()
    )
    if not doc.exists:
        raise ValueError("Slide not found")

    summary = doc.to_dict().get("summary", "")
    if not summary:
        raise ValueError("Slide has no summary")

    client = _get_anthropic()

    prompt = f"""Based on the following lecture summary, generate 5-8 study flashcards as question-answer pairs.
Each flashcard should test a key concept, definition, or important detail from the material.

Lecture summary:
{summary}

Return ONLY a JSON array of objects with "question" and "answer" keys. Example:
[{{"question": "What is ...", "answer": "..."}}]"""

    response = client.messages.create(
        model=CLAUDE_MODEL,
        max_tokens=2048,
        messages=[{"role": "user", "content": prompt}],
    )

    response_text = response.content[0].text
    # Strip markdown code fences if present
    if response_text.startswith("```"):
        lines = response_text.split("\n")
        lines = lines[1:-1]
        response_text = "\n".join(lines)

    cards = json.loads(response_text)
    return cards


def save_flashcards(class_id, slide_id, cards):
    """Write flashcards to slides/{class_id}/entries/{slide_id}/flashcards/data."""
    db = _get_db()
    doc_ref = (
        db.collection("slides")
        .document(class_id)
        .collection("entries")
        .document(slide_id)
        .collection("flashcards")
        .document("data")
    )
    doc_ref.set({
        "cards": cards,
        "generated_at": firestore.SERVER_TIMESTAMP,
    })


def get_flashcards(class_id, slide_id):
    """
    Read flashcards from Firestore.

    Returns:
        dict with "cards" list and "generated_at", or None if not found.
    """
    db = _get_db()
    doc = (
        db.collection("slides")
        .document(class_id)
        .collection("entries")
        .document(slide_id)
        .collection("flashcards")
        .document("data")
        .get()
    )
    if not doc.exists:
        return None
    data = doc.to_dict()
    ts = data.get("generated_at")
    if hasattr(ts, "isoformat"):
        data["generated_at"] = ts.strftime("%Y-%m-%dT%H:%M:%SZ")
    elif ts is not None:
        data["generated_at"] = str(ts)
    else:
        data["generated_at"] = ""
    return data

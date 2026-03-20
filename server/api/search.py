"""Search API blueprint for CourseHub."""

from flask import Blueprint, jsonify, request, g
from services.auth_service import require_auth
from services.datastore_service import (
    get_enrolled_class_ids,
    get_recent_messages_for_class,
    get_class_by_id,
)
from services.syllabus_service import get_syllabus_context

search_bp = Blueprint("search", __name__)


@search_bp.route("/search", methods=["GET"])
@require_auth
def global_search():
    """
    Global search across syllabus contexts and recent chat messages for the
    authenticated user's enrolled classes.
    Query params:
        q: search query (required)
        types: comma-separated list among ['syllabus','chat'] (optional; default both)
    """
    try:
        return _do_global_search()
    except Exception:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Search is temporarily unavailable. Please try again later."}), 500


def _do_global_search():
    q = (request.args.get("q") or "").strip()
    if not q:
        return jsonify({"error": "q is required"}), 400
    q_lower = q.lower()
    tokens = [t for t in q_lower.replace(",", " ").split() if t]
    has_numeric_token = any(any(ch.isdigit() for ch in t) for t in tokens)

    types_param = request.args.get("types", "syllabus,chat")
    allowed_types = set(t.strip() for t in types_param.split(",") if t.strip())
    if not allowed_types:
        allowed_types = {"syllabus", "chat"}

    class_ids = get_enrolled_class_ids(g.user_id)
    # Build class metadata for tagging and fuzzy class filtering
    class_meta = {}
    for cid in class_ids:
        info = get_class_by_id(cid) or {}
        class_meta[cid] = {
            "code": (info.get("class_code") or cid),
            "name": info.get("class_name") or "",
        }

    def class_matches_query(cid: str) -> bool:
        if not tokens:
            return True
        code = class_meta[cid]["code"].lower()
        name = class_meta[cid]["name"].lower()
        if has_numeric_token and any(t for t in tokens if t in code or t in name):
            return True
        if any(t for t in tokens if t in code or t in name):
            return True
        return not has_numeric_token

    filtered_class_ids = [cid for cid in class_ids if class_matches_query(cid)]

    def text_matches(text: str) -> bool:
        if not text:
            return False
        tl = text.lower()
        if q_lower in tl:
            return True
        return any(t for t in tokens if t in tl)

    results = []

    if "syllabus" in allowed_types:
        for cid in filtered_class_ids:
            ctx = get_syllabus_context(cid) or {}
            fields = {
                "instructor": ctx.get("instructor", ""),
                "office_hours": ctx.get("office_hours", ""),
                "grading_policy": ctx.get("grading_policy", ""),
                "important_dates": ctx.get("important_dates", ""),
                "course_policies": ctx.get("course_policies", ""),
                "raw_summary": ctx.get("raw_summary", ""),
            }
            for field, text in fields.items():
                if text_matches(text or ""):
                    snippet = (text or "")
                    results.append({
                        "type": "syllabus",
                        "class_id": cid,
                        "class_code": class_meta[cid]["code"],
                        "field": field,
                        "snippet": snippet[:220]
                    })

    if "chat" in allowed_types:
        for cid in filtered_class_ids:
            msgs = get_recent_messages_for_class(cid, limit=150)
            for m in msgs:
                content = m.get("content", "")
                if text_matches(content or ""):
                    results.append({
                        "type": "chat",
                        "class_id": cid,
                        "class_code": class_meta[cid]["code"],
                        "message_id": m["id"],
                        "sender_name": m.get("sender_name", ""),
                        "snippet": content[:220]
                    })

    return jsonify({"results": results})


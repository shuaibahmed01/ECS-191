"""Uploads API for chat/media attachments."""

import os
import base64
import uuid
from flask import Blueprint, jsonify, request, send_from_directory
from services.auth_service import require_auth

uploads_bp = Blueprint("uploads", __name__)

UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "..", "uploads")
UPLOAD_DIR = os.path.abspath(UPLOAD_DIR)
os.makedirs(UPLOAD_DIR, exist_ok=True)

ALLOWED_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "application/pdf": ".pdf",
}


@uploads_bp.route("/uploads", methods=["POST"])
@require_auth
def upload_file():
    """
    Accept a base64-encoded file and return a public URL served by the backend.
    Body:
      - file_data: base64 string
      - file_type: MIME string (must be in ALLOWED_TYPES)
    """
    data = request.get_json() or {}
    file_data = data.get("file_data")
    file_type = data.get("file_type")

    if not file_data or not file_type:
        return jsonify({"error": "file_data and file_type are required"}), 400

    if file_type not in ALLOWED_TYPES:
        return jsonify({"error": f"Unsupported file type. Allowed: {list(ALLOWED_TYPES.keys())}"}), 400

    try:
        file_bytes = base64.b64decode(file_data)
    except Exception:
        return jsonify({"error": "Invalid base64 file_data"}), 400

    ext = ALLOWED_TYPES[file_type]
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(UPLOAD_DIR, filename)
    with open(filepath, "wb") as f:
        f.write(file_bytes)

    # Served via GET /v1/uploads/<filename>
    return jsonify({"url": f"/v1/uploads/{filename}", "type": file_type}), 201


@uploads_bp.route("/uploads/<path:filename>", methods=["GET"])
def serve_upload(filename: str):
    """Serve an uploaded file."""
    return send_from_directory(UPLOAD_DIR, filename, as_attachment=False)


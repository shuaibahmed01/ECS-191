"""Uploads API for chat/media attachments using Firebase Storage."""

import base64
import uuid
from datetime import timedelta
from flask import Blueprint, jsonify, request
from firebase_admin import storage
from services.auth_service import require_auth

uploads_bp = Blueprint("uploads", __name__)

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
    Accept a base64-encoded file, upload to Firebase Storage,
    and return a public URL.
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
    filename = f"chat_attachments/{uuid.uuid4().hex}{ext}"

    bucket = storage.bucket()
    blob = bucket.blob(filename)
    blob.upload_from_string(file_bytes, content_type=file_type)

    # Generate a signed URL that lasts 7 days
    url = blob.generate_signed_url(expiration=timedelta(days=7))

    return jsonify({"url": url, "type": file_type}), 201

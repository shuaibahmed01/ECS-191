"""Firebase authentication service for CourseHub."""

import os
from functools import wraps
from flask import request, jsonify, g
import firebase_admin
from firebase_admin import auth, credentials


def init_firebase():
    """Initialize Firebase Admin SDK."""
    if not firebase_admin._apps:
        # For local development, use default credentials or service account
        # In production on GCP, this will use the default service account
        try:
            # Try to use application default credentials (works on GCP)
            firebase_admin.initialize_app()
        except Exception:
            # For local development without credentials, initialize without verification
            # Note: In production, you should always have proper credentials
            firebase_admin.initialize_app(options={
                'projectId': os.environ.get('FIREBASE_PROJECT_ID', 'coursehub-dev')
            })


def verify_token(id_token):
    """
    Verify a Firebase ID token.
    Returns the decoded token if valid, None otherwise.
    """
    try:
        decoded_token = auth.verify_id_token(id_token)
        return decoded_token
    except Exception as e:
        print(f"Token verification failed: {e}")
        return None


def require_auth(f):
    """
    Decorator to require authentication for an endpoint.
    Sets g.user_id and g.user_email from the verified token.
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization')

        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({"error": "Missing or invalid Authorization header"}), 401

        id_token = auth_header.split('Bearer ')[1]
        decoded_token = verify_token(id_token)

        if not decoded_token:
            return jsonify({"error": "Invalid or expired token"}), 401

        # Store user info in Flask's g object for use in the route
        g.user_id = decoded_token['uid']
        g.user_email = decoded_token.get('email', '')
        g.user_name = decoded_token.get('name', '')

        return f(*args, **kwargs)

    return decorated_function

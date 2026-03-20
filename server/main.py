"""CourseHub Flask application."""

from dotenv import load_dotenv
load_dotenv()

from flask import Flask, jsonify
from api.classes import classes_bp
from api.chat import chat_bp
from api.users import users_bp
from api.syllabus import syllabus_bp
from api.search import search_bp
from services.auth_service import init_firebase
from api.uploads import uploads_bp


def create_app():
    """Create and configure the Flask application."""
    app = Flask(__name__)

    # Initialize Firebase
    init_firebase()

    # Register blueprints with /v1 prefix
    app.register_blueprint(classes_bp, url_prefix="/v1")
    app.register_blueprint(chat_bp, url_prefix="/v1")
    app.register_blueprint(users_bp, url_prefix="/v1")
    app.register_blueprint(syllabus_bp, url_prefix="/v1")
    app.register_blueprint(search_bp, url_prefix="/v1")
    app.register_blueprint(uploads_bp, url_prefix="/v1")

    # ── Global error handlers ────────────────────────────────────────────────
    @app.errorhandler(404)
    def not_found(e):
        return jsonify({"error": "The requested resource was not found."}), 404

    @app.errorhandler(405)
    def method_not_allowed(e):
        return jsonify({"error": "Method not allowed."}), 405

    @app.errorhandler(500)
    def internal_error(e):
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Something went wrong. Please try again later."}), 500

    @app.errorhandler(Exception)
    def handle_unexpected_error(e):
        import traceback
        traceback.print_exc()
        return jsonify({"error": "Something went wrong. Please try again later."}), 500

    @app.route("/health", methods=["GET"])
    def health():
        """Health check endpoint."""
        return jsonify({"status": "healthy"})

    return app


# Create the app instance for gunicorn
app = create_app()


if __name__ == "__main__":
    app.run(debug=True, port=5001)

"""CourseHub Flask application."""

from flask import Flask, jsonify
from api.classes import classes_bp
from api.chat import chat_bp
from api.users import users_bp
from services.auth_service import init_firebase


def create_app():
    """Create and configure the Flask application."""
    app = Flask(__name__)

    # Initialize Firebase
    init_firebase()

    # Register blueprints with /v1 prefix
    app.register_blueprint(classes_bp, url_prefix="/v1")
    app.register_blueprint(chat_bp, url_prefix="/v1")
    app.register_blueprint(users_bp, url_prefix="/v1")

    @app.route("/health", methods=["GET"])
    def health():
        """Health check endpoint."""
        return jsonify({"status": "healthy"})

    return app


# Create the app instance for gunicorn
app = create_app()


if __name__ == "__main__":
    app.run(debug=True, port=5001)

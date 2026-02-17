"""Forum API blueprint for CourseHub."""

from flask import Blueprint, jsonify, request, g
from services.datastore_service import (
    get_posts_for_course,
    create_post,
    get_post_by_id,
    toggle_upvote,
    check_user_upvoted,
    get_comments_for_post,
    create_comment,
    get_user_by_id,
)
from services.auth_service import require_auth

forum_bp = Blueprint("forum", __name__)


@forum_bp.route("/courses/<course_id>/posts", methods=["GET"])
@require_auth
def list_posts(course_id):
    """List all posts for a course, newest first."""
    posts = get_posts_for_course(course_id)
    return jsonify({"posts": posts})


@forum_bp.route("/courses/<course_id>/posts", methods=["POST"])
@require_auth
def create_new_post(course_id):
    """Create a new forum post."""
    data = request.get_json()
    if not data:
        return jsonify({"error": "Request body is required"}), 400

    title = data.get("title")
    body = data.get("body")

    if not title:
        return jsonify({"error": "title is required"}), 400
    if not body:
        return jsonify({"error": "body is required"}), 400

    user = get_user_by_id(g.user_id)
    author_name = user["display_name"] if user else g.user_name or "Unknown"

    post = create_post(course_id, g.user_id, author_name, title, body)
    return jsonify(post), 201


@forum_bp.route("/courses/<course_id>/posts/<post_id>", methods=["GET"])
@require_auth
def get_post_detail(course_id, post_id):
    """Get a single post with its comments and the current user's upvote status."""
    post = get_post_by_id(course_id, post_id)
    if not post:
        return jsonify({"error": "Post not found"}), 404

    comments = get_comments_for_post(course_id, post_id)
    has_upvoted = check_user_upvoted(course_id, post_id, g.user_id)

    return jsonify({
        "post": post,
        "comments": comments,
        "has_upvoted": has_upvoted,
    })


@forum_bp.route("/courses/<course_id>/posts/<post_id>/upvote", methods=["POST"])
@require_auth
def upvote_post(course_id, post_id):
    """Toggle upvote on a post."""
    post = get_post_by_id(course_id, post_id)
    if not post:
        return jsonify({"error": "Post not found"}), 404

    upvoted, new_count = toggle_upvote(course_id, post_id, g.user_id)
    return jsonify({
        "upvoted": upvoted,
        "upvote_count": new_count,
    })


@forum_bp.route("/courses/<course_id>/posts/<post_id>/comments", methods=["POST"])
@require_auth
def add_comment(course_id, post_id):
    """Add a comment to a post (optionally threaded via parent_comment_id)."""
    post = get_post_by_id(course_id, post_id)
    if not post:
        return jsonify({"error": "Post not found"}), 404

    data = request.get_json()
    if not data:
        return jsonify({"error": "Request body is required"}), 400

    body = data.get("body")
    if not body:
        return jsonify({"error": "body is required"}), 400

    parent_comment_id = data.get("parent_comment_id")

    user = get_user_by_id(g.user_id)
    author_name = user["display_name"] if user else g.user_name or "Unknown"

    comment = create_comment(
        course_id, post_id, g.user_id, author_name, body, parent_comment_id
    )
    return jsonify(comment), 201

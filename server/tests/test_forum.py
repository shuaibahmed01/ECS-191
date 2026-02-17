"""Tests for forum API endpoints."""

import json
from services.datastore_service import create_user


class TestListPosts:
    """Tests for GET /v1/courses/<course_id>/posts"""

    def test_list_posts_returns_200(self, auth_client):
        response = auth_client.get("/v1/courses/ecs_032a/posts")
        assert response.status_code == 200

    def test_list_posts_returns_empty_list(self, auth_client):
        response = auth_client.get("/v1/courses/ecs_032a/posts")
        data = json.loads(response.data)
        assert data["posts"] == []

    def test_list_posts_returns_created_post(self, auth_client):
        create_user("test_user", "test@test.com", "Test User")
        auth_client.post(
            "/v1/courses/ecs_032a/posts",
            data=json.dumps({"title": "Hello", "body": "World"}),
            content_type="application/json",
        )
        response = auth_client.get("/v1/courses/ecs_032a/posts")
        data = json.loads(response.data)
        assert len(data["posts"]) == 1
        assert data["posts"][0]["title"] == "Hello"

    def test_list_posts_requires_auth(self, auth_client):
        response = auth_client.no_auth.get("/v1/courses/ecs_032a/posts")
        assert response.status_code == 401


class TestCreatePost:
    """Tests for POST /v1/courses/<course_id>/posts"""

    def test_create_post_returns_201(self, auth_client):
        create_user("test_user", "test@test.com", "Test User")
        response = auth_client.post(
            "/v1/courses/ecs_032a/posts",
            data=json.dumps({"title": "Title", "body": "Body"}),
            content_type="application/json",
        )
        assert response.status_code == 201

    def test_create_post_returns_post(self, auth_client):
        create_user("test_user", "test@test.com", "Test User")
        response = auth_client.post(
            "/v1/courses/ecs_032a/posts",
            data=json.dumps({"title": "My Title", "body": "My Body"}),
            content_type="application/json",
        )
        data = json.loads(response.data)
        assert data["title"] == "My Title"
        assert data["body"] == "My Body"
        assert data["author_name"] == "Test User"
        assert data["upvote_count"] == 0
        assert "id" in data

    def test_create_post_missing_title(self, auth_client):
        response = auth_client.post(
            "/v1/courses/ecs_032a/posts",
            data=json.dumps({"body": "Body only"}),
            content_type="application/json",
        )
        assert response.status_code == 400

    def test_create_post_missing_body(self, auth_client):
        response = auth_client.post(
            "/v1/courses/ecs_032a/posts",
            data=json.dumps({"title": "Title only"}),
            content_type="application/json",
        )
        assert response.status_code == 400

    def test_create_post_empty_request(self, auth_client):
        response = auth_client.post(
            "/v1/courses/ecs_032a/posts",
            data="",
            content_type="application/json",
        )
        assert response.status_code == 400


class TestGetPostDetail:
    """Tests for GET /v1/courses/<course_id>/posts/<post_id>"""

    def test_get_post_detail_returns_200(self, auth_client):
        create_user("test_user", "test@test.com", "Test User")
        resp = auth_client.post(
            "/v1/courses/ecs_032a/posts",
            data=json.dumps({"title": "T", "body": "B"}),
            content_type="application/json",
        )
        post_id = json.loads(resp.data)["id"]
        response = auth_client.get(f"/v1/courses/ecs_032a/posts/{post_id}")
        assert response.status_code == 200

    def test_get_post_detail_contains_post_and_comments(self, auth_client):
        create_user("test_user", "test@test.com", "Test User")
        resp = auth_client.post(
            "/v1/courses/ecs_032a/posts",
            data=json.dumps({"title": "T", "body": "B"}),
            content_type="application/json",
        )
        post_id = json.loads(resp.data)["id"]
        response = auth_client.get(f"/v1/courses/ecs_032a/posts/{post_id}")
        data = json.loads(response.data)
        assert "post" in data
        assert "comments" in data
        assert "has_upvoted" in data
        assert data["has_upvoted"] is False

    def test_get_post_detail_not_found(self, auth_client):
        response = auth_client.get("/v1/courses/ecs_032a/posts/nonexistent")
        assert response.status_code == 404


class TestUpvote:
    """Tests for POST /v1/courses/<course_id>/posts/<post_id>/upvote"""

    def test_upvote_returns_200(self, auth_client):
        create_user("test_user", "test@test.com", "Test User")
        resp = auth_client.post(
            "/v1/courses/ecs_032a/posts",
            data=json.dumps({"title": "T", "body": "B"}),
            content_type="application/json",
        )
        post_id = json.loads(resp.data)["id"]
        response = auth_client.post(f"/v1/courses/ecs_032a/posts/{post_id}/upvote")
        assert response.status_code == 200

    def test_upvote_toggles_on(self, auth_client):
        create_user("test_user", "test@test.com", "Test User")
        resp = auth_client.post(
            "/v1/courses/ecs_032a/posts",
            data=json.dumps({"title": "T", "body": "B"}),
            content_type="application/json",
        )
        post_id = json.loads(resp.data)["id"]
        response = auth_client.post(f"/v1/courses/ecs_032a/posts/{post_id}/upvote")
        data = json.loads(response.data)
        assert data["upvoted"] is True
        assert data["upvote_count"] == 1

    def test_upvote_toggles_off(self, auth_client):
        create_user("test_user", "test@test.com", "Test User")
        resp = auth_client.post(
            "/v1/courses/ecs_032a/posts",
            data=json.dumps({"title": "T", "body": "B"}),
            content_type="application/json",
        )
        post_id = json.loads(resp.data)["id"]
        # Upvote then un-upvote
        auth_client.post(f"/v1/courses/ecs_032a/posts/{post_id}/upvote")
        response = auth_client.post(f"/v1/courses/ecs_032a/posts/{post_id}/upvote")
        data = json.loads(response.data)
        assert data["upvoted"] is False
        assert data["upvote_count"] == 0

    def test_upvote_not_found(self, auth_client):
        response = auth_client.post("/v1/courses/ecs_032a/posts/nonexistent/upvote")
        assert response.status_code == 404


class TestComments:
    """Tests for POST /v1/courses/<course_id>/posts/<post_id>/comments"""

    def test_create_comment_returns_201(self, auth_client):
        create_user("test_user", "test@test.com", "Test User")
        resp = auth_client.post(
            "/v1/courses/ecs_032a/posts",
            data=json.dumps({"title": "T", "body": "B"}),
            content_type="application/json",
        )
        post_id = json.loads(resp.data)["id"]
        response = auth_client.post(
            f"/v1/courses/ecs_032a/posts/{post_id}/comments",
            data=json.dumps({"body": "Nice post!"}),
            content_type="application/json",
        )
        assert response.status_code == 201

    def test_create_comment_returns_comment(self, auth_client):
        create_user("test_user", "test@test.com", "Test User")
        resp = auth_client.post(
            "/v1/courses/ecs_032a/posts",
            data=json.dumps({"title": "T", "body": "B"}),
            content_type="application/json",
        )
        post_id = json.loads(resp.data)["id"]
        response = auth_client.post(
            f"/v1/courses/ecs_032a/posts/{post_id}/comments",
            data=json.dumps({"body": "Great!"}),
            content_type="application/json",
        )
        data = json.loads(response.data)
        assert data["body"] == "Great!"
        assert data["author_name"] == "Test User"
        assert data["parent_comment_id"] is None
        assert "id" in data

    def test_create_threaded_comment(self, auth_client):
        create_user("test_user", "test@test.com", "Test User")
        resp = auth_client.post(
            "/v1/courses/ecs_032a/posts",
            data=json.dumps({"title": "T", "body": "B"}),
            content_type="application/json",
        )
        post_id = json.loads(resp.data)["id"]
        # Create parent comment
        parent_resp = auth_client.post(
            f"/v1/courses/ecs_032a/posts/{post_id}/comments",
            data=json.dumps({"body": "Parent"}),
            content_type="application/json",
        )
        parent_id = json.loads(parent_resp.data)["id"]
        # Create reply
        reply_resp = auth_client.post(
            f"/v1/courses/ecs_032a/posts/{post_id}/comments",
            data=json.dumps({"body": "Reply", "parent_comment_id": parent_id}),
            content_type="application/json",
        )
        reply_data = json.loads(reply_resp.data)
        assert reply_data["parent_comment_id"] == parent_id
        assert parent_id in reply_data["path"]

    def test_create_comment_missing_body(self, auth_client):
        create_user("test_user", "test@test.com", "Test User")
        resp = auth_client.post(
            "/v1/courses/ecs_032a/posts",
            data=json.dumps({"title": "T", "body": "B"}),
            content_type="application/json",
        )
        post_id = json.loads(resp.data)["id"]
        response = auth_client.post(
            f"/v1/courses/ecs_032a/posts/{post_id}/comments",
            data=json.dumps({"not_body": "oops"}),
            content_type="application/json",
        )
        assert response.status_code == 400

    def test_create_comment_on_nonexistent_post(self, auth_client):
        response = auth_client.post(
            "/v1/courses/ecs_032a/posts/nonexistent/comments",
            data=json.dumps({"body": "comment"}),
            content_type="application/json",
        )
        assert response.status_code == 404

    def test_comments_appear_in_post_detail(self, auth_client):
        create_user("test_user", "test@test.com", "Test User")
        resp = auth_client.post(
            "/v1/courses/ecs_032a/posts",
            data=json.dumps({"title": "T", "body": "B"}),
            content_type="application/json",
        )
        post_id = json.loads(resp.data)["id"]
        auth_client.post(
            f"/v1/courses/ecs_032a/posts/{post_id}/comments",
            data=json.dumps({"body": "A comment"}),
            content_type="application/json",
        )
        detail = auth_client.get(f"/v1/courses/ecs_032a/posts/{post_id}")
        data = json.loads(detail.data)
        assert len(data["comments"]) == 1
        assert data["comments"][0]["body"] == "A comment"


class TestNoEnrollmentRequired:
    """Forum endpoints should NOT require enrollment."""

    def test_any_user_can_list_posts(self, auth_client):
        response = auth_client.get("/v1/courses/ecs_032a/posts", uid="random_user")
        assert response.status_code == 200

    def test_any_user_can_create_post(self, auth_client):
        create_user("random_user", "rand@test.com", "Random User")
        response = auth_client.post(
            "/v1/courses/ecs_032a/posts",
            uid="random_user",
            data=json.dumps({"title": "T", "body": "B"}),
            content_type="application/json",
        )
        assert response.status_code == 201

"""Tests for chat API endpoints."""

import json
from services.datastore_service import create_user


class TestGetMessages:
    """Tests for GET /v1/classes/<class_id>/messages"""

    def test_get_messages_returns_200(self, auth_client):
        """Should return 200 status code."""
        auth_client.post("/v1/users/me/classes",
            data=json.dumps({"class_id": "ecs_032a"}),
            content_type="application/json"
        )
        response = auth_client.get("/v1/classes/ecs_032a/messages")
        assert response.status_code == 200

    def test_get_messages_returns_list(self, auth_client):
        """Should return a list of messages."""
        auth_client.post("/v1/users/me/classes",
            data=json.dumps({"class_id": "ecs_032a"}),
            content_type="application/json"
        )
        response = auth_client.get("/v1/classes/ecs_032a/messages")
        data = json.loads(response.data)
        assert "messages" in data
        assert isinstance(data["messages"], list)

    def test_get_messages_for_class_without_messages(self, auth_client):
        """Should return empty list for class with no messages."""
        auth_client.post("/v1/users/me/classes",
            data=json.dumps({"class_id": "ecs_032b"}),
            content_type="application/json"
        )
        response = auth_client.get("/v1/classes/ecs_032b/messages")
        data = json.loads(response.data)
        assert data["messages"] == []

    def test_get_messages_contains_required_fields(self, auth_client):
        """Should return messages with all required fields."""
        create_user("test_user", "test@test.com", "Test User")
        auth_client.post("/v1/users/me/classes",
            data=json.dumps({"class_id": "ecs_032a"}),
            content_type="application/json"
        )
        # Post a message first
        auth_client.post(
            "/v1/classes/ecs_032a/messages",
            data=json.dumps({"content": "Hello!"}),
            content_type="application/json"
        )
        response = auth_client.get("/v1/classes/ecs_032a/messages")
        data = json.loads(response.data)
        message = data["messages"][0]

        assert "id" in message
        assert "class_id" in message
        assert "sender_id" in message
        assert "sender_name" in message
        assert "content" in message
        assert "timestamp" in message

    def test_get_messages_sorted_by_timestamp(self, auth_client):
        """Messages should be sorted by timestamp."""
        create_user("test_user", "test@test.com", "Test User")
        auth_client.post("/v1/users/me/classes",
            data=json.dumps({"class_id": "ecs_032a"}),
            content_type="application/json"
        )
        # Post multiple messages
        auth_client.post(
            "/v1/classes/ecs_032a/messages",
            data=json.dumps({"content": "First"}),
            content_type="application/json"
        )
        auth_client.post(
            "/v1/classes/ecs_032a/messages",
            data=json.dumps({"content": "Second"}),
            content_type="application/json"
        )
        response = auth_client.get("/v1/classes/ecs_032a/messages")
        data = json.loads(response.data)
        messages = data["messages"]

        timestamps = [m["timestamp"] for m in messages]
        assert timestamps == sorted(timestamps)


class TestPostMessage:
    """Tests for POST /v1/classes/<class_id>/messages"""

    def test_post_message_returns_201(self, auth_client):
        """Should return 201 status code on success."""
        create_user("test_user", "test@test.com", "Test User")
        auth_client.post("/v1/users/me/classes",
            data=json.dumps({"class_id": "ecs_032a"}),
            content_type="application/json"
        )
        response = auth_client.post(
            "/v1/classes/ecs_032a/messages",
            data=json.dumps({"content": "Hello!"}),
            content_type="application/json"
        )
        assert response.status_code == 201

    def test_post_message_returns_created_message(self, auth_client):
        """Should return the created message."""
        create_user("test_user", "test@test.com", "Test User")
        auth_client.post("/v1/users/me/classes",
            data=json.dumps({"class_id": "ecs_032a"}),
            content_type="application/json"
        )
        response = auth_client.post(
            "/v1/classes/ecs_032a/messages",
            data=json.dumps({"content": "Hello!"}),
            content_type="application/json"
        )
        data = json.loads(response.data)

        assert data["content"] == "Hello!"
        assert data["sender_name"] == "Test User"
        assert data["class_id"] == "ecs_032a"
        assert "id" in data

    def test_post_message_missing_content(self, auth_client):
        """Should return 400 when content is missing."""
        auth_client.post("/v1/users/me/classes",
            data=json.dumps({"class_id": "ecs_032a"}),
            content_type="application/json"
        )
        response = auth_client.post(
            "/v1/classes/ecs_032a/messages",
            data=json.dumps({"other_field": "value"}),
            content_type="application/json"
        )
        assert response.status_code == 400
        data = json.loads(response.data)
        assert "content" in data["error"].lower()

    def test_post_message_empty_body(self, auth_client):
        """Should return 400 when body is empty."""
        auth_client.post("/v1/users/me/classes",
            data=json.dumps({"class_id": "ecs_032a"}),
            content_type="application/json"
        )
        response = auth_client.post(
            "/v1/classes/ecs_032a/messages",
            data="",
            content_type="application/json"
        )
        assert response.status_code == 400

    def test_post_message_persists(self, auth_client):
        """Posted message should appear in subsequent GET."""
        create_user("test_user", "test@test.com", "Test User")
        auth_client.post("/v1/users/me/classes",
            data=json.dumps({"class_id": "ecs_032b"}),
            content_type="application/json"
        )

        # Post a new message
        auth_client.post(
            "/v1/classes/ecs_032b/messages",
            data=json.dumps({"content": "New message"}),
            content_type="application/json"
        )

        # Fetch messages and verify it's there
        response = auth_client.get("/v1/classes/ecs_032b/messages")
        data = json.loads(response.data)

        assert len(data["messages"]) == 1
        assert data["messages"][0]["content"] == "New message"

    def test_post_message_uses_authenticated_user(self, auth_client):
        """Should use authenticated user's ID for sender_id."""
        create_user("test_user", "test@test.com", "Test User")
        auth_client.post("/v1/users/me/classes",
            data=json.dumps({"class_id": "ecs_032a"}),
            content_type="application/json"
        )
        response = auth_client.post(
            "/v1/classes/ecs_032a/messages",
            data=json.dumps({"content": "Hello!"}),
            content_type="application/json"
        )
        data = json.loads(response.data)
        assert data["sender_id"] == "test_user"


class TestChatAuthorization:
    """Tests for chat access control."""

    def test_cannot_read_messages_without_enrollment(self, auth_client):
        """Should return 403 when not enrolled in class."""
        response = auth_client.get("/v1/classes/ecs_036c/messages", uid="unenrolled_user")
        assert response.status_code == 403

    def test_cannot_post_messages_without_enrollment(self, auth_client):
        """Should return 403 when posting to class not enrolled in."""
        response = auth_client.post(
            "/v1/classes/ecs_036c/messages",
            uid="unenrolled_user",
            data=json.dumps({"content": "Hello!"}),
            content_type="application/json"
        )
        assert response.status_code == 403

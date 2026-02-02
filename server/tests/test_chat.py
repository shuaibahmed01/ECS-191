"""Tests for chat API endpoints."""

import json


class TestGetMessages:
    """Tests for GET /v1/classes/<class_id>/messages"""

    def test_get_messages_returns_200(self, seeded_client):
        """Should return 200 status code."""
        response = seeded_client.get("/v1/classes/1/messages")
        assert response.status_code == 200

    def test_get_messages_returns_list(self, seeded_client):
        """Should return a list of messages."""
        response = seeded_client.get("/v1/classes/1/messages")
        data = json.loads(response.data)
        assert "messages" in data
        assert isinstance(data["messages"], list)

    def test_get_messages_for_class_with_seed_data(self, seeded_client):
        """Should return seed messages for class 1."""
        response = seeded_client.get("/v1/classes/1/messages")
        data = json.loads(response.data)
        assert len(data["messages"]) == 4  # Class 1 has 4 seed messages

    def test_get_messages_for_class_without_messages(self, seeded_client):
        """Should return empty list for class with no messages."""
        response = seeded_client.get("/v1/classes/2/messages")
        data = json.loads(response.data)
        assert data["messages"] == []

    def test_get_messages_contains_required_fields(self, seeded_client):
        """Should return messages with all required fields."""
        response = seeded_client.get("/v1/classes/1/messages")
        data = json.loads(response.data)
        message = data["messages"][0]

        assert "id" in message
        assert "class_id" in message
        assert "sender_id" in message
        assert "sender_name" in message
        assert "content" in message
        assert "timestamp" in message

    def test_get_messages_sorted_by_timestamp(self, seeded_client):
        """Messages should be sorted by timestamp."""
        response = seeded_client.get("/v1/classes/1/messages")
        data = json.loads(response.data)
        messages = data["messages"]

        timestamps = [m["timestamp"] for m in messages]
        assert timestamps == sorted(timestamps)


class TestPostMessage:
    """Tests for POST /v1/classes/<class_id>/messages"""

    def test_post_message_returns_201(self, seeded_client):
        """Should return 201 status code on success."""
        response = seeded_client.post(
            "/v1/classes/1/messages",
            data=json.dumps({"content": "Hello!", "sender_name": "Test User"}),
            content_type="application/json"
        )
        assert response.status_code == 201

    def test_post_message_returns_created_message(self, seeded_client):
        """Should return the created message."""
        response = seeded_client.post(
            "/v1/classes/1/messages",
            data=json.dumps({"content": "Hello!", "sender_name": "Test User"}),
            content_type="application/json"
        )
        data = json.loads(response.data)

        assert data["content"] == "Hello!"
        assert data["sender_name"] == "Test User"
        assert data["class_id"] == 1
        assert "id" in data
        assert "timestamp" in data

    def test_post_message_missing_content(self, seeded_client):
        """Should return 400 when content is missing."""
        response = seeded_client.post(
            "/v1/classes/1/messages",
            data=json.dumps({"sender_name": "Test User"}),
            content_type="application/json"
        )
        assert response.status_code == 400
        data = json.loads(response.data)
        assert "content" in data["error"].lower()

    def test_post_message_missing_sender_name(self, seeded_client):
        """Should return 400 when sender_name is missing."""
        response = seeded_client.post(
            "/v1/classes/1/messages",
            data=json.dumps({"content": "Hello!"}),
            content_type="application/json"
        )
        assert response.status_code == 400
        data = json.loads(response.data)
        assert "sender_name" in data["error"].lower()

    def test_post_message_empty_body(self, seeded_client):
        """Should return 400 when body is empty."""
        response = seeded_client.post(
            "/v1/classes/1/messages",
            data="",
            content_type="application/json"
        )
        assert response.status_code == 400

    def test_post_message_persists(self, seeded_client):
        """Posted message should appear in subsequent GET."""
        # Post a new message
        seeded_client.post(
            "/v1/classes/2/messages",
            data=json.dumps({"content": "New message", "sender_name": "Alice"}),
            content_type="application/json"
        )

        # Fetch messages and verify it's there
        response = seeded_client.get("/v1/classes/2/messages")
        data = json.loads(response.data)

        assert len(data["messages"]) == 1
        assert data["messages"][0]["content"] == "New message"
        assert data["messages"][0]["sender_name"] == "Alice"

    def test_post_message_uses_header_user_id(self, seeded_client):
        """Should use X-User-Id header for sender_id."""
        response = seeded_client.post(
            "/v1/classes/1/messages",
            data=json.dumps({"content": "Hello!", "sender_name": "Test User"}),
            content_type="application/json",
            headers={"X-User-Id": "42"}
        )
        data = json.loads(response.data)
        assert data["sender_id"] == 42

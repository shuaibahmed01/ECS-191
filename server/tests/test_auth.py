"""Tests for authentication feature."""

import json


class TestPublicEndpoints:
    """Tests for endpoints that don't require authentication."""

    def test_list_classes_no_auth(self, seeded_client):
        """GET /v1/classes should work without auth."""
        response = seeded_client.get("/v1/classes")
        assert response.status_code == 200

    def test_get_class_no_auth(self, seeded_client):
        """GET /v1/classes/<id> should work without auth."""
        response = seeded_client.get("/v1/classes/1")
        assert response.status_code == 200

    def test_health_check(self, client):
        """GET /health should work without auth."""
        response = client.get("/health")
        assert response.status_code == 200


class TestProtectedEndpoints:
    """Tests for endpoints that require authentication."""

    def test_get_my_classes_requires_auth(self, seeded_client):
        """GET /v1/users/me/classes should return 401 without auth."""
        response = seeded_client.get("/v1/users/me/classes")
        assert response.status_code == 401

    def test_enroll_requires_auth(self, seeded_client):
        """POST /v1/users/me/classes should return 401 without auth."""
        response = seeded_client.post(
            "/v1/users/me/classes",
            data=json.dumps({"class_id": 1}),
            content_type="application/json"
        )
        assert response.status_code == 401

    def test_unenroll_requires_auth(self, seeded_client):
        """DELETE /v1/users/me/classes/<id> should return 401 without auth."""
        response = seeded_client.delete("/v1/users/me/classes/1")
        assert response.status_code == 401

    def test_get_messages_requires_auth(self, seeded_client):
        """GET /v1/classes/<id>/messages should return 401 without auth."""
        response = seeded_client.get("/v1/classes/1/messages")
        assert response.status_code == 401

    def test_post_message_requires_auth(self, seeded_client):
        """POST /v1/classes/<id>/messages should return 401 without auth."""
        response = seeded_client.post(
            "/v1/classes/1/messages",
            data=json.dumps({"content": "Hello"}),
            content_type="application/json"
        )
        assert response.status_code == 401


class TestEnrollment:
    """Tests for enrollment with authentication."""

    def test_enroll_with_auth(self, auth_client):
        """Should enroll user when authenticated."""
        response = auth_client.post(
            "/v1/users/me/classes",
            data=json.dumps({"class_id": 1}),
            content_type="application/json"
        )
        assert response.status_code == 201
        data = json.loads(response.data)
        assert "enrollment_id" in data
        assert data["id"] == 1

    def test_get_enrolled_classes(self, auth_client):
        """Should return enrolled classes for authenticated user."""
        # Enroll first
        auth_client.post(
            "/v1/users/me/classes",
            data=json.dumps({"class_id": 1}),
            content_type="application/json"
        )

        # Get enrolled classes
        response = auth_client.get("/v1/users/me/classes")
        assert response.status_code == 200
        data = json.loads(response.data)
        assert len(data["classes"]) == 1

    def test_users_have_separate_enrollments(self, auth_client):
        """Different users should have separate enrollment lists."""
        # User 1 enrolls in class 1
        auth_client.post(
            "/v1/users/me/classes",
            uid="user1",
            data=json.dumps({"class_id": 1}),
            content_type="application/json"
        )

        # User 2 enrolls in class 2
        auth_client.post(
            "/v1/users/me/classes",
            uid="user2",
            data=json.dumps({"class_id": 2}),
            content_type="application/json"
        )

        # User 2 should only see class 2
        response = auth_client.get("/v1/users/me/classes", uid="user2")
        data = json.loads(response.data)
        assert len(data["classes"]) == 1
        assert data["classes"][0]["id"] == 2

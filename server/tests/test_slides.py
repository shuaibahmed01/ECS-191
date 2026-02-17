"""Tests for slides API endpoints."""

import json
from unittest.mock import patch, MagicMock


MOCK_SLIDE_SUMMARY = "This lecture covers sorting algorithms including bubble sort, merge sort, and quicksort. Key concepts: time complexity analysis, divide-and-conquer strategy, and stability of sorting algorithms."


def _enroll_user(auth_client, class_id="ecs_191"):
    """Helper to enroll the test user in a class."""
    auth_client.post(
        "/v1/users/me/classes",
        data=json.dumps({"class_id": class_id}),
        content_type="application/json",
    )


class TestUploadSlides:
    """Tests for POST /v1/classes/<class_id>/slides"""

    def test_upload_slides_returns_201(self, auth_client):
        """Should return 201 on successful upload."""
        _enroll_user(auth_client)

        with patch("api.syllabus.extract_slides", return_value=MOCK_SLIDE_SUMMARY), \
             patch("api.syllabus.save_slide", return_value="slide_001"):
            response = auth_client.post(
                "/v1/classes/ecs_191/slides",
                data=json.dumps({
                    "file_data": "base64encodeddata",
                    "file_type": "application/pdf",
                    "title": "Week 3 - Sorting",
                }),
                content_type="application/json",
            )

        assert response.status_code == 201

    def test_upload_slides_returns_slide_data(self, auth_client):
        """Should return the created slide with title and summary."""
        _enroll_user(auth_client)

        with patch("api.syllabus.extract_slides", return_value=MOCK_SLIDE_SUMMARY), \
             patch("api.syllabus.save_slide", return_value="slide_001"):
            response = auth_client.post(
                "/v1/classes/ecs_191/slides",
                data=json.dumps({
                    "file_data": "base64encodeddata",
                    "file_type": "application/pdf",
                    "title": "Week 3 - Sorting",
                }),
                content_type="application/json",
            )

        data = json.loads(response.data)
        assert "slide" in data
        assert data["slide"]["id"] == "slide_001"
        assert data["slide"]["title"] == "Week 3 - Sorting"
        assert data["slide"]["summary"] == MOCK_SLIDE_SUMMARY

    def test_upload_slides_missing_title(self, auth_client):
        """Should return 400 when title is missing."""
        _enroll_user(auth_client)

        response = auth_client.post(
            "/v1/classes/ecs_191/slides",
            data=json.dumps({
                "file_data": "base64encodeddata",
                "file_type": "application/pdf",
            }),
            content_type="application/json",
        )

        assert response.status_code == 400

    def test_upload_slides_missing_file_data(self, auth_client):
        """Should return 400 when file_data is missing."""
        _enroll_user(auth_client)

        response = auth_client.post(
            "/v1/classes/ecs_191/slides",
            data=json.dumps({
                "file_type": "application/pdf",
                "title": "Week 3",
            }),
            content_type="application/json",
        )

        assert response.status_code == 400

    def test_upload_slides_unsupported_file_type(self, auth_client):
        """Should return 400 for unsupported file types."""
        _enroll_user(auth_client)

        response = auth_client.post(
            "/v1/classes/ecs_191/slides",
            data=json.dumps({
                "file_data": "base64encodeddata",
                "file_type": "application/zip",
                "title": "Week 3",
            }),
            content_type="application/json",
        )

        assert response.status_code == 400

    def test_upload_slides_empty_body(self, auth_client):
        """Should return 400 when body is empty."""
        _enroll_user(auth_client)

        response = auth_client.post(
            "/v1/classes/ecs_191/slides",
            data="",
            content_type="application/json",
        )

        assert response.status_code == 400

    def test_upload_slides_file_too_large(self, auth_client):
        """Should return 400 when file exceeds 10MB."""
        _enroll_user(auth_client)

        large_data = "A" * (10 * 1024 * 1024 + 1)
        response = auth_client.post(
            "/v1/classes/ecs_191/slides",
            data=json.dumps({
                "file_data": large_data,
                "file_type": "application/pdf",
                "title": "Huge Slides",
            }),
            content_type="application/json",
        )

        assert response.status_code == 400

    def test_upload_slides_not_enrolled(self, auth_client):
        """Should return 403 when user is not enrolled."""
        response = auth_client.post(
            "/v1/classes/ecs_191/slides",
            uid="unenrolled_user",
            data=json.dumps({
                "file_data": "base64encodeddata",
                "file_type": "application/pdf",
                "title": "Week 3",
            }),
            content_type="application/json",
        )

        assert response.status_code == 403

    def test_upload_slides_extraction_failure(self, auth_client):
        """Should return 500 when Claude extraction fails."""
        _enroll_user(auth_client)

        with patch("api.syllabus.extract_slides", side_effect=Exception("API error")):
            response = auth_client.post(
                "/v1/classes/ecs_191/slides",
                data=json.dumps({
                    "file_data": "base64encodeddata",
                    "file_type": "application/pdf",
                    "title": "Week 3",
                }),
                content_type="application/json",
            )

        assert response.status_code == 500


class TestGetSlides:
    """Tests for GET /v1/classes/<class_id>/slides"""

    def test_get_slides_returns_200(self, auth_client):
        """Should return 200 status code."""
        _enroll_user(auth_client)

        with patch("api.syllabus.get_slides", return_value=[]):
            response = auth_client.get("/v1/classes/ecs_191/slides")

        assert response.status_code == 200

    def test_get_slides_returns_list(self, auth_client):
        """Should return a list of slides."""
        _enroll_user(auth_client)

        mock_slides = [
            {"id": "slide_001", "title": "Week 1", "summary": "Intro topics", "uploaded_by": "user1", "uploaded_at": "2026-02-16T12:00:00Z"},
            {"id": "slide_002", "title": "Week 2", "summary": "More topics", "uploaded_by": "user1", "uploaded_at": "2026-02-17T12:00:00Z"},
        ]

        with patch("api.syllabus.get_slides", return_value=mock_slides):
            response = auth_client.get("/v1/classes/ecs_191/slides")

        data = json.loads(response.data)
        assert "slides" in data
        assert len(data["slides"]) == 2
        assert data["slides"][0]["title"] == "Week 1"
        assert data["slides"][1]["title"] == "Week 2"

    def test_get_slides_empty_class(self, auth_client):
        """Should return empty list for class with no slides."""
        _enroll_user(auth_client)

        with patch("api.syllabus.get_slides", return_value=[]):
            response = auth_client.get("/v1/classes/ecs_191/slides")

        data = json.loads(response.data)
        assert data["slides"] == []

    def test_get_slides_not_enrolled(self, auth_client):
        """Should return 403 when user is not enrolled."""
        response = auth_client.get("/v1/classes/ecs_191/slides", uid="unenrolled_user")
        assert response.status_code == 403


class TestDeleteSlide:
    """Tests for DELETE /v1/classes/<class_id>/slides/<slide_id>"""

    def test_delete_slide_returns_200(self, auth_client):
        """Should return 200 on successful delete."""
        _enroll_user(auth_client)

        with patch("api.syllabus.delete_slide"):
            response = auth_client.delete("/v1/classes/ecs_191/slides/slide_001")

        assert response.status_code == 200

    def test_delete_slide_not_enrolled(self, auth_client):
        """Should return 403 when user is not enrolled."""
        response = auth_client.delete("/v1/classes/ecs_191/slides/slide_001", uid="unenrolled_user")
        assert response.status_code == 403

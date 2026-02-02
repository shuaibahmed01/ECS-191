"""Pytest fixtures for CourseHub tests."""

import pytest
from main import create_app


@pytest.fixture
def app():
    """Create application for testing."""
    app = create_app()
    app.config["TESTING"] = True
    return app


@pytest.fixture
def client(app):
    """Create a test client."""
    return app.test_client()


@pytest.fixture
def seeded_client(client):
    """Create a test client with seeded data."""
    client.post("/v1/seed")
    return client

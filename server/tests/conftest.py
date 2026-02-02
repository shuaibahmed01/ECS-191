"""Pytest fixtures for CourseHub tests."""

import pytest
from unittest.mock import patch


@pytest.fixture
def app():
    """Create application for testing with mocked Firebase."""
    with patch('services.auth_service.init_firebase'):
        from main import create_app
        app = create_app()
        app.config["TESTING"] = True
        yield app


@pytest.fixture
def client(app):
    """Create a test client."""
    return app.test_client()


@pytest.fixture
def seeded_client(client):
    """Create a test client with seeded data."""
    client.post("/v1/seed")
    return client


@pytest.fixture
def auth_client(client):
    """
    Create a test client with auth helper.

    Usage:
        def test_something(auth_client):
            response = auth_client.get('/v1/users/me/classes', uid='user123')
    """
    client.post("/v1/seed")

    class AuthClient:
        def __init__(self, test_client):
            self._client = test_client

        def _make_request(self, method, url, uid="test_user", **kwargs):
            token_data = {'uid': uid, 'email': f'{uid}@test.com', 'name': 'Test User'}
            headers = kwargs.pop('headers', {})
            headers['Authorization'] = 'Bearer fake_token'

            with patch('services.auth_service.verify_token', return_value=token_data):
                return getattr(self._client, method)(url, headers=headers, **kwargs)

        def get(self, url, uid="test_user", **kwargs):
            return self._make_request('get', url, uid, **kwargs)

        def post(self, url, uid="test_user", **kwargs):
            return self._make_request('post', url, uid, **kwargs)

        def delete(self, url, uid="test_user", **kwargs):
            return self._make_request('delete', url, uid, **kwargs)

        # Access underlying client for non-auth requests
        @property
        def no_auth(self):
            return self._client

    return AuthClient(client)

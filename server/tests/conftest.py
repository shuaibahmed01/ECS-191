"""Pytest fixtures for CourseHub tests."""

import pytest
from datetime import datetime, timezone
from unittest.mock import patch, MagicMock


# Test course data matching Firestore document structure
TEST_COURSES = {
    "ecs_032a": {"code": "ECS 032A", "name": "Intro to Programming", "lecture_times": ["6:10 - 7:30 PM, MW"], "discussion_times": ["9:00 - 9:50 AM, F"]},
    "ecs_032b": {"code": "ECS 032B", "name": "Intro to Data Structures", "lecture_times": ["1:40 - 3:00 PM, TR"], "discussion_times": ["9:00 - 9:50 AM, M"]},
    "ecs_036c": {"code": "ECS 036C", "name": "Data Structures", "lecture_times": ["7:40 - 9:00 PM, TR"], "discussion_times": ["2:10 - 3:00 PM, W"]},
    "ecs_191": {"code": "ECS 191", "name": "Software Design Project", "lecture_times": ["11:00 - 12:20 PM, TR"], "discussion_times": ["2:10 - 3:00 PM, T"]},
}


def _mock_get_all_classes(query=""):
    classes = [
        {"id": doc_id, "class_code": data["code"], "class_name": data["name"]}
        for doc_id, data in TEST_COURSES.items()
    ]
    if query:
        query_lower = query.lower()
        classes = [
            c for c in classes
            if query_lower in c["class_code"].lower()
            or query_lower in c["class_name"].lower()
        ]
    return classes


def _mock_get_class_by_id(class_id):
    data = TEST_COURSES.get(class_id)
    if data is None:
        return None
    return {"id": class_id, "class_code": data["code"], "class_name": data["name"]}


def _create_mock_db(enrollments_store, users_store, messages_store):
    """Create a mock Firestore DB that handles enrollment, user, and message operations."""
    db_instance = MagicMock()
    _next_msg_id = [0]  # mutable counter for auto-generated doc IDs

    def setup_user_enrollments(user_id):
        if user_id not in enrollments_store:
            enrollments_store[user_id] = {}

    def mock_collection(name):
        collection_mock = MagicMock()

        def mock_document(doc_id=None):
            doc_mock = MagicMock()

            if name == 'users':
                user_id = doc_id
                setup_user_enrollments(user_id)

                # User document-level set/get for profile storage
                def mock_user_set(data, merge=False):
                    if merge and user_id in users_store:
                        users_store[user_id].update(data)
                    else:
                        users_store[user_id] = data

                def mock_user_get():
                    result = MagicMock()
                    result.exists = user_id in users_store
                    result.id = user_id
                    if result.exists:
                        result.to_dict.return_value = users_store[user_id]
                    return result

                doc_mock.set = mock_user_set
                doc_mock.get = mock_user_get

                def mock_subcollection(sub_name):
                    if sub_name == 'enrollments':
                        sub_mock = MagicMock()

                        def mock_enrollment_doc(enroll_id=None):
                            if enroll_id is None:
                                enroll_id = f"enroll_{len(enrollments_store.get(user_id, {})) + 1}"

                            enroll_doc = MagicMock()
                            enroll_doc.id = enroll_id

                            def mock_set(data):
                                enrollments_store[user_id][enroll_id] = data

                            def mock_get():
                                result = MagicMock()
                                result.exists = enroll_id in enrollments_store.get(user_id, {})
                                if result.exists:
                                    result.to_dict.return_value = enrollments_store[user_id][enroll_id]
                                result.id = enroll_id
                                return result

                            def mock_delete():
                                if user_id in enrollments_store and enroll_id in enrollments_store[user_id]:
                                    del enrollments_store[user_id][enroll_id]

                            enroll_doc.set = mock_set
                            enroll_doc.get = mock_get
                            enroll_doc.delete = mock_delete
                            return enroll_doc

                        def mock_stream():
                            results = []
                            for eid, edata in enrollments_store.get(user_id, {}).items():
                                doc = MagicMock()
                                doc.id = eid
                                doc.to_dict.return_value = edata
                                results.append(doc)
                            return iter(results)

                        def mock_where(field, op, value):
                            query_mock = MagicMock()

                            def mock_limit(n):
                                limit_mock = MagicMock()

                                def mock_limit_stream():
                                    results = []
                                    count = 0
                                    for eid, edata in enrollments_store.get(user_id, {}).items():
                                        if edata.get(field) == value and count < n:
                                            doc = MagicMock()
                                            doc.id = eid
                                            doc.to_dict.return_value = edata
                                            results.append(doc)
                                            count += 1
                                    return iter(results)

                                limit_mock.stream = mock_limit_stream
                                return limit_mock

                            query_mock.limit = mock_limit
                            return query_mock

                        sub_mock.document = mock_enrollment_doc
                        sub_mock.stream = mock_stream
                        sub_mock.where = mock_where
                        return sub_mock
                    return MagicMock()

                doc_mock.collection = mock_subcollection

            elif name == 'courses':
                # Mock course document lookup
                course_data = TEST_COURSES.get(doc_id)

                def mock_course_get():
                    result = MagicMock()
                    result.exists = course_data is not None
                    result.id = doc_id
                    if course_data:
                        result.to_dict.return_value = course_data
                    return result

                doc_mock.get = mock_course_get

            elif name == 'classes':
                # Mock classes/{class_id} document for messages subcollection
                class_id = doc_id

                def mock_messages_subcollection(sub_name):
                    if sub_name == 'messages':
                        msgs_mock = MagicMock()

                        if class_id not in messages_store:
                            messages_store[class_id] = {}

                        def mock_order_by(field):
                            order_mock = MagicMock()

                            def mock_order_stream():
                                items = list(messages_store.get(class_id, {}).items())
                                items.sort(key=lambda x: x[1].get("timestamp", ""))
                                results = []
                                for mid, mdata in items:
                                    doc = MagicMock()
                                    doc.id = mid
                                    doc.to_dict.return_value = mdata
                                    results.append(doc)
                                return iter(results)

                            order_mock.stream = mock_order_stream
                            return order_mock

                        def mock_add(data):
                            _next_msg_id[0] += 1
                            msg_id = f"msg_{_next_msg_id[0]}"
                            stored = data.copy()
                            # Replace SERVER_TIMESTAMP sentinel with actual timestamp
                            if not isinstance(stored.get("timestamp"), str):
                                stored["timestamp"] = datetime.now(timezone.utc)
                            messages_store.setdefault(class_id, {})[msg_id] = stored
                            ref_mock = MagicMock()
                            ref_mock.id = msg_id
                            return (None, ref_mock)

                        msgs_mock.order_by = mock_order_by
                        msgs_mock.add = mock_add
                        return msgs_mock
                    return MagicMock()

                doc_mock.collection = mock_messages_subcollection

            return doc_mock

        def mock_stream():
            """Stream all documents in a collection."""
            if name == 'courses':
                results = []
                for doc_id, data in TEST_COURSES.items():
                    doc = MagicMock()
                    doc.id = doc_id
                    doc.to_dict.return_value = data
                    results.append(doc)
                return iter(results)
            return iter([])

        collection_mock.document = mock_document
        collection_mock.stream = mock_stream
        return collection_mock

    db_instance.collection = mock_collection
    return db_instance


@pytest.fixture
def app():
    """Create application for testing with mocked Firebase."""
    enrollments_store = {}
    users_store = {}
    messages_store = {}

    with patch('services.auth_service.init_firebase'), \
         patch('services.datastore_service._get_db') as mock_db:

        mock_db.return_value = _create_mock_db(enrollments_store, users_store, messages_store)

        from main import create_app
        app = create_app()
        app.config["TESTING"] = True
        yield app


@pytest.fixture
def client(app):
    """Create a test client."""
    return app.test_client()


@pytest.fixture
def auth_client(client):
    """
    Create a test client with auth helper.

    Usage:
        def test_something(auth_client):
            response = auth_client.get('/v1/users/me/classes', uid='user123')
    """
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

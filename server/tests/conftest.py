"""Pytest fixtures for CourseHub tests."""

import pytest
from datetime import datetime, timezone
from unittest.mock import patch, MagicMock


class _Increment:
    """Sentinel that mimics firestore.Increment for mock updates."""
    def __init__(self, value):
        self.value = value


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


def _create_mock_db(enrollments_store, users_store, messages_store,
                    posts_store=None, comments_store=None, upvotes_store=None):
    """Create a mock Firestore DB that handles enrollment, user, message, and forum operations."""
    db_instance = MagicMock()
    _next_msg_id = [0]  # mutable counter for auto-generated doc IDs
    _next_post_id = [0]
    _next_comment_id = [0]

    if posts_store is None:
        posts_store = {}
    if comments_store is None:
        comments_store = {}
    if upvotes_store is None:
        upvotes_store = {}

    def setup_user_enrollments(user_id):
        if user_id not in enrollments_store:
            enrollments_store[user_id] = {}

    def _mock_upvotes_collection(course_id, post_id):
        """Mock upvotes subcollection for a post."""
        sub = MagicMock()
        key = (course_id, post_id)
        if key not in upvotes_store:
            upvotes_store[key] = {}

        def mock_upvote_doc(user_id):
            udoc = MagicMock()
            udoc.id = user_id

            def mock_get(uid=user_id, k=key):
                r = MagicMock()
                r.exists = uid in upvotes_store.get(k, {})
                r.id = uid
                if r.exists:
                    r.to_dict.return_value = upvotes_store[k][uid]
                return r

            def mock_set(data, uid=user_id, k=key):
                upvotes_store.setdefault(k, {})[uid] = data

            def mock_delete(uid=user_id, k=key):
                upvotes_store.get(k, {}).pop(uid, None)

            udoc.get = mock_get
            udoc.set = mock_set
            udoc.delete = mock_delete
            return udoc

        sub.document = mock_upvote_doc
        return sub

    def _mock_comments_collection(course_id, post_id):
        """Mock comments subcollection for a post."""
        sub = MagicMock()
        key = (course_id, post_id)
        if key not in comments_store:
            comments_store[key] = {}

        def mock_comment_doc(comment_id=None, k=key):
            if comment_id is None:
                _next_comment_id[0] += 1
                comment_id = f"comment_{_next_comment_id[0]}"
            cdoc = MagicMock()
            cdoc.id = comment_id

            def mock_get(cid=comment_id, kk=k):
                r = MagicMock()
                r.exists = cid in comments_store.get(kk, {})
                r.id = cid
                if r.exists:
                    r.to_dict.return_value = comments_store[kk][cid]
                return r

            def mock_set(data, cid=comment_id, kk=k):
                stored = data.copy()
                if not isinstance(stored.get("created_at"), str):
                    stored["created_at"] = datetime.now(timezone.utc)
                comments_store.setdefault(kk, {})[cid] = stored

            cdoc.get = mock_get
            cdoc.set = mock_set
            return cdoc

        def mock_order_by(field, k=key):
            order_mock = MagicMock()

            def mock_stream():
                items = list(comments_store.get(k, {}).items())
                items.sort(key=lambda x: x[1].get(field, ""))
                results = []
                for cid, cdata in items:
                    d = MagicMock()
                    d.id = cid
                    d.to_dict.return_value = cdata
                    results.append(d)
                return iter(results)

            order_mock.stream = mock_stream
            return order_mock

        sub.document = mock_comment_doc
        sub.order_by = mock_order_by
        return sub

    def _mock_posts_collection(course_id):
        """Mock posts subcollection for a course."""
        sub = MagicMock()
        if course_id not in posts_store:
            posts_store[course_id] = {}

        def mock_post_doc(post_id=None, cid=course_id):
            if post_id is None:
                _next_post_id[0] += 1
                post_id = f"post_{_next_post_id[0]}"
            pdoc = MagicMock()
            pdoc.id = post_id

            def mock_get(pid=post_id, c=cid):
                r = MagicMock()
                r.exists = pid in posts_store.get(c, {})
                r.id = pid
                if r.exists:
                    r.to_dict.return_value = posts_store[c][pid]
                return r

            def mock_set(data, pid=post_id, c=cid):
                stored = data.copy()
                if not isinstance(stored.get("created_at"), str):
                    stored["created_at"] = datetime.now(timezone.utc)
                posts_store.setdefault(c, {})[pid] = stored

            def mock_update(data, pid=post_id, c=cid):
                if pid in posts_store.get(c, {}):
                    for k, v in data.items():
                        if isinstance(v, _Increment):
                            posts_store[c][pid][k] = posts_store[c][pid].get(k, 0) + v.value
                        else:
                            posts_store[c][pid][k] = v

            pdoc.get = mock_get
            pdoc.set = mock_set
            pdoc.update = mock_update

            def mock_post_subcollection(sub_name, pid=post_id, c=cid):
                if sub_name == 'upvotes':
                    return _mock_upvotes_collection(c, pid)
                elif sub_name == 'comments':
                    return _mock_comments_collection(c, pid)
                return MagicMock()

            pdoc.collection = mock_post_subcollection
            return pdoc

        def mock_add(data, cid=course_id):
            _next_post_id[0] += 1
            pid = f"post_{_next_post_id[0]}"
            stored = data.copy()
            if not isinstance(stored.get("created_at"), str):
                stored["created_at"] = datetime.now(timezone.utc)
            posts_store.setdefault(cid, {})[pid] = stored
            ref = MagicMock()
            ref.id = pid
            return (None, ref)

        def mock_order_by(field, direction=None, cid=course_id):
            order_mock = MagicMock()

            def mock_stream():
                items = list(posts_store.get(cid, {}).items())
                reverse = direction is not None  # DESCENDING
                items.sort(key=lambda x: x[1].get(field, ""), reverse=reverse)
                results = []
                for pid, pdata in items:
                    d = MagicMock()
                    d.id = pid
                    d.to_dict.return_value = pdata
                    results.append(d)
                return iter(results)

            order_mock.stream = mock_stream
            return order_mock

        sub.document = mock_post_doc
        sub.add = mock_add
        sub.order_by = mock_order_by
        return sub

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
                course_id_outer = doc_id
                course_data = TEST_COURSES.get(doc_id)

                def mock_course_get(cid=course_id_outer, cdata=course_data):
                    result = MagicMock()
                    result.exists = cdata is not None
                    result.id = cid
                    if cdata:
                        result.to_dict.return_value = cdata
                    return result

                doc_mock.get = mock_course_get

                def mock_course_subcollection(sub_name, cid=course_id_outer):
                    if sub_name == 'posts':
                        return _mock_posts_collection(cid)
                    return MagicMock()

                doc_mock.collection = mock_course_subcollection

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
    posts_store = {}
    comments_store = {}
    upvotes_store = {}

    with patch('services.auth_service.init_firebase'), \
         patch('services.datastore_service._get_db') as mock_db, \
         patch('services.datastore_service.firestore.Increment', side_effect=_Increment), \
         patch('services.datastore_service.firestore.Query') as mock_query:

        mock_query.DESCENDING = 'DESCENDING'

        mock_db.return_value = _create_mock_db(
            enrollments_store, users_store, messages_store,
            posts_store, comments_store, upvotes_store,
        )

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

# CourseHub - Project Overview

## What is CourseHub?

CourseHub is an AI-powered course hub for college students tired of scattered group chats and buried syllabi. It unifies class communication, centralizes course info, and lets an AI agent handle tasks like emailing professors or syncing deadlines.

## The Problem

College students juggle multiple platforms for class communication: iMessage groups, Discord servers, GroupMe chats, and email threads. Syllabi get buried in inboxes, deadlines slip through the cracks, and there is no single source of truth for course information.

## The Solution

CourseHub provides a single iOS app where students can:

- **Browse and add classes** to their personal schedule
- **Automatically join group chats** for every enrolled class
- (Future) Use an **AI agent** to handle tasks like emailing professors or syncing deadlines

## Team Members

| Name | Role |
|------|------|
| Shuaib Ahmed | Developer |
| Isa Bukhari | Developer |
| Afifah Hadi | Developer |
| Hamza Bandakar | Developer |

**Course:** ECS 191 - Software Design Project, UC Davis, Winter 2026

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Client** | iOS (Swift, SwiftUI) |
| **Server** | Python 3.12, Flask with Blueprints |
| **Database** | Firestore (Native Mode) via `firebase-admin` SDK |
| **Authentication** | Firebase Authentication (Email/Password) |
| **Real-Time Chat** | Firestore snapshot listeners (iOS reads directly from Firestore) |
| **Deployment** | gunicorn |

## Milestone 0 Scope

Milestone 0 delivers two core features:

1. **Add Class** -- User searches and selects a class from hardcoded seed data (~13 UC Davis CS classes) and adds it to their schedule.
2. **Class Groupchat** -- When a user adds a class, they are automatically added to a group chat with all other users enrolled in that class.

### Simplifications for M0

- **No separate GroupChat entity.** Chat membership is derived from class enrollment.
- **Client-side search.** The client fetches all classes once and filters locally (dataset is small).

### Post-M0 Enhancements

- **Real-time chat.** Chat now uses Firestore snapshot listeners instead of HTTP polling.
- **Persistent messages.** Messages are stored in Firestore and persist across server restarts.
- **Real course data.** Courses are loaded from a CSV import script into Firestore.

## Repository Structure

```
ECS-191/
├── proposal.md
├── overview.md              # This file
├── server_architecture.md
├── client_architecture.md
├── api.md
├── add_class.md
├── class_groupchat.md
├── authentication.md
├── realtime_chat.md
├── server/
│   ├── main.py              # Flask app factory, registers blueprints
│   ├── requirements.txt
│   ├── api/
│   │   ├── classes.py       # Class listing endpoints
│   │   ├── users.py         # User registration & enrollment endpoints
│   │   └── chat.py          # Messaging endpoints
│   ├── services/
│   │   ├── datastore_service.py  # All Firestore CRUD operations
│   │   └── auth_service.py       # Firebase token verification
│   └── tests/
│       ├── conftest.py      # Pytest fixtures with mocked Firestore
│       ├── test_auth.py
│       └── test_chat.py
└── ios/
    └── CourseHub/
        ├── Models/
        ├── ViewModels/
        ├── Views/
        └── Networking/
```

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Auth | Firebase Authentication | Email/password auth with secure token verification; easy to add social login later |
| DB package | `firebase-admin` (Firestore) | Service functions return plain dicts; easy to swap DB later |
| Chat membership | Derived from enrollment records | No separate GroupChat entity needed; enrollment = membership |
| Chat transport | Firestore snapshot listeners | Real-time updates without polling; server-mediated writes for access control |
| Search | Client-side filtering | Fetch all classes once, filter locally |
| Service layer | Returns plain dicts | Decouples business logic from DB implementation; enables easy DB swap |

## Firestore Data Model

| Collection | Key Fields | Purpose |
|-----------|-----------|---------|
| `courses/{doc_id}` | code, name, lecture_times, discussion_times | Course catalog |
| `users/{uid}` | uid, email, display_name | Student profile (doc ID = Firebase UID) |
| `users/{uid}/enrollments/{doc_id}` | class_id, enrolled_at | Enrollment (also defines chat membership) |
| `classes/{class_id}/messages/{doc_id}` | sender_id, sender_name, content, timestamp | Chat messages |

## Related Documentation

- [Server Architecture](server_architecture.md) -- Backend structure, modules, and DB abstraction
- [Client Architecture](client_architecture.md) -- iOS app structure, MVVM pattern, networking
- [API Reference](api.md) -- Complete REST API specification with request/response examples
- [Add Class Feature](add_class.md) -- Feature spec, wireframes, user stories, test cases
- [Class Groupchat Feature](class_groupchat.md) -- Feature spec, wireframes, user stories, test cases
- [Authentication](authentication.md) -- Firebase auth implementation, login/signup flow, token verification

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
| **Server** | Google App Engine (Standard Environment), Python 3.12, Flask with Blueprints |
| **Database** | Firestore in Datastore Mode (`google-cloud-datastore` package) |
| **Authentication** | Firebase Authentication (Email/Password) |
| **Deployment** | Google App Engine (Standard), gunicorn |

## Milestone 0 Scope

Milestone 0 delivers two core features:

1. **Add Class** -- User searches and selects a class from hardcoded seed data (~13 UC Davis CS classes) and adds it to their schedule.
2. **Class Groupchat** -- When a user adds a class, they are automatically added to a group chat with all other users enrolled in that class.

### Simplifications for M0

- **No WebSockets.** Chat uses HTTP polling every 5 seconds.
- **No separate GroupChat entity.** Chat membership is derived from class enrollment.
- **Hardcoded seed data.** Classes are loaded from a Python list, not a real course catalog API.
- **Client-side search.** The client fetches all classes once and filters locally (dataset is small).

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
├── server/
│   ├── main.py              # Flask app factory, registers blueprints
│   ├── models.py            # Entity kind constants + helper functions
│   ├── seed_data.py         # Hardcoded class list + seed function
│   ├── app.yaml             # GAE config (Python 3.12 runtime)
│   ├── requirements.txt
│   ├── test_api.py          # API integration tests
│   ├── conftest.py          # Pytest fixtures
│   ├── api/
│   │   ├── __init__.py
│   │   ├── classes.py       # Class listing + enrollment endpoints
│   │   └── chat.py          # Messaging endpoints
│   └── services/
│       ├── __init__.py
│       └── datastore_service.py  # All Datastore CRUD operations
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
| DB package | `google-cloud-datastore` | Entities are plain dicts (not ORM objects); easy to swap DB later |
| Chat membership | Derived from `UserClass` enrollment | No separate GroupChat entity needed; enrollment = membership |
| Chat transport | HTTP polling (5s interval) | Simple implementation for M0; no WebSocket complexity |
| Search | Client-side filtering | Only ~13 classes; fetch all once, filter locally |
| Service layer | Returns plain dicts | Decouples business logic from DB implementation; enables easy DB swap |

## Data Models (High Level)

| Entity | Key Fields | Purpose |
|--------|-----------|---------|
| **Class** | class_code, class_name, quarter | Course catalog (seed data) |
| **User** | id, name, email/phone | Student profile |
| **UserClass** | user_id, class_id | Enrollment join (also defines chat membership) |
| **Message** | chat_id, user_id, content, timestamp | Chat messages (chat_id = class_id) |

## Related Documentation

- [Server Architecture](server_architecture.md) -- Backend structure, modules, and DB abstraction
- [Client Architecture](client_architecture.md) -- iOS app structure, MVVM pattern, networking
- [API Reference](api.md) -- Complete REST API specification with request/response examples
- [Add Class Feature](add_class.md) -- Feature spec, wireframes, user stories, test cases
- [Class Groupchat Feature](class_groupchat.md) -- Feature spec, wireframes, user stories, test cases
- [Authentication](authentication.md) -- Firebase auth implementation, login/signup flow, token verification

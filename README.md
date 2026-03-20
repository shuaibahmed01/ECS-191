# CourseHub

A mobile app for UC Davis students to manage their class schedules, communicate with classmates, and study smarter with AI-powered tools.

## Features

- **Schedule Management** — Browse and search UC Davis courses, add them to your schedule, or create custom classes not in the catalog
- **Class Group Chat** — Real-time messaging per class with image and PDF attachment support
- **AI Syllabus Extraction** — Upload a syllabus (PDF or photo) and AI extracts instructor info, grading policies, important dates, and course policies
- **Lecture Slides & Flashcards** — Upload slides for AI-generated summaries, then auto-generate interactive study flashcards
- **Practice Exams** — AI-generated exams from your lecture slides (multiple choice, short answer, or mixed) with automated grading, feedback, and score tracking
- **Course Agent** — Chat with an AI assistant that answers questions about your classes using your syllabus and slides as context
- **Reminders & Important Dates** — Dates extracted from syllabi appear in a unified calendar view with push notification reminders and custom reminder creation
- **Global Search** — Search across all enrolled classes' syllabus content and chat messages from one search bar

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | SwiftUI (iOS 17+) |
| Backend | Flask (Python 3.12) on Google App Engine |
| Auth | Firebase Authentication |
| Database | Firestore |
| Storage | Firebase Storage |
| Real-Time Chat | Firestore snapshot listeners |
| AI | Anthropic Claude API (claude-sonnet-4-20250514) |

## Getting Started

### Prerequisites

- Python 3.12+
- Xcode 15+
- iOS 17+ Simulator or device
- Access to the team's Firebase project

### 1. Firebase Setup

**iOS:** Download `GoogleService-Info.plist` from [Firebase Console](https://console.firebase.google.com/) → Project Settings → iOS app, and add it to `ios/CourseHub/CourseHub/` in Xcode.

**Backend:** Generate a service account key from Firebase Console → Service accounts, and save it as `server/firebase-credentials.json`.

### 2. Environment Variables

```bash
cp server/.env.example server/.env
```

Fill in:
```
ANTHROPIC_API_KEY=your-anthropic-api-key
GOOGLE_CLOUD_PROJECT=coursehub-c99c6
GOOGLE_APPLICATION_CREDENTIALS=firebase-credentials.json
```

### 3. Run the Server

```bash
cd server
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python main.py
```

Server runs on `http://localhost:5001`.

### 4. Run the iOS App

```bash
open ios/CourseHub/CourseHub.xcodeproj
```

Select an iOS Simulator and hit `Cmd + R`.

## Project Structure

```
server/
├── api/            # REST endpoints (classes, users, chat, syllabus, search, uploads)
├── services/       # Business logic (Firestore data layer, auth, Anthropic API)
├── main.py         # Flask app with global error handlers
└── requirements.txt

ios/CourseHub/CourseHub/
├── Models/         # Data models
├── ViewModels/     # Business logic & state management
├── Views/          # SwiftUI views
├── Networking/     # API client
└── Services/       # Push notification service
```

## Troubleshooting

- **"No such module 'FirebaseAuth'"** — Xcode → File → Packages → Resolve Package Versions, then clean build (`Cmd + Shift + K`)
- **"FirebaseApp not configured" crash** — Ensure `GoogleService-Info.plist` is added to the Xcode project target, not just the folder
- **Server returns 401** — Check that `firebase-credentials.json` exists in `server/`
- **Need Firebase access?** — Ask a team member: Firebase Console → Project Settings → Users and permissions

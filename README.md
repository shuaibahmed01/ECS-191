# CourseHub

A mobile app for UC Davis students to manage their class schedules and communicate with classmates. Students can browse courses, add them to their schedule, chat with others in each class, and study smarter with AI-powered tools.

## Features

- **Authentication**: Sign up and sign in with email/password
- **Browse Classes**: View all available UC Davis CS courses for the current quarter
- **Search**: Filter classes by course code or name
- **Add to Schedule**: Enroll in classes with a single tap
- **My Schedule**: View all enrolled classes in one place
- **Class Group Chat**: Chat with classmates in each enrolled class, with support for image and PDF attachments
- **Remove Classes**: Swipe to remove classes from your schedule
- **Syllabus Upload**: Upload a PDF or photo of your syllabus; AI extracts instructor, grading, dates, and policies
- **Syllabus Editing**: Edit extracted syllabus fields (instructor, office hours, grading policy, dates, policies) after upload
- **Lecture Slides**: Upload lecture slides (PDF or photo); AI summarizes key concepts, definitions, formulas, and examples
- **Flashcard Generation**: Auto-generate study flashcards from lecture slide summaries with an interactive flip-and-swipe study interface
- **Course Agent**: Chat with an AI assistant that answers questions using your syllabus and lecture slides as context, with citation support
- **Practice Exams**: AI-generated practice exams from lecture slides with multiple choice, short answer, or mixed (70/30 MC/SA) question types; automated grading with per-question feedback, score tracking, result persistence, and retake support
- **Global Search**: Search across all enrolled classes — syllabus content and chat messages — from a single search bar
- **File Attachments**: Upload images and PDFs in chat via Firebase Storage with signed URLs

## Tech Stack

- **Frontend**: SwiftUI (iOS 17+)
- **Backend**: Flask (Python 3.12)
- **Authentication**: Firebase Authentication
- **Database**: Firestore (courses, users, enrollments, chat messages, slides, and flashcards)
- **Storage**: Firebase Storage (chat attachments, slide uploads)
- **Real-Time Chat**: Firestore snapshot listeners (iOS reads directly from Firestore)
- **AI**: Anthropic Claude API — claude-sonnet-4-20250514 (syllabus extraction, slide summarization, flashcard generation, practice exam generation/grading, and course agent)

## Getting Started

### Prerequisites

- Python 3.12+
- Xcode 15+
- iOS Simulator or device running iOS 17+
- Access to the team's Firebase project

### Step 1: Firebase Setup (First-time only)

#### iOS Config

1. Go to [Firebase Console](https://console.firebase.google.com/) and select the **CourseHub** project
2. Go to Project Settings → Your apps → iOS app
3. Download `GoogleService-Info.plist`
4. Place it in `ios/CourseHub/CourseHub/`
5. In Xcode, add the file to the project:
   - Right-click the `CourseHub` folder → "Add Files to CourseHub"
   - Select `GoogleService-Info.plist`
   - Ensure "Add to targets: CourseHub" is checked

#### Backend Credentials

1. Go to Firebase Console → Project Settings → Service accounts
2. Click "Generate new private key"
3. Save as `server/firebase-credentials.json`

**Note:** Never commit credential files to git.

### Step 2: Configure Environment Variables

Create a `.env` file in the `server/` directory:

```bash
cp server/.env.example server/.env
```

Then fill in the values:

```
ANTHROPIC_API_KEY=your-anthropic-api-key
GOOGLE_CLOUD_PROJECT=coursehub-c99c6
GOOGLE_APPLICATION_CREDENTIALS=firebase-credentials.json
```

- **ANTHROPIC_API_KEY**: Get one from [Anthropic Console](https://console.anthropic.com/) — required for syllabus extraction and course agent
- **GOOGLE_CLOUD_PROJECT**: Your Firebase project ID
- **GOOGLE_APPLICATION_CREDENTIALS**: Path to the Firebase service account key

### Step 3: Start the Server

```bash
cd server
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python main.py
```

The server runs on `http://localhost:5001`

### Step 4: Run the iOS App

```bash
open ios/CourseHub/CourseHub.xcodeproj
```

1. Select an iOS Simulator (iPhone 15 Pro recommended)
2. Build and run (`Cmd + R`)

## API Endpoints

### Public (No Auth Required)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/classes` | List all classes |
| GET | `/v1/classes?q=<query>` | Search classes |
| GET | `/v1/classes/<id>` | Get single class |

### Protected (Requires Firebase Token)

All protected endpoints require header: `Authorization: Bearer <firebase_id_token>`

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/users` | Register new user |
| GET | `/v1/users/me/classes` | List enrolled classes |
| POST | `/v1/users/me/classes` | Enroll in class |
| DELETE | `/v1/users/me/classes/<enrollment_id>` | Unenroll from class |
| GET | `/v1/classes/<id>/messages` | Get chat messages |
| POST | `/v1/classes/<id>/messages` | Send chat message |
| POST | `/v1/classes/<id>/syllabus` | Upload & process syllabus |
| GET | `/v1/classes/<id>/syllabus` | Get extracted syllabus context |
| PUT | `/v1/classes/<id>/syllabus` | Update syllabus fields |
| POST | `/v1/classes/<id>/slides` | Upload & process lecture slides |
| GET | `/v1/classes/<id>/slides` | List slide summaries |
| DELETE | `/v1/classes/<id>/slides/<slide_id>` | Delete a slide entry |
| POST | `/v1/classes/<id>/slides/<slide_id>/flashcards` | Generate flashcards from slide |
| GET | `/v1/classes/<id>/slides/<slide_id>/flashcards` | Get generated flashcards |
| POST | `/v1/classes/<id>/practice-exams` | Generate practice exam from slides |
| GET | `/v1/classes/<id>/practice-exams` | List practice exams |
| GET | `/v1/classes/<id>/practice-exams/<eid>` | Get exam with questions |
| POST | `/v1/classes/<id>/practice-exams/<eid>/submit` | Submit answers for grading |
| GET | `/v1/classes/<id>/practice-exams/<eid>/attempts` | List user's past attempts |
| POST | `/v1/classes/<id>/agent/chat` | Send message to course agent |
| GET | `/v1/classes/<id>/agent/history` | Get agent chat history |
| POST | `/v1/uploads` | Upload file to Firebase Storage |
| GET | `/v1/search?q=<query>&types=<types>` | Search across enrolled classes |

## Project Structure

```
├── server/
│   ├── api/
│   │   ├── classes.py          # Class listing endpoints
│   │   ├── users.py            # User & enrollment endpoints
│   │   ├── chat.py             # Chat endpoints
│   │   ├── syllabus.py         # Syllabus, slides, flashcards, practice exams & agent endpoints
│   │   ├── uploads.py          # File upload to Firebase Storage
│   │   └── search.py           # Global search across classes
│   ├── services/
│   │   ├── datastore_service.py  # Data layer
│   │   ├── auth_service.py       # Firebase token verification
│   │   └── syllabus_service.py   # Anthropic API, syllabus, slides, flashcards & practice exams
│   ├── main.py
│   ├── .env                     # Environment variables (not committed)
│   ├── tests/                   # Pytest test suite
│   └── requirements.txt
│
└── ios/CourseHub/
    └── CourseHub/
        ├── Models/             # Data models (incl. SlideEntry, Flashcard, PracticeExam)
        ├── ViewModels/         # Business logic (incl. SlidesViewModel, PracticeExamViewModel)
        ├── Views/              # SwiftUI views (incl. SlidesView, FlashcardStudyView, PracticeExamsView)
        └── Networking/         # API client
```

## Troubleshooting

### "No such module 'FirebaseAuth'"
- Xcode: File → Packages → Resolve Package Versions
- Clean build: `Cmd + Shift + K`, then `Cmd + R`

### "FirebaseApp not configured" crash
- Ensure `GoogleService-Info.plist` is added to the Xcode project (not just the folder)

### Server returns 401 Unauthorized
- Ensure `firebase-credentials.json` exists in `server/`
- Ensure you ran the `export` command before starting the server

### Need Firebase Access?
Ask a team member to add you: Firebase Console → Project Settings → Users and permissions

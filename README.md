# CourseHub

A mobile app for UC Davis students to manage their class schedules and communicate with classmates. Students can browse courses, add them to their schedule, and chat with others in each class.

## Features 

- **Authentication**: Sign up and sign in with email/password
- **Browse Classes**: View all available UC Davis CS courses for the current quarter
- **Search**: Filter classes by course code or name
- **Add to Schedule**: Enroll in classes with a single tap
- **My Schedule**: View all enrolled classes in one place
- **Class Group Chat**: Chat with classmates in each enrolled class
- **Remove Classes**: Swipe to remove classes from your schedule
- **Syllabus Upload**: Upload a PDF or photo of your syllabus; AI extracts instructor, grading, dates, and policies
- **Course Agent**: Chat with an AI assistant that answers questions using your syllabus as context

## Tech Stack

- **Frontend**: SwiftUI (iOS 17+)
- **Backend**: Flask (Python 3.12)
- **Authentication**: Firebase Authentication
- **Database**: Firestore (courses, users, enrollments, and chat messages)
- **Real-Time Chat**: Firestore snapshot listeners (iOS reads directly from Firestore)
- **AI**: Anthropic Claude API (syllabus extraction and course agent)

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
| POST | `/v1/classes/<id>/agent/chat` | Send message to course agent |
| GET | `/v1/classes/<id>/agent/history` | Get agent chat history |

## Project Structure

```
├── server/
│   ├── api/
│   │   ├── classes.py          # Class listing endpoints
│   │   ├── users.py            # User & enrollment endpoints
│   │   ├── chat.py             # Chat endpoints
│   │   └── syllabus.py         # Syllabus & course agent endpoints
│   ├── services/
│   │   ├── datastore_service.py  # Data layer
│   │   ├── auth_service.py       # Firebase token verification
│   │   └── syllabus_service.py   # Anthropic API & syllabus Firestore CRUD
│   ├── main.py
│   ├── .env                     # Environment variables (not committed)
│   ├── tests/                   # Pytest test suite
│   └── requirements.txt
│
└── ios/CourseHub/
    └── CourseHub/
        ├── Models/             # Data models
        ├── ViewModels/         # Business logic (incl. AuthViewModel)
        ├── Views/              # SwiftUI views (incl. LoginView)
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

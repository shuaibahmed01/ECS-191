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

## Tech Stack

- **Frontend**: SwiftUI (iOS 17+)
- **Backend**: Flask (Python 3.12)
- **Authentication**: Firebase Authentication
- **Data**: In-memory storage (Milestone 0)

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

### Step 2: Start the Server

```bash
cd server
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
export GOOGLE_APPLICATION_CREDENTIALS="firebase-credentials.json"
python main.py
```

The server runs on `http://localhost:5001`

### Step 3: Run the iOS App

```bash
open ios/CourseHub/CourseHub.xcodeproj
```

1. Select an iOS Simulator (iPhone 15 Pro recommended)
2. Build and run (`Cmd + R`)

## API Endpoints

### Public (No Auth Required)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/seed` | Seed database with courses |
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

## Project Structure

```
├── server/
│   ├── api/
│   │   ├── classes.py          # Class listing endpoints
│   │   ├── users.py            # User & enrollment endpoints
│   │   └── chat.py             # Chat endpoints
│   ├── services/
│   │   ├── datastore_service.py  # Data layer
│   │   └── auth_service.py       # Firebase token verification
│   ├── main.py
│   ├── seed_data.py
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

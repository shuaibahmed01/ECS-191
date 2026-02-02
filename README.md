# CourseHub

A mobile app for UC Davis students to manage their class schedules. Students can browse available courses, add them to their personal schedule, and remove them as needed.

## Features

- **Browse Classes**: View all available UC Davis CS courses for the current quarter
- **Search**: Filter classes by course code or name
- **Add to Schedule**: Enroll in classes with a single tap
- **My Schedule**: View all enrolled classes in one place
- **Remove Classes**: Swipe to remove classes from your schedule

## Tech Stack

- **Backend**: Flask (Python)
- **Frontend**: SwiftUI (iOS 17+)
- **Data**: In-memory storage (Milestone 0)

## Getting Started

### Prerequisites

- Python 3.12+
- Xcode 15+
- iOS Simulator or device running iOS 17+

### Start the Server

1. Navigate to the server directory:
   ```bash
   cd server
   ```

2. Create and activate a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Run the server:
   ```bash
   python main.py
   ```

   The server will start on `http://localhost:5001`

### Run the iOS App

1. Open the Xcode project:
   ```bash
   open ios/CourseHub/CourseHub.xcodeproj
   ```

2. Select an iOS Simulator (iPhone 15 Pro recommended)

3. Build and run (Cmd+R)

The app will automatically seed the database with 13 UC Davis CS courses on launch.

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/seed` | Seed database with courses |
| GET | `/v1/classes` | List all classes |
| GET | `/v1/classes?q=<query>` | Search classes |
| GET | `/v1/classes/<id>` | Get single class |
| POST | `/v1/users/<user_id>/classes` | Enroll in class |
| GET | `/v1/users/<user_id>/classes` | List enrolled classes |
| DELETE | `/v1/users/<user_id>/classes/<enrollment_id>` | Unenroll |

## Project Structure

```
├── server/
│   ├── api/
│   │   ├── classes.py      # Class endpoints
│   │   └── chat.py         # Chat stub (future)
│   ├── services/
│   │   └── datastore_service.py  # Data layer
│   ├── main.py             # Flask app
│   ├── models.py           # Model constants
│   ├── seed_data.py        # Course data
│   └── requirements.txt
│
└── ios/CourseHub/
    └── CourseHub/
        ├── Models/         # Data models
        ├── ViewModels/     # Business logic
        ├── Views/          # SwiftUI views
        └── Networking/     # API client
```

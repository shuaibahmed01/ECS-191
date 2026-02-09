# Feature Spec: Authentication

## Overview

The Authentication feature provides secure user registration and login using Firebase Authentication. Users must sign in with their email and password to access the app. The backend verifies Firebase ID tokens on protected endpoints.

## User Stories

1. **As a new user**, I want to create an account with my email and password so that I can access the app.
2. **As a returning user**, I want to sign in with my credentials so that I can access my schedule and chats.
3. **As a user**, I want to stay signed in between app launches so that I don't have to log in every time.
4. **As a user**, I want to sign out so that I can switch accounts or secure my session.
5. **As a user**, I want to reset my password if I forget it so that I can regain access to my account.

## Authentication Flow

### Sign Up

```
┌──────────┐                    ┌──────────┐                    ┌──────────┐
│  Client  │                    │ Firebase │                    │  Server  │
└────┬─────┘                    └────┬─────┘                    └────┬─────┘
     │                               │                               │
     │  1. User enters email,        │                               │
     │     password, display name    │                               │
     │                               │                               │
     │  createUser(email, password)  │                               │
     │──────────────────────────────>│                               │
     │       User created + token    │                               │
     │<──────────────────────────────│                               │
     │                               │                               │
     │  updateProfile(displayName)   │                               │
     │──────────────────────────────>│                               │
     │              OK               │                               │
     │<──────────────────────────────│                               │
     │                               │                               │
     │  POST /v1/users               │                               │
     │  Authorization: Bearer <token>│                               │
     │  {uid, email, display_name}   │                               │
     │───────────────────────────────────────────────────────────────>
     │                               │              User stored in DB │
     │               201 Created     │                               │
     │<───────────────────────────────────────────────────────────────
     │                               │                               │
     │  Navigate to main app         │                               │
     │                               │                               │
```

### Sign In

```
┌──────────┐                    ┌──────────┐
│  Client  │                    │ Firebase │
└────┬─────┘                    └────┬─────┘
     │                               │
     │  signIn(email, password)      │
     │──────────────────────────────>│
     │       User + ID token         │
     │<──────────────────────────────│
     │                               │
     │  Auth state listener fires    │
     │  isAuthenticated = true       │
     │                               │
     │  Navigate to main app         │
     │                               │
```

### API Request with Authentication

```
┌──────────┐                    ┌──────────┐                    ┌──────────┐
│  Client  │                    │  Server  │                    │ Firebase │
└────┬─────┘                    └────┬─────┘                    └────┬─────┘
     │                               │                               │
     │  getIDToken()                 │                               │
     │───────────────────────────────────────────────────────────────>
     │       ID token                │                               │
     │<───────────────────────────────────────────────────────────────
     │                               │                               │
     │  GET /v1/users/me/classes     │                               │
     │  Authorization: Bearer <token>│                               │
     │──────────────────────────────>│                               │
     │                               │  verify_id_token(token)       │
     │                               │──────────────────────────────>│
     │                               │       Decoded token (uid)     │
     │                               │<──────────────────────────────│
     │                               │                               │
     │       {classes: [...]}        │                               │
     │<──────────────────────────────│                               │
     │                               │                               │
```

## UI Wireframes

### Login View

```
┌─────────────────────────────┐
│                             │
│         [Book Icon]         │
│                             │
│         CourseHub           │
│    Sign in to continue      │
│                             │
│  ┌───────────────────────┐  │
│  │ Email                 │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │ Password              │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │      Sign In          │  │
│  └───────────────────────┘  │
│                             │
│     Forgot Password?        │
│                             │
│                             │
│  Don't have an account?     │
│         Sign Up             │
│                             │
└─────────────────────────────┘
```

### Sign Up View

```
┌─────────────────────────────┐
│                             │
│         [Book Icon]         │
│                             │
│         CourseHub           │
│    Create your account      │
│                             │
│  ┌───────────────────────┐  │
│  │ Display Name          │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │ Email                 │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │ Password              │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │      Sign Up          │  │
│  └───────────────────────┘  │
│                             │
│  Already have an account?   │
│         Sign In             │
│                             │
└─────────────────────────────┘
```

### Profile View (with Sign Out)

```
┌─────────────────────────────┐
│  Profile                    │
├─────────────────────────────┤
│                             │
│  [Avatar]  John Doe         │
│            john@email.com   │
│                             │
├─────────────────────────────┤
│                             │
│  [Sign Out]                 │
│                             │
└─────────────────────────────┘
```

## Data Models

### User (Backend)

| Field | Type | Description |
|-------|------|-------------|
| `uid` | string | Firebase UID (primary key) |
| `email` | string | User's email address |
| `display_name` | string | User's display name (shown in chat) |

### Firebase User (Client)

The Firebase SDK provides a `User` object with:
- `uid`: Unique identifier
- `email`: Email address
- `displayName`: Display name
- `getIDToken()`: Method to get the ID token for API calls

## API Endpoints

### User Registration

```
POST /v1/users
Authorization: Bearer <firebase_id_token>

Request:
{
    "uid": "firebase_uid",
    "email": "user@example.com",
    "display_name": "John Doe"
}

Response: 201 Created
{
    "uid": "firebase_uid",
    "email": "user@example.com",
    "display_name": "John Doe"
}
```

### Protected Endpoints

All endpoints that require authentication expect:
```
Authorization: Bearer <firebase_id_token>
```

Protected endpoints:
- `GET /v1/users/me/classes` - Get enrolled classes
- `POST /v1/users/me/classes` - Enroll in a class
- `DELETE /v1/users/me/classes/:id` - Unenroll from a class
- `GET /v1/classes/:id/messages` - Get chat messages
- `POST /v1/classes/:id/messages` - Send a message

Public endpoints (no auth required):
- `GET /v1/classes` - List all classes
- `GET /v1/classes/:id` - Get a single class

## Implementation Details

### iOS Client

| File | Purpose |
|------|---------|
| `AuthViewModel.swift` | Manages auth state, sign in/up/out methods |
| `LoginView.swift` | Login and sign up UI |
| `MainTabView.swift` | Tab navigation with Profile tab |
| `ProfileView.swift` | Shows user info and sign out button |
| `APIClient.swift` | Adds Bearer token to authenticated requests |
| `CourseHubApp.swift` | Shows LoginView or MainTabView based on auth state |

### Backend

| File | Purpose |
|------|---------|
| `services/auth_service.py` | Firebase token verification, `@require_auth` decorator |
| `api/users.py` | User registration and `/users/me/*` endpoints |
| `api/chat.py` | Updated to require auth and check enrollment |

## Error Handling

| Error | HTTP Status | Description |
|-------|-------------|-------------|
| Missing token | 401 | No Authorization header |
| Invalid token | 401 | Token expired or malformed |
| UID mismatch | 403 | Token UID doesn't match request UID |
| Not enrolled | 403 | User trying to access chat they're not enrolled in |

## Security Considerations

1. **Token Verification**: All protected endpoints verify the Firebase ID token server-side
2. **UID Validation**: User registration verifies the request UID matches the token UID
3. **Enrollment Check**: Chat endpoints verify the user is enrolled in the class
4. **HTTPS**: In production, all traffic should use HTTPS
5. **Token Refresh**: Firebase tokens expire after 1 hour; the SDK handles refresh automatically

## Test Cases

### Authentication Tests

| # | Test Case | Expected |
|---|-----------|----------|
| 1 | Sign up with valid email/password | Account created, user signed in |
| 2 | Sign up with existing email | Error: email already in use |
| 3 | Sign up with weak password | Error: password too weak |
| 4 | Sign in with valid credentials | User signed in |
| 5 | Sign in with wrong password | Error: invalid credentials |
| 6 | Sign in with non-existent email | Error: user not found |
| 7 | Sign out | User signed out, redirected to login |
| 8 | Password reset request | Reset email sent |
| 9 | Session persistence | User stays signed in after app restart |

### API Authentication Tests

| # | Test Case | Expected |
|---|-----------|----------|
| 10 | Request without token | 401 Unauthorized |
| 11 | Request with invalid token | 401 Unauthorized |
| 12 | Request with valid token | Success |
| 13 | Access chat without enrollment | 403 Forbidden |
| 14 | Access chat with enrollment | Success |

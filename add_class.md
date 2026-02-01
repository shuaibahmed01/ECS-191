# Feature Spec: Add Class

## Overview

The "Add Class" feature allows users to browse a catalog of UC Davis classes, search by class code or name, and add classes to their personal schedule. Adding a class creates an enrollment record (`UserClass`) that also serves as group chat membership for the [Class Groupchat](class_groupchat.md) feature.

## User Stories

1. **As a student**, I want to browse all available classes so that I can find classes to add to my schedule.
2. **As a student**, I want to search for classes by code or name so that I can quickly find a specific class.
3. **As a student**, I want to add a class to my schedule so that I can keep track of my enrolled classes.
4. **As a student**, I want to see a confirmation when I successfully add a class so that I know it was added.
5. **As a student**, I want to view my schedule of enrolled classes so that I can see everything in one place.
6. **As a student**, I want to remove a class from my schedule so that I can correct mistakes or drop classes.

## UI Wireframes

### ClassListView (Browse Classes Tab)

```
┌─────────────────────────────┐
│  Browse Classes             │
├─────────────────────────────┤
│  ┌─────────────────────────┐│
│  │ 🔍 Search classes...    ││
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │ ECS 032A                ││
│  │ Introduction to         ││
│  │ Programming       [Add] ││
│  ├─────────────────────────┤│
│  │ ECS 032B                ││
│  │ Intro to Data           ││
│  │ Structures        [Add] ││
│  ├─────────────────────────┤│
│  │ ECS 036A                ││
│  │ Programming &           ││
│  │ Problem Solving   [Add] ││
│  ├─────────────────────────┤│
│  │ ECS 036B                ││
│  │ Software Dev &          ││
│  │ OOP              [Add] ││
│  ├─────────────────────────┤│
│  │ ECS 191                 ││
│  │ Software Design         ││
│  │ Project           [Add] ││
│  └─────────────────────────┘│
│                             │
│  [Browse]    [My Schedule]  │
└─────────────────────────────┘
```

### MyScheduleView (My Schedule Tab)

```
┌─────────────────────────────┐
│  My Schedule                │
├─────────────────────────────┤
│                             │
│  ┌─────────────────────────┐│
│  │ ECS 191            >    ││
│  │ Software Design Project ││
│  │         ← swipe: Remove ││
│  ├─────────────────────────┤│
│  │ ECS 170            >    ││
│  │ Intro to AI             ││
│  │         ← swipe: Remove ││
│  └─────────────────────────┘│
│                             │
│  Tap a class to open its   │
│  group chat.               │
│                             │
│  [Browse]    [My Schedule]  │
└─────────────────────────────┘
```

### Empty Schedule State

```
┌─────────────────────────────┐
│  My Schedule                │
├─────────────────────────────┤
│                             │
│                             │
│     No classes yet.         │
│     Browse classes to add   │
│     some to your schedule.  │
│                             │
│                             │
│  [Browse]    [My Schedule]  │
└─────────────────────────────┘
```

## Client-Server Sequence Diagram

### Adding a Class

```
┌──────────┐                    ┌──────────┐                    ┌───────────┐
│  Client  │                    │  Server  │                    │ Datastore │
└────┬─────┘                    └────┬─────┘                    └─────┬─────┘
     │                               │                                │
     │  GET /v1/classes              │                                │
     │──────────────────────────────>│                                │
     │                               │  Query(Kind=Class)            │
     │                               │───────────────────────────────>│
     │                               │             [class entities]  │
     │                               │<───────────────────────────────│
     │         {classes: [...]}      │                                │
     │<──────────────────────────────│                                │
     │                               │                                │
     │  (User searches locally)      │                                │
     │                               │                                │
     │  (User taps "Add" on ECS 191) │                                │
     │                               │                                │
     │  POST /v1/users/1/classes     │                                │
     │  {class_id: 123}             │                                │
     │──────────────────────────────>│                                │
     │                               │  Query(UserClass,              │
     │                               │    user_id=1, class_id=123)   │
     │                               │───────────────────────────────>│
     │                               │              [empty = no dup] │
     │                               │<───────────────────────────────│
     │                               │  Put(UserClass entity)        │
     │                               │───────────────────────────────>│
     │                               │                     [stored]  │
     │                               │<───────────────────────────────│
     │     201 {id, user_id,         │                                │
     │          class_id}            │                                │
     │<──────────────────────────────│                                │
     │                               │                                │
     │  (Show success confirmation)  │                                │
     │                               │                                │
```

### Removing a Class

```
┌──────────┐                    ┌──────────┐                    ┌───────────┐
│  Client  │                    │  Server  │                    │ Datastore │
└────┬─────┘                    └────┬─────┘                    └─────┬─────┘
     │                               │                                │
     │  DELETE /v1/users/1/          │                                │
     │    classes/456                │                                │
     │──────────────────────────────>│                                │
     │                               │  Get(UserClass, id=456)       │
     │                               │───────────────────────────────>│
     │                               │           [enrollment entity] │
     │                               │<───────────────────────────────│
     │                               │  Delete(UserClass, id=456)    │
     │                               │───────────────────────────────>│
     │                               │                    [deleted]  │
     │                               │<───────────────────────────────│
     │            204 No Content     │                                │
     │<──────────────────────────────│                                │
     │                               │                                │
     │  (Remove from local list)     │                                │
     │                               │                                │
```

## Data Models

| Entity | Field | Type | Description |
|--------|-------|------|-------------|
| **Class** | `id` | int (auto) | Datastore key ID |
| | `class_code` | string | e.g., "ECS 191" |
| | `class_name` | string | e.g., "Software Design Project" |
| | `quarter` | string | e.g., "W26" |
| **UserClass** | `id` | int (auto) | Datastore key ID (= enrollment_id) |
| | `user_id` | int | Reference to User |
| | `class_id` | int | Reference to Class |
| **User** | `id` | int (auto) | Datastore key ID |
| | `name` | string | Display name |
| | `email` | string | Email address |

## API Endpoints Used

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/v1/classes` | Fetch all classes (optional `?q=` filter) |
| `GET` | `/v1/classes/:class_id` | Get single class details |
| `POST` | `/v1/users/:user_id/classes` | Enroll in a class |
| `GET` | `/v1/users/:user_id/classes` | Get user's enrolled classes |
| `DELETE` | `/v1/users/:user_id/classes/:enrollment_id` | Unenroll from a class |

See [API Reference](api.md) for full request/response details.

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| **Duplicate enrollment** | Server returns `409 Conflict` with `{"error": "Already enrolled"}`. Client shows an alert. |
| **Invalid class ID** | Server returns `404 Not Found` with `{"error": "Class not found"}`. Client shows an error message. |
| **Empty catalog** | `GET /v1/classes` returns `{"classes": []}`. Client shows "No classes available" placeholder. |
| **Network failure** | Client shows an error message ("Failed to load classes" or "Failed to add class"). Retry on pull-to-refresh. |
| **Search with no results** | Client-side filter returns empty array. Show "No classes match your search" placeholder. |
| **Remove class from schedule** | Swipe-to-delete triggers `DELETE` endpoint. Class disappears from the schedule list. User loses access to the class group chat. |
| **Rapid double-tap on Add** | Client should disable the Add button while the request is in flight to prevent duplicate requests. |

## Test Cases

### API Tests

| # | Test Case | Method | Endpoint | Expected |
|---|-----------|--------|----------|----------|
| 1 | List all classes | GET | `/v1/classes` | `200`, returns array of all seed classes |
| 2 | Search classes by code | GET | `/v1/classes?q=ECS 191` | `200`, returns only matching classes |
| 3 | Search classes by name | GET | `/v1/classes?q=Software` | `200`, returns classes with "Software" in name |
| 4 | Search with no match | GET | `/v1/classes?q=NONEXISTENT` | `200`, returns empty array |
| 5 | Get single class | GET | `/v1/classes/:id` | `200`, returns class object |
| 6 | Get non-existent class | GET | `/v1/classes/99999` | `404`, error message |
| 7 | Enroll in class | POST | `/v1/users/:uid/classes` | `201`, returns enrollment object |
| 8 | Duplicate enrollment | POST | `/v1/users/:uid/classes` | `409`, error "Already enrolled" |
| 9 | List user's classes | GET | `/v1/users/:uid/classes` | `200`, returns enrolled classes with enrollment_id |
| 10 | Unenroll from class | DELETE | `/v1/users/:uid/classes/:eid` | `204`, empty body |
| 11 | Unenroll non-existent | DELETE | `/v1/users/:uid/classes/99999` | `404`, error message |

### UI Tests

| # | Test Case | Expected |
|---|-----------|----------|
| 12 | Browse tab shows class list | All seed classes displayed with code and name |
| 13 | Search bar filters classes | Typing "191" shows only ECS 191 |
| 14 | Tap "Add" button | Class added; success feedback shown |
| 15 | Schedule tab shows enrolled classes | All enrolled classes displayed |
| 16 | Swipe to remove class | Class removed from schedule |

### Unit Tests

| # | Test Case | Expected |
|---|-----------|----------|
| 17 | ClassListViewModel.filteredClasses | Returns only classes matching searchText |

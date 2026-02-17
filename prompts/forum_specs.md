# CourseHub Forum + Groupchat Architecture Spec

This document describes how forum posts and groupchat should be implemented
based on the CURRENT Firestore database structure.

IMPORTANT:
The database already exists and must NOT be refactored from scratch.

We have two collections:

courses/  → metadata (scraped)
classes/  → existing chat messages

We must build on top of this.

--------------------------------------------------

## HIGH LEVEL RULES

Forum posts
→ course-wide
→ stored under courses/

Groupchat messages
→ quarter-specific
→ stored under classes/

Lecture and discussion times
→ quarter-specific
→ stored under classes/

Users do NOT need to enroll to view forum.

--------------------------------------------------

## EXISTING STRUCTURE

courses/{courseId}
  code
  name
  lecture_times   (currently here, but should move)
  discussion_times

classes/{classId}
  messages/

Messages were implemented first under classes.

--------------------------------------------------

## NEW STRUCTURE (DO NOT BREAK EXISTING DATA)

We will evolve classes into quarter-specific course instances.

### courses collection (forum lives here)

courses/{courseId}

  code
  name

  posts/{postId}
    title
    body
    author_id
    author_name
    created_at
    upvote_count
    comment_count

    comments/{commentId}
      body
      author_id
      author_name
      created_at
      parent_comment_id
      depth
      path

    upvotes/{uid}

Forum posts are NOT quarter-specific.

--------------------------------------------------

### classes collection (quarter specific)

Each class doc represents:
one course in one quarter

Example ids:
ecs_020_2026_winter
ecs_020_2026_spring

classes/{classId}

Fields:
- course_id  (ex: ecs_020)
- quarter    (ex: 2026_winter)
- lecture_times
- discussion_times

messages/{messageId}
  text
  author_id
  author_name
  created_at

--------------------------------------------------

## LATEST QUARTER LOGIC

When loading groupchat for a course:

1. query classes where course_id == target course
2. choose latest quarter
3. load messages from that class doc

If no class exists yet:
create one automatically.

Client never selects quarter.

--------------------------------------------------

## THREADED COMMENT RULES

comments/{commentId}

Fields:
- parent_comment_id
- depth
- path

Path examples:
top level → "c1"
reply → "c1/c2"
reply → "c1/c2/c3"

Order comments by path.

--------------------------------------------------

## BACKEND TASKS

Add forum endpoints using courses collection.

Update groupchat endpoints to:
- resolve latest class doc for course
- read/write messages there

DO NOT expose quarter to client.

--------------------------------------------------

## IOS TASKS

Add Forum tab.

Forum uses courses collection.

Groupchat continues to open normally but backend now resolves
latest quarter automatically.

--------------------------------------------------

## CONSTRAINTS

Do not delete existing data.
Do not rename collections.
Extend safely.

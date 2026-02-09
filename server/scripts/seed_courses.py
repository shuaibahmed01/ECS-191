"""Upload courses from CSV to Firestore.

Usage:
    python seed_courses.py [path/to/courses.csv]

Uses sanitized course codes as document IDs (e.g., "ECS 170" -> "ecs_170").
Idempotent: re-running overwrites existing documents without creating duplicates.
"""

import csv
import os
import sys

import firebase_admin
from firebase_admin import credentials, firestore


def init_firebase():
    """Initialize Firebase Admin SDK."""
    if not firebase_admin._apps:
        try:
            firebase_admin.initialize_app()
        except Exception:
            firebase_admin.initialize_app(options={
                'projectId': os.environ.get('FIREBASE_PROJECT_ID', 'coursehub-dev')
            })


def sanitize_id(course_code):
    """Convert course code to Firestore document ID.

    "ECS 170" -> "ecs_170", "ECS 032AV" -> "ecs_032av"
    """
    return course_code.lower().replace(" ", "_")


def classify_timing(timing):
    """Classify a timing string as 'lecture' or 'discussion'.

    Multi-day patterns (MWF, TR, MW, etc.) are lectures.
    Single-day patterns (M, T, W, R, F) are discussions.
    Returns None for TBA or unparseable timings.
    """
    timing = timing.strip()
    if not timing or timing.upper() == "TBA":
        return None, timing

    # Format: "10:30 - 11:50 AM, TR"
    parts = timing.rsplit(", ", 1)
    if len(parts) != 2:
        return None, timing

    days = parts[1].strip()
    if len(days) > 1:
        return "lecture", timing
    return "discussion", timing


def main():
    csv_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(__file__), "courses.csv"
    )

    if not os.path.exists(csv_path):
        print(f"Error: CSV file not found at {csv_path}")
        sys.exit(1)

    init_firebase()
    db = firestore.client()

    # Read CSV, deduplicate by courseCode, and collect timings
    courses = {}  # code -> {"name": ..., "lecture_times": set, "discussion_times": set}
    with open(csv_path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            code = row["courseCode"].strip()
            title = row["courseTitle"].strip()
            timing = row["timing"].strip()

            if code not in courses:
                courses[code] = {
                    "name": title,
                    "lecture_times": set(),
                    "discussion_times": set(),
                }

            kind, timing_str = classify_timing(timing)
            if kind == "lecture":
                courses[code]["lecture_times"].add(timing_str)
            elif kind == "discussion":
                courses[code]["discussion_times"].add(timing_str)

    print(f"Found {len(courses)} unique courses in CSV")

    # Upload to Firestore
    batch = db.batch()
    count = 0
    for code, info in sorted(courses.items()):
        doc_id = sanitize_id(code)
        ref = db.collection("courses").document(doc_id)
        batch.set(ref, {
            "code": code,
            "name": info["name"],
            "lecture_times": sorted(info["lecture_times"]),
            "discussion_times": sorted(info["discussion_times"]),
        })
        count += 1
        # Firestore batches are limited to 500 operations
        if count % 500 == 0:
            batch.commit()
            batch = db.batch()

    if count % 500 != 0:
        batch.commit()

    print(f"Uploaded {count} courses to Firestore")


if __name__ == "__main__":
    main()

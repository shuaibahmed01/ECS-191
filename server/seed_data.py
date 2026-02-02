"""Seed data for CourseHub classes."""

SEED_CLASSES = [
    {
        "id": 1,
        "class_code": "ECS 032A",
        "class_name": "Introduction to Programming",
        "quarter": "W26"
    },
    {
        "id": 2,
        "class_code": "ECS 032B",
        "class_name": "Introduction to Data Structures",
        "quarter": "W26"
    },
    {
        "id": 3,
        "class_code": "ECS 036A",
        "class_name": "Programming & Problem Solving",
        "quarter": "W26"
    },
    {
        "id": 4,
        "class_code": "ECS 036B",
        "class_name": "Software Development & Object-Oriented Programming",
        "quarter": "W26"
    },
    {
        "id": 5,
        "class_code": "ECS 036C",
        "class_name": "Data Structures, Algorithms, & Programming",
        "quarter": "W26"
    },
    {
        "id": 6,
        "class_code": "ECS 050",
        "class_name": "Computer Organization & Machine-Dependent Programming",
        "quarter": "W26"
    },
    {
        "id": 7,
        "class_code": "ECS 120",
        "class_name": "Theory of Computation",
        "quarter": "W26"
    },
    {
        "id": 8,
        "class_code": "ECS 122A",
        "class_name": "Algorithm Design & Analysis",
        "quarter": "W26"
    },
    {
        "id": 9,
        "class_code": "ECS 140A",
        "class_name": "Programming Languages",
        "quarter": "W26"
    },
    {
        "id": 10,
        "class_code": "ECS 150",
        "class_name": "Operating Systems & System Programming",
        "quarter": "W26"
    },
    {
        "id": 11,
        "class_code": "ECS 160",
        "class_name": "Software Engineering",
        "quarter": "W26"
    },
    {
        "id": 12,
        "class_code": "ECS 170",
        "class_name": "Introduction to Artificial Intelligence",
        "quarter": "W26"
    },
    {
        "id": 13,
        "class_code": "ECS 191",
        "class_name": "Design Project",
        "quarter": "W26"
    }
]

SEED_MESSAGES = [
    # Class 1: ECS 032A - Introduction to Programming
    {
        "id": 1,
        "class_id": 1,
        "sender_id": 2,
        "sender_name": "Alice Chen",
        "content": "Hey everyone! Anyone want to form a study group?",
        "timestamp": "2026-01-15T10:30:00Z"
    },
    {
        "id": 2,
        "class_id": 1,
        "sender_id": 3,
        "sender_name": "Bob Martinez",
        "content": "I'm in! When were you thinking?",
        "timestamp": "2026-01-15T10:35:00Z"
    },
    {
        "id": 3,
        "class_id": 1,
        "sender_id": 2,
        "sender_name": "Alice Chen",
        "content": "How about Thursday evenings at Shields Library?",
        "timestamp": "2026-01-15T10:40:00Z"
    },
    {
        "id": 4,
        "class_id": 1,
        "sender_id": 4,
        "sender_name": "Carol Wang",
        "content": "Thursday works for me too! See you all there.",
        "timestamp": "2026-01-15T11:00:00Z"
    },
    # Class 5: ECS 036C - Data Structures
    {
        "id": 5,
        "class_id": 5,
        "sender_id": 5,
        "sender_name": "David Kim",
        "content": "Anyone else struggling with the red-black tree assignment?",
        "timestamp": "2026-01-16T14:00:00Z"
    },
    {
        "id": 6,
        "class_id": 5,
        "sender_id": 6,
        "sender_name": "Emma Davis",
        "content": "Yes! The rotations are confusing. Want to meet at the CS lab?",
        "timestamp": "2026-01-16T14:15:00Z"
    },
    {
        "id": 7,
        "class_id": 5,
        "sender_id": 5,
        "sender_name": "David Kim",
        "content": "That would be great. How about tomorrow at 3pm?",
        "timestamp": "2026-01-16T14:20:00Z"
    },
    # Class 13: ECS 191 - Design Project
    {
        "id": 8,
        "class_id": 13,
        "sender_id": 7,
        "sender_name": "Frank Lee",
        "content": "Team meeting for milestone 1 - when is everyone free?",
        "timestamp": "2026-01-17T09:00:00Z"
    },
    {
        "id": 9,
        "class_id": 13,
        "sender_id": 8,
        "sender_name": "Grace Liu",
        "content": "I can do Monday or Wednesday afternoons.",
        "timestamp": "2026-01-17T09:30:00Z"
    },
    {
        "id": 10,
        "class_id": 13,
        "sender_id": 9,
        "sender_name": "Henry Park",
        "content": "Wednesday at 2pm works best for me.",
        "timestamp": "2026-01-17T10:00:00Z"
    },
    {
        "id": 11,
        "class_id": 13,
        "sender_id": 7,
        "sender_name": "Frank Lee",
        "content": "Wednesday 2pm it is! I'll book a room in Kemper.",
        "timestamp": "2026-01-17T10:15:00Z"
    }
]

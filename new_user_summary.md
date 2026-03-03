## New User Study Summary

### Overall

- **Core understanding**: Across all phases, users consistently saw the app as a "smarter Canvas" / "one‑stop hub" that centralizes course info, extracts key syllabus details, and offers class chat plus an AI assistant.
- **Trust in AI**: Users generally trusted AI for concrete facts (dates, policies) but wanted transparency (citations, links to sources) and the ability to verify answers quickly.
- **Usability**: Setup and navigation were consistently described as "very easy" or "straightforward," with most friction coming from edge cases (wrong uploads, undiscoverable features).

### Phase 1 – Initial Validation & Basic UX Fixes

**What we learned**

- Users immediately recognized the Course Agent and syllabus-reading value, and described the app as a "one-stop shop" for class info.
- Trust dropped when answers were unhelpful (missing info in syllabus) or visually unpolished.
- Empty group chats felt intimidating; users were hesitant to send the first message.
- Some navigation labels were confusing (greeting doubling as a back button).
- Users experimented with invalid uploads (random images/docs), exposing brittle error handling and lack of an obvious "re-upload syllabus" path.

**What we changed**

- **Navigation clarity**: Fixed the "Hi [User Name]" label so back navigation is clear and the greeting lives in the toolbar instead.
- **Agent affordances**: Made Course Agent suggestion buttons persist in a scrollable bar so common questions are always one tap away.
- **Empty-state design**: Added a friendly first-message screen in empty group chats to lower the barrier to starting conversations.
- **Upload validation**: Added backend checks for non-syllabus files and surfaced a clear 422 error message instead of a generic 500.
- **Recovery flow**: Exposed a visible "Wrong syllabus? Re-upload" area in the syllabus view with explicit actions to upload/retake.

### Phase 2 – Discoverability & Course Management

**What we learned**

- Users continued to describe the app as a simpler, AI-enhanced Canvas companion.
- Some important features (class group chat) were not immediately discoverable.
- Users needed better course management controls (e.g., removing an accidentally added class).
- There was demand for adding non-CS / non-catalog classes to make the app useful beyond a fixed course list.

**What we changed**

- **Group chat discoverability**: Added a prominent "Open Class Group Chat" entry in the class detail screen.
- **Course removal**: Introduced an explicit "Remove from Schedule" button with confirmation inside the class detail view.
- **Custom courses**: Added support for creating custom/non-listed courses via an "Add Custom" flow that hits the backend to upsert new classes.

### Phase 3 (Trust, Power Features, and Search)

**What we learned**

- Users now clearly articulated the product vision: a smarter Canvas companion that unifies syllabus parsing, chat, and materials in one searchable place.
- Trust in AI was tightly coupled with source visibility: users wanted inline citations, jump-to-context, and verification options.
- Power users wanted richer collaboration (attachments) and global search across classes, chats, and documents with filters.

**What we changed**

- **Transparent answers**: Added inline AI citation chips that deep-link into and highlight the relevant syllabus sections.
- **Richer chat**: Enabled native file/image attachments in class chat with inline previews to make it a more complete home for class communication.
- **Global search**: Improved search to include course tags, better query matching (including numeric course hints), and direct navigation to the right chat or syllabus.
- **UI polish**: Cleaned up visual noise (redundant chevrons, inconsistent back buttons) and ensured chat titles consistently show the course code for orientation.

### Trajectory Across Iterations

- **Phase 1** focused on confirming core value and fixing obvious UX pain points.
- **Phase 2** improved feature discoverability and basic course lifecycle management.
- **Phase 3** deepened AI trust, collaboration capabilities, and cross-app search, shifting toward a more powerful and reliable daily tool.


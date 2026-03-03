# User Experience Notes

## Phase 1
### User # 1
1. What do you think this app does?

- "It looks like an app to interact with a Course Agent that has all the information on classes you're taking"
- Accurate analysis. Course Agent feature seems to dominate user's attention.
   
2. Do you trust the AI results? (after having them complete their AI-related task)

- "Umm not really?"
- I should've asked a little bit more about this (this was my first user experience interview so I wasn't used to it yet), but this is likely because 1. the agent didn't provide any useful information because the syllabus uploaded didn't have the information the user was looking for and 2. the agent's text output wasn't formatted and looked a little janky.

3. How easy was this? How would you explain this to someone else using one sentence?

- "It was pretty easy"
- "If I had to explain this to someone else in one sentence... I'd call this a one-stop shop for information on your classes."
- Exactly what we're aiming for in terms of user understanding of our app!

4. Other Notes:

- User appreciated how easy the app was to navigate.
- They also appreciated how the Course Agent had buttons to automatically ask the user certain questions. But it becomes a little cumbersome once the user has already asked a question once, and those buttons disappear -> We should think of a way for these options to always be visible to a user, even after they've asked a question before.
- We should think of how to pre-populate some parts of the app so it’s a little more intuitive to use (ex: class gc was empty -> daunting to send first message)

### User # 2

1. What do you think this app does?  

- "Seems like some kind of planner app where you can keep track of all your classes, anything related to the class in terms of materials. seems like you can. Almost like AI-driven Canvas."
- Overall pretty accurate analysis.

2. Do you trust the AI results? (after having them complete their AI-related task)

- "Yeah. Seeing as how I'm uploading the material, all its doing is scanning and summarizing."
- User actually tried doing some stuff that isn't expected by the app. Ex: They uploaded a random picture as a syllabus, and our app gave a 500 error. (Perhaps we need to add something to catch this edge case and remind the user they need to upload a valid syllabus?)
- They tried a second time with a random document and it worked, but as expected none of the syllabus fields were properly filled in. Luckily, the user was able to manually edit it after the fact so this shouldn't be too much of an issue? But maybe we should also have a button to "Submit Updated Syllabus" so we can fix the course if the wrong document was uploaded.

3. How easy was this? How would you explain this to someone else using one sentence?
   
- "It's pretty straightforward. Everything is labeled well."
- I don't think the user had any issues with navigating our app. They just seemed to try and break our agent on purpose :( 

4. Other Notes:
- “Hi [User Name]” is also the backwards button once you've clicked on a class -> need to fix this
- It doesn't seem like theres any other point of having the profile except signing out? -> Told him its for ensuring UC Davis student use and also having a user name when talking to a class.
- What happens if there's multiple sections to a course? -> need to work this out
- Is there any way to make cummulative/summary notes thing from the AI -> there is technically, from the Course Agent chat, but we shouldn't rely on this being in chat format. Chat format, as mentioned, should be our last resort.
  
### User # 3

1. What do you think this app does?
- "Looks like it stores information on classes. It has slides, class information, syllabus, Course Agent, and a groupchat with what I'm assuming is other students."
2. Do you trust the AI results? (after having them complete their AI-related task)
- "Yeah. It's pretty much how I'd use ChatGPT to read through a syllabus for me regularly, but it's nice the syllabus and agent are together in one place. I don't need to switch between Canvas files and Chat."
3. How easy was this? How would you explain this to someone else using one sentence?
- "Very easy to use. Didn't need you to tell me how to use it at all."
- "Class groupchat with information about the course through stuff the users upload and an agent to parse through everything for you."
4. Other Notes:
- User complimented our app! Said they would use this as is.
- They appreciated the class groupchat feature. They ran into a problem last week where they were trying to get into a class discord that they forgot to join, but the invite link sent through Canvas inbox had long expired. With our app, the groupchat is always available to students in the related class.


## Phase 1 Changes

Based on the feedback above, we made the following changes:

1. **Fixed "Hi [User Name]" back button** (User #2) — Changed the navigation title of MyScheduleView to "My Schedule" so child views show a proper back button label. The personalized greeting is now displayed as a toolbar header instead.

2. **Persistent suggestion buttons in Course Agent** (User #1) — Suggestion buttons (e.g. "When is the midterm?", "Office hours?") now remain visible in a horizontally scrollable bar above the text input even after the user has sent messages, rather than disappearing after the first question.

3. **Welcoming empty state for group chat** (User #1) — When a class groupchat has no messages yet, a friendly welcome screen is shown with the class code, an explanation of the chat's purpose, and a "Be the first to send a message!" prompt to make it less daunting to start.

4. **Validation for non-syllabus file uploads** (User #2) — The backend now checks whether the uploaded file is actually a syllabus after AI extraction. If 4+ out of 5 fields come back as "Not specified", the server returns a 422 error with a helpful message ("The uploaded file does not appear to be a valid course syllabus") instead of a generic 500 error.

5. **Visible "Re-upload Syllabus" button** (User #2) — Added a "Wrong syllabus?" section at the bottom of the syllabus detail view with clear "Upload New Syllabus (PDF)" and "Retake Syllabus Photo" buttons, so users don't have to discover the small toolbar menu icon.

## Phase 2

### User # 4

1. What do you think this app does

You put your class schedule and it basically serves as a syllabus reader. It tells you all the information from the syllabus.  

2. Do you trust the AI results? (after having them complete their AI-related task)

Yeah I do.

3. How easy was this? How would you explain this to someone else using one sentence?
   
Very easy, you just have to upload your syllabus.

4. Other Notes:

He didn't notice the class group chat feature that much. He said he would use it because right now he has to keep checking his phone. He says its for people who arent very on top of their scheduling but because he always puts the information in google calendar he doesn't need it that much.

### User # 5

1. What do you think this app does

It looks like a sort of smart canvas. It can summarize and the AI aspect is useful because it can get you quick access to the course and can get you quick information. It's meant to use your canvas and meant for it to be more user friendly/

2. Do you trust the AI results? (after having them complete their AI-related task)

I do because the developers are trustworthy.

3. How easy was this? How would you explain this to someone else using one sentence?
   
Imagine canvas but a lot easier. It was very easy.

4. Other Notes:

There's no way to remove classes. I misclicked on one and now you can't remove it.

### User # 6

1. What do you think this app does

It's a canvas extension that uses AI to make the workload easier for students.

2. Do you trust the AI results? (after having them complete their AI-related task)

For specific stuff like dates I would, but I'd also double check. For general questions like when I asked about the AI policy I'd prefer to read it myself to see if there are any like exceptions or specific wordinh.

3. How easy was this? How would you explain this to someone else using one sentence?
   
It was easy because the material is sort of just hard coded. I'd describe it as a canvas app that simplifies the student workflow.

4. Other Notes:

I'm taking non-cs classes that aren't in there so if there was maybe a way that I could add my own class it would be helpful? Or some way to get my MGT courses. Otherwise, it's pretty decent but I wouldn't end up using it that much because I'm a graduating senior and used to the canvas flow.

## Phase 2 Changes

Based on the feedback above, we made the following changes:

1. **Prominent "Open Class Group Chat" entry** (User #4) — Added a large callout at the top of `ClassDetailView` with icon, description, and chevron to make the class group chat clearly discoverable.

2. **Explicit "Remove from Schedule" action** (User #5) — Added a destructive "Remove from Schedule" button with confirmation inside `ClassDetailView`, complementing the existing swipe-to-delete on `MyScheduleView`.

3. **Support for custom/non-listed courses** (User #6) — Introduced an "Add Custom" flow in `ClassListView` to create and immediately enroll in courses outside the default catalog (e.g., MGT). Client calls `APIClient.createCustomClass(...)` which hits `POST /v1/classes` (auth required); the server upserts into the course catalog via `server/services/datastore_service.py`.

## Phase 3
### User # 7
1. What do you think this app does?

- "It’s like a smarter Canvas companion that pulls important info from my syllabus, lets me chat with classmates, and keeps everything for each class in one place."
- Accurate. They immediately recognized the syllabus + AI + class hub concept.
  
2. Do you trust the AI results? (after having them complete their AI-related task)

- "For dates and policies, yes if I can see where it came from. I want a link or highlight to the exact line in the syllabus."
- Trust improves with transparent citations and quick access to the original source.

3. How easy was this? How would you explain this to someone else using one sentence?
   
- "Very easy. Upload a syllabus and get the key details and a place to talk to your class."
- One-sentence: "A one-stop hub that extracts class info for you and keeps your class organized."

4. Other Notes:

- Wants AI answers to show inline citations with jump-to-syllabus context (tap-to-highlight).

### User # 8
1. What do you think this app does?

- "Group chat plus quick facts about my course from files. Feels like a shared space for the class that’s simpler than Discord."
- Accurate, and they framed it as a lightweight alternative to external tools.

2. Do you trust the AI results? (after having them complete their AI-related task)

- "I trust it for quick lookups, but I need to verify for anything I post to my group. File links and previews would help."
- Trust increases if answers are verifiable and rich previews reduce friction.

3. How easy was this? How would you explain this to someone else using one sentence?
   
- "Easy to get started and add classes."
- One-sentence: "A simpler class home with chat and fast answers from your materials."

4. Other Notes:

- Wants file/image attachments in class chat with link previews.

### User # 9
1. What do you think this app does?

- "Centralizes course info and lets me query it; could replace bouncing between Canvas, email, and Drive."
- Accurate; sees it as a workflow consolidator.

2. Do you trust the AI results? (after having them complete their AI-related task)

- "Trust is good if I can search globally and see sources; I’d like a confidence hint or 'verify against source' button."
- Trust hinges on discoverability of sources and global search coverage.

3. How easy was this? How would you explain this to someone else using one sentence?
   
- "Straightforward, but I want power features."
- One-sentence: "Your classes, chats, and extracted facts, all searchable in one app."

4. Other Notes:

- Global search across classes, chat, and syllabus with filters.

## Phase 3 Changes

Based on the feedback above, we made the following changes:

1. **Inline AI citations with syllabus jump** (User #7) — Assistant replies now include tappable citation chips that open `Syllabus` scrolled to and highlighted on the referenced section (e.g., Office Hours, Grading).

2. **Native chat attachments with previews** (User #8) — Replaced link input with iMessage-style attachments. Users can take a photo or choose a file; images render inline previews in `ChatView`.

3. **Global Search improvements** (User #9) — Results now show a course tag (e.g., “ECS 154A”), match tokenized queries (including numeric class hints like “154 midterm”), and navigate directly to the correct class `Chat` or `Syllabus`.

4. **UI polish from testing** — Removed redundant chevrons in `ClassDetailView` callout, standardized back navigation (removed “Close” in Search), and ensured chat titles display the proper course code.

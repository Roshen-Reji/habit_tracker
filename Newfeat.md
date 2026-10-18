

## 1. Product Vision

**One app that captures anything in seconds, understands a student's week, plans the day intelligently, and never lets a deadline surprise you.**

### Core principles
1. **Capture in under 3 seconds.** Nothing may slow this down.
2. **Reminders never fail.** If notifications are unreliable, nothing else matters.
3. **Offline-first.** Everything works with no signal; sync happens quietly.
4. **AI proposes, you approve.** Every automatic change is explained, previewable and undoable.
5. **Calm by default, powerful on demand.** New users see Today and one "+" button. Depth appears when needed.
6. **Time is visible.** The day is a timeline, not just a list.
7. **Fair and private.** Generous free tier, no ads, user data stays user-owned.

### Target users
| User | Main need |
|---|---|
| **University / college student** (primary) | Classes, labs, assignments, exams, group projects, attendance |
| **School student** | Homework, timetable, exam prep |
| **Self-learner / developer** | Projects, study plans, habit streaks |
| **Club / committee member** | Event tasks, shared deadlines |

---

## 2. The Essentials Checklist (Non-Negotiables)

If the app has only these, it's already a strong product. Everything in this list is `P0` or `P1`.

- [ ] Add a task in under 3 seconds (typed shorthand and voice)
- [ ] Title, notes, due date and time, priority, course/project, tags
- [ ] Subtasks / checklists
- [ ] Recurring tasks (daily, weekly, custom, "after completion")
- [ ] Reminders that fire reliably (multiple per task, snooze)
- [ ] Today, Upcoming, Overdue, Inbox views
- [ ] Calendar view and timeline view
- [ ] Courses and weekly timetable (including rotating schedules and lab batches)
- [ ] Exams with syllabus topics
- [ ] Offline-first with automatic sync across devices
- [ ] Search and filters
- [ ] Focus timer linked to tasks
- [ ] Habits with forgiving streaks
- [ ] Home-screen widgets and quick-add
- [ ] Dark mode and accessibility support
- [ ] Import / export (CSV, iCal, Markdown)
- [ ] Backup and account recovery

### The "Dream" Differentiators (what makes it the best)
- [ ] AI morning plan with approval ("why is this here?")
- [ ] Voice brain-dump, photo capture, syllabus/PDF import
- [ ] Big-task breakdown with backwards deadlines
- [ ] Exam mode with spaced revision plan
- [ ] Workload heatmap and overload warnings
- [ ] Attendance tracker ("how many classes can I still miss?")
- [ ] Grade/GPA tracker with target calculator
- [ ] Group projects with guest links and common-free-slot finder
- [ ] Weekly review and shutdown ritual
- [ ] Autonomy dial for AI (manual → fully auto)

---

## 3. Feature Specification

### M1. ⚡ Capture

| ID | Feature | Pri |
|---|---|---|
| CAP-1 | **Quick Add** (global "+" button, widget, lock-screen/notification action) | P0 |
| CAP-2 | **Natural-language parsing** | P0 |
| CAP-3 | **Inbox** (unsorted captures) | P0 |
| CAP-4 | **Voice brain-dump** | P1 |
| CAP-5 | **Share-sheet capture** (text, links, images from other apps) | P1 |
| CAP-6 | **Photo capture** (whiteboard, assignment sheet, timetable) | P1 |
| CAP-7 | **Syllabus / PDF import** (extract deadlines, exams, topics) | P1 |
| CAP-8 | **Email-forward capture** | P2 |
| CAP-9 | **Multilingual and mixed-language input** | P1 |

**CAP-1 AC**
- From app launch to a saved task takes **≤ 3 seconds** with the keyboard already open.
- Pressing "Enter" saves and keeps the field open for the next task (rapid-fire mode).
- Works fully offline.

**CAP-2 Natural-language grammar (parse live, show chips while typing)**
| Token | Examples | Result |
|---|---|---|
| Date | `today`, `tmr`, `fri`, `next mon`, `25 oct`, `in 3 days`, `end of month` | Due date |
| Time | `5pm`, `17:30`, `noon` | Due time |
| Duration | `~2h`, `for 45m`, `est 90min` | Estimated effort |
| Priority | `!1`–`!4`, `!high`, `!urgent` | Priority |
| Course / project | `#DBMS`, `#Capstone` | Link to course/project |
| Tag | `@lab`, `@revision` | Tag |
| Recurrence | `every mon`, `daily`, `every 2 weeks`, `every weekday` | Recurrence rule |
| Reminder | `remind 1d before`, `remind 30m before` | Reminder offset |

- **AC:** `DBMS record fri 5pm #DBMS !high ~2h @lab` → title "DBMS record", due next Friday 17:00, course DBMS, priority high, effort 2h, tag lab. Each parsed token is shown as a removable chip; tapping a chip edits it. If the user dismisses a chip, that text stays in the title.

**CAP-4 Voice brain-dump AC**
- User speaks freely; app returns a **review list** of proposed tasks (title, course, due date, priority).
- Nothing is saved until the user confirms (individually or "Add all").
- Supports spoken corrections ("actually make that Thursday").

**CAP-6/7 AC**
- Extraction results are shown in a **review screen** with confidence indicators; low-confidence fields are highlighted for the user to fix before import.
- Original image/PDF stays attached to the created items.

---

### M2. ✅ Tasks Core

| ID | Feature | Pri |
|---|---|---|
| TSK-1 | **Task fields** (see Data Model) | P0 |
| TSK-2 | **Subtasks / checklists** (nested one level, reorderable) | P0 |
| TSK-3 | **Priority** (4 levels, color-coded) | P0 |
| TSK-4 | **Due date, due time, start date ("hide until")** | P0 |
| TSK-5 | **Recurrence** (RRULE-based; fixed schedule or after completion) | P0 |
| TSK-6 | **Tags and course/project assignment** | P0 |
| TSK-7 | **Complete / uncomplete with Undo** | P0 |
| TSK-8 | **Bulk actions** (multi-select: move, reschedule, tag, delete) | P1 |
| TSK-9 | **Duplicate / templates** (e.g. "Weekly lab record" template) | P1 |
| TSK-10 | **Dependencies** ("blocked by" another task) | P2 |
| TSK-11 | **Estimated effort and actual time** | P1 |
| TSK-12 | **Task history / activity log** | P2 |
| TSK-13 | **Archive & trash** (30-day restore) | P0 |

**TSK-5 AC**
- Supports daily, weekly (specific days), monthly, yearly, custom interval, and end conditions (never / on date / after N).
- Two modes: **"Repeat on schedule"** (next due date from the original schedule) and **"Repeat after completion"** (next due date = completion date + interval).
- Completing a recurring task creates the next instance immediately and keeps history of past completions.
- "Skip this occurrence" and "Edit this / all future" are available.

**TSK-7 AC**
- Completion animation < 300 ms; an Undo snackbar appears for 5 s.
- Completing a parent with open subtasks asks: "Complete all subtasks?"

---

### M3. 🗂️ Organization and Views

| ID | Feature | Pri |
|---|---|---|
| VIEW-1 | **Today** (overdue + due today + planned today) | P0 |
| VIEW-2 | **Upcoming** (next 7/14/30 days, grouped by day) | P0 |
| VIEW-3 | **Inbox** | P0 |
| VIEW-4 | **Course / Project pages** | P0 |
| VIEW-5 | **Calendar view** (day / 3-day / week / month) | P0 |
| VIEW-6 | **Timeline view** (visual day: classes + tasks + breaks) | P1 |
| VIEW-7 | **Board view** (Kanban by status) | P1 |
| VIEW-8 | **Search** (title, notes, tags, attachments) | P0 |
| VIEW-9 | **Filters and saved smart lists** | P1 |
| VIEW-10 | **Sorting & grouping** (due, priority, course, manual drag) | P0 |
| VIEW-11 | **Completed history** | P1 |

**AC**
- All views are **free** (no paywalled basics).
- Today screen answers: "What should I do next?" It highlights **one suggested next task** at the top.
- Search returns results as the user types (< 150 ms for up to 10,000 tasks, local).
- Filters combine with AND/OR (course, tag, priority, due range, status, has-attachment).

---

### M4. 🔔 Reminders and Notifications

| ID | Feature | Pri |
|---|---|---|
| REM-1 | **Time reminders** (multiple per task, relative or absolute) | P0 |
| REM-2 | **Snooze** (10 min, 1 h, tonight, tomorrow, custom) | P0 |
| REM-3 | **Notification actions** (Done, Snooze, Open) | P0 |
| REM-4 | **Daily digest** (morning summary, evening review nudge) | P1 |
| REM-5 | **Class reminders** ("Class in 15 min, room C-204") | P1 |
| REM-6 | **Quiet hours / exam-week mode** | P1 |
| REM-7 | **Location reminders** | P2 |
| REM-8 | **Escalating reminders** for critical tasks (repeat until acknowledged) | P2 |
| REM-9 | **Reliability health check** (detects disabled notifications / battery restrictions and guides the user) | P0 |

**AC**
- Reminders are scheduled **locally on-device** so they fire offline and after reboot.
- Reminder fires within **±1 minute** of the scheduled time on a healthy device.
- App re-schedules all reminders after reboot, time zone change, and app update.
- If notification or exact-alarm permission is missing, a persistent in-app banner explains how to fix it.
- Default reminder offsets are user-configurable per task type.

---

### M5. 🎓 Academic Module

| ID | Feature | Pri |
|---|---|---|
| ACA-1 | **Courses** (name, code, color, credits, instructor, room, links) | P0 |
| ACA-2 | **Semesters** (date range, archive and rollover) | P1 |
| ACA-3 | **Timetable** (weekly, rotating weeks, lab batches, holidays) | P0 |
| ACA-4 | **Class sessions** (auto-generated from timetable, with per-session notes) | P1 |
| ACA-5 | **Exams** (date, time, venue, syllabus topics, topic confidence) | P0 |
| ACA-6 | **Assignments** (task subtype with weightage and max marks) | P1 |
| ACA-7 | **Attendance tracker** | P1 |
| ACA-8 | **Grade & GPA tracker** | P1 |
| ACA-9 | **Semester dashboard** | P1 |
| ACA-10 | **Shared batch timetable** (class rep publishes, others import) | P2 |
| ACA-11 | **Import from college portal exports / ICS / CSV** | P1 |

**ACA-3 AC**
- Supports "Week A / Week B" rotation, specific-date overrides (cancelled, extra, rescheduled class) and holiday ranges.
- Classes appear in Today, Calendar and Timeline views.

**ACA-7 Attendance AC**
- Mark Present / Absent / Cancelled per session (one tap from class reminder notification).
- Per course: attendance %, **required minimum %** (user-set), and **"you can still miss N classes"** / **"you must attend next N classes"** calculation.
- Warning at configurable threshold (e.g. within 5% of the minimum).

**ACA-8 Grades AC**
- Components with weightage per course; configurable scale (4.0 GPA, 10-point CGPA, percentage).
- **Target calculator:** "What do I need on the final to get X?"
- Running semester and cumulative GPA.

---

### M6. 🧠 Smart Planning (AI)

| ID | Feature | Pri |
|---|---|---|
| PLAN-1 | **Today ranking** (rule-based urgency score, no AI needed) | P0 |
| PLAN-2 | **Free-time detection** (gaps between classes/events) | P1 |
| PLAN-3 | **AI morning plan** (proposed schedule for today) | P1 |
| PLAN-4 | **"Why is this here?" explanations** | P1 |
| PLAN-5 | **Autonomy dial** (Manual / Suggest / Auto-with-approval / Auto) | P1 |
| PLAN-6 | **Editable scheduling rules** | P1 |
| PLAN-7 | **Big-task breakdown** (milestones scheduled backwards from deadline) | P1 |
| PLAN-8 | **Exam mode** (revision plan + spaced repetition) | P1 |
| PLAN-9 | **"Rebalance my day"** (one-tap re-plan with before/after diff) | P1 |
| PLAN-10 | **Workload heatmap & overload warnings** | P1 |
| PLAN-11 | **Effort estimate learning** (adjusts using actual vs. estimated time) | P2 |
| PLAN-12 | **Deadline conflict detection** | P1 |
| PLAN-13 | **Tiny first step suggestions** (for avoided tasks) | P2 |

**PLAN-3 AC**
- Plan is generated in < 5 s and shown as time blocks on the day timeline.
- User can accept all, accept one, drag blocks, or reject.
- **Nothing is committed without approval** unless the user has set autonomy to "Auto".
- Every block shows its reason: *"Due tomorrow · 2h estimated · fits your free slot 2–4 pm"*.

**PLAN-5 Autonomy levels**
| Level | Behavior |
|---|---|
| Manual | App only shows free slots |
| Suggest | App proposes; user accepts each |
| Auto-with-approval (default) | App re-plans when things change and asks to confirm the diff |
| Auto | App re-plans silently, shows a "Changed" badge and allows Undo |

**PLAN-6 Rule examples (user-editable, visible)**
- Working hours per weekday; no study after 10 pm; keep Sundays light.
- Minimum block length (e.g. 25 min), maximum continuous study (e.g. 90 min), break length.
- Preferred deep-work hours (e.g. mornings).
- Buffer before deadlines (e.g. finish 1 day early).

**PLAN-7 AC**
- Given a large task and a deadline, propose 3–8 milestones with dates computed **backwards** from the deadline; user can edit before creating subtasks.

**PLAN-8 Exam mode AC**
- Input: exam date, syllabus topics (manual or imported), available study time.
- Output: day-by-day revision schedule; weak topics get more sessions; topics resurface at spaced intervals (e.g. 1, 3, 7, 14 days).
- User rates confidence per topic after each session; plan adapts.

**PLAN-10 AC**
- Weekly heatmap shows estimated workload hours per day.
- Banner when any day exceeds the user's realistic capacity or when ≥ 3 deadlines/exams fall in the same 3 days.

---

### M7. 🎯 Focus and Habits

| ID | Feature | Pri |
|---|---|---|
| FOC-1 | **Focus timer** (Pomodoro + custom), tied to a task | P1 |
| FOC-2 | **Time tracking per task/course** (automatic from focus sessions) | P1 |
| FOC-3 | **Ambient sounds** | P2 |
| FOC-4 | **Distraction blocking** (Android: app blocking via permissions) | P2 |
| FOC-5 | **"Just 5 minutes" start mode** | P1 |
| HAB-1 | **Habits** (daily / weekly / x times per week) | P1 |
| HAB-2 | **Forgiving streaks** (rest days, freezes) | P1 |
| HAB-3 | **Habit reminders and widgets** | P1 |
| FOC-6 | **Study-together rooms** (quiet body-doubling) | P2 |

**AC**
- Focus session continues correctly if the app is backgrounded or the screen is locked (foreground service on Android).
- Session logs start/end, task, course and interruption count.
- Habit streak does not break on a planned rest day or when a freeze is used.

---

### M8. 📝 Notes and Attachments

| ID | Feature | Pri |
|---|---|---|
| NOTE-1 | **Notes on tasks, courses and class sessions** (Markdown, checklists) | P1 |
| NOTE-2 | **Attachments** (images, PDFs, links, files) | P1 |
| NOTE-3 | **Course space** (auto-collects deadlines, notes, files, grades) | P1 |
| NOTE-4 | **Universal search across notes and attachments** | P1 |
| NOTE-5 | **Handwritten note photo with optional text extraction** | P2 |
| NOTE-6 | **Markdown import/export** | P1 |

**AC**
- No database-building or template-designing required.
- Attachments are stored locally and synced; size limits are shown clearly.

---

### M9. 👥 Collaboration

| ID | Feature | Pri |
|---|---|---|
| COL-1 | **Shared project boards** (owners, deadlines, comments, status) | P1 |
| COL-2 | **Invite by link / QR** | P1 |
| COL-3 | **Guest view** (web link, no install required) | P1 |
| COL-4 | **Task assignment and mentions** | P1 |
| COL-5 | **Common free-slot finder** (shows availability without exposing details) | P2 |
| COL-6 | **Contribution view** | P2 |
| COL-7 | **Club / event mode** | P2 |
| COL-8 | **Roles** (owner, editor, viewer) | P1 |

**AC**
- Joining via link takes ≤ 3 taps.
- Removing a member immediately revokes access (server-side authorization checks on every request).
- Availability sharing exposes only "free/busy", never event titles.

---

### M10. 📊 Insights and Wellbeing

| ID | Feature | Pri |
|---|---|---|
| INS-1 | **Weekly review** (planned vs. done, time per course, best hours) | P1 |
| INS-2 | **Shutdown ritual** (end-of-day: carry over / reschedule / drop) | P1 |
| INS-3 | **Streaks and milestones** (gentle, optional) | P1 |
| INS-4 | **Burnout guard** (warns on over-planning, suggests rest) | P2 |
| INS-5 | **Productivity charts** | P2 |

**AC**
- Tone is encouraging; no shaming language.
- Weekly review is generated automatically each Sunday (time configurable) and takes < 2 minutes to read.

---

### M11. 🔄 Sync, Accounts and Integrations

| ID | Feature | Pri |
|---|---|---|
| SYN-1 | **Offline-first local database** (source of truth on device) | P0 |
| SYN-2 | **Background sync** across devices | P0 |
| SYN-3 | **Accounts** (email, Google, Apple) + guest/local-only mode | P0 |
| SYN-4 | **Conflict resolution** | P0 |
| SYN-5 | **Two-way calendar sync** (Google / Outlook / Apple) | P1 |
| SYN-6 | **Import** (Todoist, TickTick, Notion, CSV, ICS) | P1 |
| SYN-7 | **Export** (CSV, JSON, Markdown, iCal) | P0 |
| SYN-8 | **LMS / Classroom import** | P2 |
| SYN-9 | **GitHub issue linking** (useful for CS students) | P2 |
| SYN-10 | **Public API / webhooks** | P2 |
| SYN-11 | **Backup and restore** | P0 |

**Sync rules**
- Local DB is the source of truth; UI never waits for the network.
- Every change is written to a **local operation log** and pushed when online.
- **Conflicts:** field-level last-write-wins using a hybrid logical clock; lists (subtasks, tags) merge by item; deletes are **tombstones** (soft delete) so they sync reliably.
- **AC:** Edit the same task on two offline devices → after reconnect, both devices converge to the same state with no data loss for non-conflicting fields.

---

### M12. ⚙️ Settings, Accessibility and Privacy

| ID | Feature | Pri |
|---|---|---|
| SET-1 | **Themes** (light/dark/AMOLED, accent colors, course colors) | P0 |
| SET-2 | **Accessibility** (screen reader labels, scalable text, high contrast, reduced motion, dyslexia-friendly font option) | P0 |
| SET-3 | **Widgets** (Today list, quick add, next class, habit) | P1 |
| SET-4 | **Language and regional settings** (week start, holidays, date formats) | P0 |
| SET-5 | **Privacy controls** (what AI sees, data export, account deletion) | P0 |
| SET-6 | **App lock** (biometric / PIN) | P2 |
| SET-7 | **Wear OS / watch quick actions** | P2 |
| SET-8 | **Onboarding** (60-second setup: courses, timetable, reminder preferences) | P0 |

**AC**
- Meets WCAG 2.1 AA contrast; every interactive element has a ≥ 48 dp touch target and a screen-reader label.
- Account deletion removes all server data within 30 days and confirms by email.

---

### M13. 💳 Pricing and Access

| ID | Feature | Pri |
|---|---|---|
| MON-1 | **Generous free tier** (all core features, all views, calendar sync, focus timer, habits, reminders) | P0 |
| MON-2 | **Pro tier** (full AI planning, exam-mode generation, advanced insights, larger groups, more storage) | P1 |
| MON-3 | **Student and regional pricing** | P1 |
| MON-4 | **Lifetime or one-time option** | P2 |
| MON-5 | **No ads, no dark patterns, transparent AI usage limits** | P0 |

---

## 4. Data Model

Use UUIDs, `createdAt`, `updatedAt`, `deletedAt` (tombstone), and `deviceId`/clock metadata on every synced entity.

### Core entities

| Entity | Key fields |
|---|---|
| **User** | id, name, email, timezone, locale, weekStart, settings (JSON) |
| **Semester** | id, name, startDate, endDate, isArchived |
| **Course** | id, semesterId, name, code, color, credits, instructor, room, requiredAttendancePct, gradeScale |
| **TimetableSlot** | id, courseId, dayOfWeek, startTime, endTime, room, weekPattern (every / A / B), batch, validFrom, validTo |
| **ClassSession** | id, slotId, courseId, date, status (scheduled / cancelled / extra / rescheduled), attendance (present / absent / unmarked), notesId |
| **Project** | id, name, color, courseId?, isShared, ownerId |
| **Task** | id, title, notes, status (inbox / todo / doing / done / archived), priority (1-4), dueAt, hasDueTime, startAt, courseId?, projectId?, parentTaskId?, estimateMin, actualMin, recurrenceRule (RRULE), recurrenceMode (fixed / afterCompletion), assigneeId?, weightage?, maxMarks?, scoreObtained?, sortOrder, completedAt |
| **Tag** / **TaskTag** | id, name, color / taskId, tagId |
| **Reminder** | id, taskId or sessionId, type (absolute / relative), offsetMin, fireAt, channel, isFired |
| **ScheduledBlock** | id, taskId, startAt, endAt, source (user / ai), reason, status (proposed / accepted / done / skipped) |
| **PlanProposal** | id, date, blocks[], rulesSnapshot, status (pending / accepted / rejected), createdAt |
| **Exam** | id, courseId, date, startTime, venue, weightage |
| **ExamTopic** | id, examId, title, confidence (0-3), lastStudiedAt, nextReviewAt |
| **FocusSession** | id, taskId?, courseId?, startAt, endAt, plannedMin, interruptions |
| **Habit** / **HabitLog** | id, name, schedule, freezesLeft / habitId, date, status |
| **Note** | id, parentType, parentId, markdown, updatedAt |
| **Attachment** | id, parentType, parentId, fileName, mime, size, storageKey |
| **GradeComponent** | id, courseId, name, weightage, maxMarks, score |
| **Board** / **Member** | id, name, ownerId / boardId, userId, role |
| **Comment** | id, taskId, authorId, body, createdAt |
| **ActivityLog** | id, entityType, entityId, action, actorId, at |

### Key relationships
- Course → many Tasks, Exams, TimetableSlots, GradeComponents
- Task → many Subtasks (via `parentTaskId`), Reminders, ScheduledBlocks, Attachments, Comments
- Board → many Projects/Tasks, many Members

---

## 5. Core Logic

### 5.1 "Today" ranking (rule-based, no AI required, `PLAN-1`)

```
urgency = 
    40 * dueProximity          // 1.0 if overdue, decays toward 0 over ~7 days
  + 25 * priorityWeight        // p1=1.0, p2=0.66, p3=0.33, p4=0
  + 15 * weightageFactor       // assessment weightage / 100 (0 if none)
  + 10 * overdueFactor         // min(daysOverdue, 7) / 7
  + 10 * effortPressure        // estimate / hoursUntilDue, clamped 0..1
```
- Sort descending; ties broken by oldest `createdAt`.
- Tune the weights with real usage data. Show the top item as **"Next up"**.

### 5.2 Scheduling algorithm (`PLAN-3`)

1. Collect **fixed events**: classes, calendar events, exams, user-blocked time.
2. Compute **free windows** inside working hours, respecting rules (quiet hours, buffers, max continuous work, breaks).
3. Sort candidate tasks by `urgency` (5.1).
4. For each task, place the **earliest suitable chunk(s)** before `dueAt - buffer`:
   - chunk length ≥ minimum block (default 25 min), ≤ maximum continuous (default 90 min)
   - split long tasks across multiple windows/days
   - prefer the user's deep-work hours for high-effort tasks
5. If a task can't fit before its deadline → flag **conflict** and suggest: move something, extend hours, or request an extension.
6. Output `PlanProposal` with a `reason` string per block (deadline, effort, slot fit).

> The LLM is used for *explanations, task breakdown and parsing*. Keep **time placement deterministic** (code), so plans are explainable and testable.

### 5.3 Recurrence
- Store as RFC 5545 `RRULE` plus `recurrenceMode`.
- Generate **only the next instance** (not the whole series) to keep data small; show projected future dates in the calendar view from the rule.
- Handle DST and time-zone changes by storing local-time intent + user timezone.

### 5.4 Reminder scheduling
- On every task/reminder change: cancel and reschedule affected local notifications.
- Maintain a rolling window (e.g. next 14 days or next 50 reminders) to stay inside OS limits (iOS limits pending local notifications; re-fill the window when the app opens or in background tasks).
- Re-register everything after boot, app update, timezone change.

### 5.5 Attendance math
```
// present, absent = sessions already marked; remaining = scheduled sessions still to come
// req = required minimum as a fraction (e.g. 0.75)
total        = present + absent + remaining
attendedPct  = present / (present + absent)
maxMissable  = max(0, floor(present + remaining - req * total))
// if present + remaining < req * total, the minimum can no longer be reached: show a warning
```
- Cancelled sessions are excluded from all totals.
- Example: present 30, absent 6, remaining 20, req 0.75 → total 56 → maxMissable = floor(50 - 42) = 8.
- Cover this with unit tests, including the "can no longer reach the minimum" case.

### 5.6 Workload heatmap
- Per day: sum `estimateMin` of tasks scheduled/due + class hours; compare to the user's capacity (rules) → color scale (green / amber / red).

---

## 6. Screens and Navigation

**Bottom navigation (5 tabs):** Today · Calendar · **＋** (Quick Add) · Courses · Me/Insights

| Screen | Purpose / key elements |
|---|---|
| **Onboarding** | Pick role → add courses → timetable (manual / photo / import) → reminder permissions → choose AI autonomy |
| **Today** | "Next up" card, overdue, today's classes + tasks on a timeline toggle, AI plan banner, habits row |
| **Quick Add sheet** | Text field with live parse chips, voice button, camera button, course/date/priority shortcuts |
| **Inbox** | Unsorted captures with swipe-to-schedule |
| **Upcoming** | Grouped by day with load indicators |
| **Calendar** | Day / week / month; classes, exams, tasks, plan blocks; drag to reschedule |
| **Timeline (day)** | Visual day with now-line, durations, transitions |
| **Course page** | Tabs: Tasks · Schedule · Exams · Notes/Files · Grades · Attendance |
| **Task detail** | All fields, subtasks, reminders, notes, attachments, focus button, activity |
| **AI Plan review** | Proposed blocks with reasons, accept/edit/reject, diff view |
| **Exam planner** | Topics with confidence, revision schedule, progress |
| **Focus screen** | Timer, current task, ambient sound, "just 5 minutes" |
| **Habits** | List, streaks, calendar heat |
| **Boards (shared)** | Kanban, members, comments, invite link |
| **Weekly review** | Stats, wins, carry-overs, next-week preview |
| **Search** | Global results grouped by type |
| **Settings** | Account, rules, notifications health, themes, accessibility, privacy, import/export |

**Navigation rules:** Quick Add is reachable from *every* screen (global). Back gesture always works. Every destructive action is undoable.

---

## 7. AI Features: Specification and Guardrails

### Use of AI (keep scope tight)
| Use | Model job | Output |
|---|---|---|
| NL parsing fallback | Parse complex phrases the rule-based parser missed | JSON task fields |
| Voice brain-dump | Split speech into tasks | JSON array of tasks |
| Photo / PDF extraction | Extract deadlines, classes, topics | JSON with confidence per field |
| Task breakdown | Propose milestones | JSON milestones with relative deadlines |
| Plan explanations | Turn scoring data into a readable reason | Short text |
| Exam plan | Draft topic order and revision cadence | JSON schedule (validated by code) |
| Tiny first step | Suggest the smallest start | One sentence |

### Guardrails
1. **Structured output only**: AI returns JSON validated against a schema; invalid output is discarded and retried once, then falls back to manual.
2. **Never auto-commit** dates or tasks from AI extraction without a review screen (unless autonomy = Auto for rescheduling only).
3. **Deterministic placement**: scheduling logic is code; AI never decides raw time slots.
4. **Explainability**: every AI-created or AI-moved item stores a `reason`.
5. **Undo everywhere**: AI actions are logged and reversible.
6. **Privacy**: send only the minimum fields needed; show users what is sent; no training on user content; allow AI to be fully disabled.
7. **Cost and abuse controls**: per-user rate limits; cache repeated requests; graceful degradation when quota is hit.
8. **Provider-agnostic**: put the LLM behind an interface so models can be swapped.

---

## 8. Non-Functional Requirements

| Area | Target |
|---|---|
| **Cold start** | < 2 s on a mid-range Android phone |
| **Quick Add** | ≤ 3 s from tap to saved |
| **List performance** | 60 fps scrolling with 10,000 tasks |
| **Local search** | < 150 ms |
| **Sync latency (online)** | < 5 s for a change to appear on another device |
| **Offline** | 100% of core features work offline (AI and collaboration degrade gracefully) |
| **Reminder accuracy** | ±1 min on healthy devices |
| **Battery** | No wakelocks beyond active focus sessions; batch background sync |
| **Security** | TLS everywhere; encryption at rest for server data; hashed credentials; short-lived tokens with refresh; server-side authorization for every shared resource; rate limiting |
| **Privacy and compliance** | Data export, account deletion, clear consent for AI/analytics; follow applicable regional privacy law |
| **Accessibility** | WCAG 2.1 AA; screen reader; dynamic type; reduced motion |
| **Reliability** | Crash-free sessions ≥ 99.5%; automatic local backup before schema migrations |
| **Testing** | Unit tests for parser, recurrence, scheduler, attendance, sync merge; integration tests for reminders; golden tests for key UI |

---

## 9. Suggested Tech Stack and Architecture

### Mobile app (primary)
- **Flutter** (Android first, iOS next) with a clean architecture (feature folders: `capture/`, `tasks/`, `academic/`, `planning/`, `focus/`, `collab/`, `insights/`, `settings/`)
- **State management:** Riverpod (or Bloc)
- **Local database:** SQLite via **Drift** (type-safe queries, migrations, FTS5 for search)
- **Notifications:** `flutter_local_notifications` + native exact-alarm handling; WorkManager for background sync and reminder re-registration
- **Widgets:** Android home-screen widgets (e.g. `home_widget`)
- **Design:** Material 3 with an expressive, calm style; Framer-like motion through Flutter implicit/explicit animations (keep it subtle and fast)

### Backend
- **NestJS + TypeScript**, **PostgreSQL** (primary data), **Redis** (queues, rate limits, caching)
- API: REST or GraphQL (GraphQL fits well for shared boards and sync deltas); WebSocket/SSE for live collaboration updates
- **Sync service:** receives operation logs, applies field-level merges, returns deltas since a cursor
- **Object storage:** S3-compatible for attachments with signed URLs
- **Auth:** email + Google + Apple sign-in; JWT access + refresh tokens
- **AI service:** thin module that wraps the LLM provider (e.g. Gemini or Claude) with schema validation, caching, rate limiting
- **Deployment:** Docker containers; start simple (single region), add observability (logs, metrics, tracing, crash reporting)

### Web companion (later)
- **Next.js + TypeScript + Tailwind** consuming the same API, for guest board links and a desktop planning view.

### Repo layout (monorepo suggestion)
```
/apps/mobile      (Flutter)
/apps/web         (Next.js)
/services/api     (NestJS)
/packages/schema  (shared JSON schemas / API contracts)
/docs             (this spec, ADRs)
```

---

## 10. Analytics and Success Metrics

*(Privacy-respecting, opt-out available.)*

| Metric | Target idea |
|---|---|
| Time-to-first-task | < 60 s from install |
| Quick-add median time | ≤ 3 s |
| Day-7 / Day-30 retention | Track and improve cohort over cohort |
| % of days with ≥ 1 completed task (active users) | Rising trend |
| AI plan acceptance rate | > 60% accepted with ≤ 2 edits |
| Reminder reliability | > 99% delivered on time (device-reported) |
| Missed-deadline rate | Decreasing for users with AI plan on |
| Crash-free sessions | ≥ 99.5% |

---

## 11. Edge Cases Checklist

- [ ] Time zone change or travel: tasks keep intended local time; reminders re-scheduled
- [ ] Daylight saving shifts around recurring tasks and reminders
- [ ] Device clock manually changed
- [ ] Notification permission denied / exact alarms denied / battery optimization kills reminders
- [ ] Same task edited offline on two devices
- [ ] Completing a recurring task twice from two devices
- [ ] Deleting a course that has tasks, exams, sessions and grades (offer: archive / move / delete all)
- [ ] Semester rollover: archive old courses, carry over unfinished tasks
- [ ] Task with a due date but no time (all-day) vs. with time
- [ ] Very long titles / emojis / right-to-left languages / mixed-language input
- [ ] Voice or photo extraction returns wrong dates → always requires confirmation
- [ ] Removing a member from a shared board mid-edit
- [ ] Large attachments on poor networks (resumable uploads, clear limits)
- [ ] Rotating timetable weeks around holidays
- [ ] User downgrades from Pro: AI features pause, data remains intact
- [ ] Account deletion while offline changes are pending
- [ ] Migration failures: auto-backup and safe rollback

---

## 12. Milestones (Build Order)

### M0: Foundations (week 1–2)
Project setup, architecture, design system (colors, type, components), local DB schema and migrations, account scaffolding, CI.
**Done when:** a blank app runs on a device, writes and reads local data, and tests run in CI.

### M1: Core tasks and views (week 3–5)
`CAP-1/2/3`, `TSK-1…7, 13`, `VIEW-1…5, 8, 10`, `SET-1/2/4`.
**Done when:** you can add tasks by typed shorthand in ≤ 3 s, see them in Today/Upcoming/Calendar, complete with undo, and search them, all offline.

### M2: Reminders and recurrence (week 6–7)
`REM-1/2/3/9`, `TSK-5`, local notification scheduling, reboot/time zone re-registration.
**Done when:** reminders fire reliably on test devices (including after reboot and with battery saver on) and recurring tasks behave correctly across DST.

### M3: Sync and accounts (week 8–10)
`SYN-1…4, 7, 11`, `SET-5`.
**Done when:** two devices converge after offline edits; export, backup and restore work.

### M4: Academic module (week 11–14)
`ACA-1…5`, `ACA-6…9`, `REM-5`, onboarding (`SET-8`), class reminders with attendance action.
**Done when:** a new student can set up courses and a rotating timetable in under 3 minutes and see classes, exams and attendance math.

### M5: Focus, habits, notes (week 15–17)
`FOC-1/2/5`, `HAB-1/2/3`, `NOTE-1/2/3`, `VIEW-6/7/9`, widgets `SET-3`.
**Done when:** focus sessions survive backgrounding, habits keep forgiving streaks, widgets update.

### M6: Smart planning (week 18–21)
`PLAN-1…10, 12`, `CAP-4/6/7/9`, AI service with schema validation and guardrails.
**Done when:** the morning plan is generated in < 5 s, every block has a reason, the autonomy dial works, and exam mode produces a valid revision schedule.

### M7: Collaboration (week 22–24)
`COL-1…4, 8`, guest web view, invite links.
**Done when:** a group can share a board via link and a guest can view without installing.

### M8: Insights and polish (week 25–27)
`INS-1…3`, `PLAN-11`, `ACA-8` grades/GPA polish, `SYN-5/6`, performance and accessibility pass, beta testing.
**Done when:** non-functional targets in Section 8 are met on mid-range devices.

### M9: Launch
Pricing tiers (`MON-1…5`), store listings, privacy policy, crash/analytics dashboards, feedback loop, staged rollout.

> **Cut line if time is short:** ship M0–M4 plus Focus (`FOC-1`) and the rule-based Today ranking. That alone is a better student task manager than most apps on the market. Add AI after the basics are trusted.

---

## 13. Starter Prompts for Coding Agents

**Project kickoff prompt**
```
You are building "Orbit", an offline-first student task manager in Flutter (Android first)
with a NestJS + PostgreSQL backend. Read /docs/ultimate-task-manager-app-spec.md fully.
Start with Milestone M0. Create the folder structure from Section 9, set up Drift with the
core entities from Section 4, a Material 3 theme, and CI. Write unit tests for every
non-trivial function. Do not implement features from later milestones.
```

**Per-feature prompt template**
```
Implement feature <ID> from the spec exactly as written, including every acceptance
criterion. List the files you will change before editing. Add unit/widget tests that
prove each AC. If an AC is ambiguous, ask me before assuming.
```

**Review prompt**
```
Review the implementation of <ID> against its acceptance criteria and the edge-case
checklist in Section 11. List gaps, risks and missing tests. Do not rewrite working code.
```

---

*Guiding rule for every decision: **Does this help a student know what to do next, trust that they won't miss a deadline, and do it with less effort?** If not, it doesn't ship.*

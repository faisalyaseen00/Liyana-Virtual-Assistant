# Liyana — Features and Implementation Roadmap

Last updated: 2026-11-23

This document has three parts:

1. **Feature list**: every feature the project has or is clearly meant to have, with its real status as of today, checked against the code.
2. **What has been implemented, and how**: every feature and fix built so far, how it works, where the code lives, and which tests cover it.
3. **Implementation guide**: for every feature that isn't finished, how to build it properly: which files to touch, data models, endpoints, packages, and how to know it's done.

Status key:

| Status | Meaning |
|---|---|
| ✅ Done | Works end to end (backend + app) and has tests |
| 🟡 Partial | Some layers exist, but a user can't fully use it yet |
| 🔴 Not started | No real code yet (there may be a placeholder screen) |

---

# Part 1 — Feature list

## Core

| # | Feature | Status | Where it stands |
|---|---|---|---|
| 1 | Sign up / log in / log out | ✅ Done | Register and login screens, JWT access + refresh tokens, logout revokes the session immediately |
| 2 | Automatic token refresh | ✅ Done | `AuthInterceptor` refreshes on 401 and retries once; a dead session returns you to login |
| 3 | AI chat (conversation) | ✅ Done | Groq model with the Liyana system prompt and today's date |
| 4 | AI semantic router | ✅ Done | Picks `tool` / `conversation` / `clarification` for each message |
| 5 | Tasks | ✅ Done | Saved in Postgres; created from chat or the Tasks tab; complete and delete in the app |
| 6 | Reminders | ✅ Done | Saved from chat or the Reminders tab; Upcoming and Done lists; the chat can also list them |
| 7 | Reminder notifications | 🟡 Partial | Built and unit-tested (local notifications on Android, iOS and macOS), but **not yet tested on a real phone** |
| 8 | Chat history | ✅ Done | The app reopens your last chat, has a history screen (open, rename, delete), loads long chats in pages, and names chats from their first message |
| 9 | Voice input and spoken replies | 🟡 Partial | Speech-to-text and text-to-speech are wired into the chat screen, but have **never been tested on a real phone** |
| 10 | More AI tools | 🟡 Partial | `create_task`, `get_tasks`, `create_reminder`, `list_reminders`. The AI can't complete or delete tasks, or cancel reminders |

## App screens

| # | Feature | Status | Where it stands |
|---|---|---|---|
| 11 | Dashboard | 🟡 Partial | Real name and task counts. The "AI Agent Status" panel is hard-coded ("Gemini AI", "RAG Engine", ...); none of that is real, and the app actually uses Groq |
| 12 | Alerts tab | 🔴 Not started | The screen exists, but every alert is fake sample data from `AlertProvider.simulateAgentAlert()` |
| 13 | Profile and settings | 🟡 Partial | `GET/PATCH /users/me` exists (name, picture, timezone, language). No screen in the app |
| 14 | Logged-in devices | 🟡 Partial | `/sessions` endpoints list devices and log out other devices. No screen in the app |

## Account and platform

| # | Feature | Status | Where it stands |
|---|---|---|---|
| 15 | User timezone | ✅ Done | The app saves the phone's timezone to the profile; the assistant's dates, "today" and "tomorrow" follow it |
| 16 | Email verification | 🔴 Not started | `users.is_verified` exists but nothing sets it |
| 17 | Password reset / change password | 🔴 Not started | — |
| 18 | Streaming AI replies | 🔴 Not started | The app waits for the whole answer |
| 19 | Google Classroom / calendar integration | 🔴 Not started | Implied by the sample alerts; no code |
| 20 | Background jobs | 🔴 Not started | Needed for notifications by email, Classroom sync, cleanup |
| 21 | Production hardening | 🔴 Not started | CORS allows every origin, no rate limiting, the `SECRET_KEY` in `.env` is 9 characters |
| 22 | Deployment | 🔴 Not started | No backend Docker image or hosting; `docker-compose.yml` only runs Postgres |
| 23 | Release builds of the app | 🔴 Not started | Default icons, no signing, the API URL is hard-coded per platform |
| 24 | Consistent naming | 🟡 Partial | The backend and some code say "Sentinel AI"; the product is "Liyana" |

---

# Part 2 — What has been implemented, and how

This part records every feature and fix that has actually been built, how it works, where the code is, and which tests cover it. It's split into the work done in this round of changes (most of which is not committed yet) and the earlier commit.

**Current test status:** backend 50 tests pass (`cd Backend && venv/bin/python -m pytest`), Flutter 35 tests pass, `flutter analyze` reports no issues, and `flutter build web` compiles the whole app.

## 2.1 Accounts and security

| What | How it was implemented | Where |
|---|---|---|
| **Logout really logs you out** | Every access token carries a `session_id`. `get_current_user` now loads that session and rejects the request with 401 if it's missing, belongs to another user, or was revoked. Before, a logged-out token kept working for up to 30 minutes. | `Backend/app/dependencies/auth.py` |
| **Malformed tokens give 401, not 500** | The `sub` and `session_id` claims are parsed inside `try/except` and turned into "Invalid token." | same file |
| **Sign-up screen** | Full register form (name, email, password, confirm) with the same validation as the backend (8–128 character password). On success it logs straight in and opens the dashboard. Linked from the login screen with "Don't have an account? Sign up". | `mobile_app/lib/features/auth/register_screen.dart`, `login_screen.dart`, `core/routes/app_routes.dart` |
| **Logout button** | Logout icon on the dashboard header with a confirmation dialog. It calls `/auth/logout`, clears stored tokens, clears the task list, and returns to login with the back stack removed. | `features/dashboard/dashboard_screen.dart` |
| **Automatic sign-out when the session dies** | `AuthInterceptor` has a static `onSessionExpired` callback. When refreshing the token fails, it clears tokens and calls it. `main.dart` sets the callback to reset `AuthProvider`/`TaskProvider` and navigate to login through a global `navigatorKey` in `app.dart`. | `core/api/auth_interceptor.dart`, `main.dart`, `app.dart` |
| **No secrets in logs** | Removed the `debugPrint` calls that printed access and refresh tokens. `ApiInterceptor` now logs only in debug builds and never prints request bodies for `/auth/` calls (passwords, refresh tokens). | `features/auth/auth_provider.dart`, `core/api/api_interceptor.dart` |
| **Real error messages** | New `ApiException.fromDio()` turns any Dio error into a readable message: the backend's `detail` string, the first FastAPI validation error (e.g. `password: String should have at least 8 characters`), "Cannot reach the server…" for connection errors, or a timeout message. Used by every service. | `core/api/api_exception.dart` |
| **Real user name on the dashboard** | `AuthProvider.loadProfile()` calls `GET /users/me` after login and on app start, and `displayName` returns the first name, or the email prefix as a fallback. Replaced the hard-coded "Faisal". | `auth_provider.dart`, `auth_service.dart`, `dashboard_screen.dart` |

**Tests:** `Backend/tests/test_security_and_validation.py` (logout revokes the token), `mobile_app/test/api_exception_test.dart`, `mobile_app/test/auth_interceptor_test.dart`.

## 2.2 AI chat

| What | How it was implemented | Where |
|---|---|---|
| **Empty replies fixed** | The configured model (`openai/gpt-oss-20b`) is a reasoning model: it spends tokens thinking before it answers. With the old 300-token limit, long questions used everything on thinking and returned nothing. The limit is now a setting, `GROQ_MAX_COMPLETION_TOKENS` (default 2048), and for `openai/gpt-oss*` models the provider sends `reasoning_effort="low"`. | `Backend/app/providers/grok.py`, `app/core/settings.py` |
| **Never saves an empty answer** | If the model still returns nothing, the assistant replies "Sorry, I couldn't come up with a reply…" instead of storing an empty message. | `app/services/ai_service.py` |
| **Assistant personality and date** | Normal conversation now starts with a system prompt: "You are Liyana, a friendly and helpful personal virtual assistant… Today's date is …". The router prompt also gets today's date, so "tomorrow" and "by Friday" become real dates. | `ai_service.py`, `services/ai/router/semantic_router.py` |
| **Router is more forgiving** | If the model sends `"arguments": null`, it's treated as `{}` instead of failing validation. | `services/ai/router/schemas.py` |
| **Errors are logged** | When a chat request fails, the full error is written to the server log; the app still gets a clean 502 "AI provider is unavailable." | `app/api/v1/chat.py` |
| **Input validation** | Chat and message text must be 1–4000 characters after trimming (blank messages are rejected with 422). Conversation titles must be 1–255 characters; before, a long title crashed the server with a 500. | `app/schemas/chat.py`, `message.py`, `conversation.py` |
| **Message integrity** | Editing or deleting a message through the wrong conversation's URL used to change the message and then return 404. The service now checks the conversation **before** changing anything. | `app/services/message_service.py`, `app/api/v1/message.py` |

**Tests:** `tests/ai/test_conversation_route.py`, `tests/test_security_and_validation.py` (wrong-conversation delete, blank message, long title).

## 2.3 Chat screen and voice (app)

| What | How it was implemented | Where |
|---|---|---|
| **Chat survives tab switches** | The dashboard used to rebuild the selected tab, which destroyed the chat. It now uses an `IndexedStack`, so every tab keeps its state. | `dashboard_screen.dart` |
| **No double sends** | `_sendMessage` returns early while a reply is loading, which also prevents two conversations being created at once. | `features/chat/chat_screen.dart` |
| **Longer timeout for chat** | The chat request uses a 90-second receive timeout (routing + answer can take more than the default 15 s). | `features/chat/chat_service.dart` |
| **Real error text in the chat** | Failed sends show "Sorry, something went wrong: <reason>" instead of always "I could not reach Liyana right now". | `chat_screen.dart` |
| **No crash after leaving the screen** | Every `setState` after an `await` (speaking, listening) checks `mounted` first. | `chat_screen.dart` |
| **Voice failures handled** | `VoiceService.init()` is wrapped in `try/catch` (speech isn't available on every platform). `startListening` returns `false` when speech recognition isn't available, and the screen shows a message. Speech status and error callbacks reset "Listening…" when recognition stops without a result, so the mic no longer gets stuck. | `services/voice_service.dart`, `chat_screen.dart` |
| **Deprecated calls removed** | All `withOpacity(x)` calls replaced with `withValues(alpha: x)`; the analyzer went from 24 issues to 0. | across `lib/` |

**Tests:** `mobile_app/test/chat_service_test.dart`. Voice has **not** been tested on a real device yet.

## 2.4 Tasks and reminders

| What | How it was implemented | Where |
|---|---|---|
| **Database tables** | `Task` (title, description, priority `low`/`medium`/`high`, `due_date`, `is_completed`, `completed_at`, timestamps) and `Reminder` (title, `remind_date`, optional `remind_time`, `is_done`, timestamps). Both have `user_id` with `ON DELETE CASCADE` and an index. Reminder date and time are stored as the user's local date and time, exactly as they said them. | `Backend/app/models/task.py`, `models/reminder.py`, `app/db/models.py` |
| **Migration** | `a7d3e2f41b90_add_tasks_and_reminders.py` on top of `c990c250ad0c`. Tested on a throwaway Postgres 17 container: upgrade → downgrade → upgrade, and Alembic's compare found no difference between the tables and the models. **Not yet applied to Neon**: run `cd Backend && venv/bin/alembic upgrade head`. | `Backend/alembic/versions/` |
| **REST API** | `GET/POST /api/v1/tasks`, `GET/PATCH/DELETE /api/v1/tasks/{id}`, with `?completed=true|false`. Same shape for `/api/v1/reminders` with `?done=`. `PATCH` changes only the fields that are sent; `null` clears `due_date`/`remind_time`. Marking a task complete sets `completed_at`. Every query filters by the current user; another user's id returns 404. | `app/api/v1/tasks.py`, `reminders.py`, `schemas/task.py`, `schemas/reminder.py`, `repositories/task_repository.py`, `repositories/reminder_repository.py` |
| **One service for API and AI** | `TaskService(db, user_id, tz)` and `ReminderService(db, user_id, tz)` hold the logic for both the REST endpoints and the AI tools, so the rules are the same either way. | `app/services/task_service.py`, `reminder_service.py` |
| **AI tools save real rows** | `ToolExecutor.for_user(db, user_id, tz)` builds the tools for the user who is chatting. `ChatService` creates one per request. `create_task`, `get_tasks` (open tasks only) and `create_reminder` now read and write the database instead of echoing their input. | `services/ai/tools/executor.py`, `services/chat_service.py` |
| **Understanding dates and times** | `parse_date` accepts `YYYY-MM-DD`, "today" and "tomorrow"; `parse_time` accepts `17:00`, `5pm`, `5:30 PM`, `12am`. Anything else raises `ValueError`, which `ChatService` turns into "Could you give me a few more details?". Nothing is saved with a wrong date. The tool descriptions tell the model the expected formats. | `app/utils/dates.py`, `services/ai/tools/defination.py` |
| **App Tasks tab uses the server** | `TaskService` (Dio) + `TaskProvider` load, add, complete and delete through the API. Changes show immediately and are rolled back with an error message if the server refuses. Pull-to-refresh, a loading spinner, and a retry screen when loading fails. The add sheet waits for the server before closing. | `mobile_app/lib/features/tasks/` |
| **Chat and Tasks stay in sync** | The chat message model reads `extra_data.tool`. When a reply ran `create_task`, the chat screen reloads the task list, so the Tasks tab and dashboard counts update. | `features/chat/chat_model.dart`, `chat_screen.dart` |
| **Tasks load at sign-in, clear at sign-out** | The dashboard loads tasks when it opens; logout and session expiry call `TaskProvider.clear()` so the next user never sees the previous user's tasks. | `dashboard_screen.dart`, `main.dart` |

**Tests:** `Backend/tests/test_tasks_and_reminders.py` (full API flow, privacy between users, validation), `tests/ai/tools/test_executor.py` (tools write real rows, bad dates are rejected), `tests/ai/test_tool_route.py` (chat → task in database), `mobile_app/test/task_provider_test.dart`, `test/add_task_sheet_test.dart`, with the fake backend in `test/fake_task_backend.dart`.

**Live check (real Groq model):** "add a high priority task to finish the project report by friday" → saved as high priority, due 2026-11-27. "what are my tasks?" lists what the chat created.

## 2.5 User timezone (roadmap Step 1)

| What | How it was implemented | Where |
|---|---|---|
| **Profile only accepts real zones** | `PATCH /users/me` checks `timezone` with Python's `zoneinfo`; unknown names like `Mars/Base` get 422. | `Backend/app/schemas/user.py`, `app/utils/dates.py` (`is_valid_timezone`) |
| **Dates follow the user's clock** | `today_label(tz)`, `local_today(tz)` and `parse_date(value, tz)` use the user's zone. Without a valid zone they fall back to the server's local time. All "now" lookups go through one `_now(tz)` function so tests can freeze the clock. | `app/utils/dates.py` |
| **Timezone passed everywhere it matters** | `ChatService` loads the user's timezone once per message and passes it to the router prompt, the conversation prompt and the tools (`ToolExecutor.for_user(db, user_id, tz)` → `TaskService`/`ReminderService`). | `services/chat_service.py`, `semantic_router.py`, `ai_service.py`, `executor.py` |
| **App sends the phone's timezone** | New `flutter_timezone` package. `deviceTimezone()` returns the IANA name (e.g. `Asia/Karachi`), or `null` on platforms that can't tell. After loading the profile, `AuthProvider` sends `PATCH /users/me` only when the device zone differs from the saved one. The lookup can be swapped in tests. | `mobile_app/lib/core/utils/device_timezone.dart`, `features/auth/auth_provider.dart`, `auth_service.dart` (`updateProfile`) |

**Tests:** `Backend/tests/test_timezone.py` freezes the clock at 20:30 UTC (already the next day in Karachi, still the same day in Los Angeles) and checks "today"/"tomorrow", a reminder created by the AI, and profile validation. `mobile_app/test/timezone_sync_test.dart` checks that the app saves a different zone, skips the call when it already matches, and does nothing when the device zone is unknown.

**Live check:** at the same moment, a Karachi user was told "Monday, 2026-11-23" and a Los Angeles user "Sunday, 2026-11-22"; "tomorrow at 5pm" gave each their own next day.

## 2.6 Reminders screen and notifications (roadmap Step 2)

| What | How it was implemented | Where |
|---|---|---|
| **AI can list reminders** | New `list_reminders` tool (open reminders, soonest first). The chat answers "Here are your upcoming reminders: …" with dates and times. | `Backend/app/services/reminder_service.py` (`get_reminders`), `services/ai/tools/defination.py`, `registery.py`, `executor.py`, `services/chat_service.py` |
| **Reminder data in the app** | `Reminder` model (date + optional `TimeOfDay`, `dueAt`), `ReminderService` for `/reminders` (list, create, mark done, delete), `ReminderProvider` with the same instant-update-and-roll-back behaviour as tasks. | `mobile_app/lib/features/reminders/reminder_model.dart`, `reminder_service.dart`, `reminder_provider.dart` |
| **Reminders tab** | A fifth bottom-nav tab with Upcoming and Done lists. Overdue reminders are shown in red with "Overdue". Tap the circle to mark done, the bin to delete, pull to refresh. The + button opens a sheet with a title, a date picker and an optional time picker. Dates read "Today", "Tomorrow" or e.g. "Fri, 27 Nov". The dashboard's Reminders card (which used to say "Coming soon" and went nowhere) now opens this tab. | `reminders_screen.dart`, `add_reminder_sheet.dart`, `reminder_format.dart`, `features/dashboard/dashboard_screen.dart` |
| **Phone notifications** | `flutter_local_notifications` 22.x schedules **local** notifications, so they fire even when the app is closed or offline, with no push server. The rule: after every load or change, cancel all pending reminder notifications and schedule every open reminder that is still in the future, so the phone always matches the server. A reminder without a time fires at 09:00. At most 50 are scheduled (iOS keeps only 64). Notification ids come from a stable hash of the reminder id. Android uses inexact scheduling, so no "exact alarm" permission is needed (it may arrive a few minutes late). | `lib/services/reminder_notifier.dart` (the rules, testable without a phone), `lib/services/local_reminder_notifier.dart` (the plugin) |
| **Permission asked at the right time** | The notification permission (Android 13+, iOS, macOS) is requested the first time there's something to schedule, not on app start. Web and desktop get a no-op notifier. | `local_reminder_notifier.dart` |
| **Always in sync** | Reminders reload, and notifications are rescheduled, when the dashboard opens, when the app comes back to the foreground, and after the chat runs `create_reminder`. Logout and session expiry clear the list and cancel all notifications. | `dashboard_screen.dart` (`WidgetsBindingObserver`), `chat_screen.dart`, `main.dart` |
| **Platform setup** | Android: core library desugaring + multidex in `build.gradle.kts`, `RECEIVE_BOOT_COMPLETED` permission, and the plugin's two receivers in `AndroidManifest.xml` (so reminders survive a reboot). iOS: notification delegate in `AppDelegate.swift`. | `mobile_app/android/app/`, `mobile_app/ios/Runner/AppDelegate.swift` |
| **Why version 22, not 23** | Version 23 of the plugin needs Android Gradle Plugin 9 and a migration to built-in Kotlin. The project uses AGP 8.11.1, which is exactly what 22.x targets, so 22.x avoids a risky build migration. | `mobile_app/pubspec.yaml` |

**Tests:** `Backend/tests/ai/tools/test_executor.py` (`list_reminders`), `mobile_app/test/reminder_notifier_test.dart` (what gets scheduled: future and open only, 09:00 default, the 50 cap, stable ids), `test/reminder_provider_test.dart` (notifications follow add, done, delete, failed delete, logout), `test/reminders_screen_test.dart` (renders the list and adds a reminder through the sheet), with fakes in `test/fake_reminder_backend.dart`.

**Not verified yet:** this machine has no Android or iOS build tools, so the Android Gradle changes, the iOS change and real notifications haven't been run on a device. To test: `flutter run` on a phone, create a reminder two minutes ahead, close the app, and wait.

## 2.7 Chat history (roadmap Step 3)

| What | How it was implemented | Where |
|---|---|---|
| **Automatic chat titles** | After the first exchange, a conversation still called "New Conversation" is renamed from the first message: its first 6 words (at most 60 characters), first letter capitalised, trailing punctuation removed, and "…" when shortened. For example: "Remind me to call mom tomorrow…". It's done in code, not with an extra AI call, so it costs nothing and never fails. A title the user chose is never overwritten. | `Backend/app/services/conversation_service.py` (`title_from_message`, `set_title_from_first_message`), `services/chat_service.py` |
| **One default title** | The model said "New Chat" while the service said "New Conversation". Both now use `DEFAULT_TITLE = "New Conversation"`; old "New Chat" rows are still treated as untitled. | `app/models/conversation.py`, `repositories/conversation_repository.py` |
| **Paging long chats** | `GET /conversations/{id}/messages?limit=50` returns the newest 50 messages (oldest first); `&before=<message id>` gives the 50 before that. Without `limit` it still returns everything, so older clients keep working. `limit` must be 1–200; a `before` id from another conversation returns 404. | `app/repositories/message_repository.py`, `services/message_service.py`, `api/v1/message.py` |
| **Chat state lives in a provider** | `ChatProvider` holds the open conversation, its messages, the paging state and the history list, so the chat survives leaving the screen. The chat screen now only handles input, voice and scrolling. | `mobile_app/lib/features/chat/chat_provider.dart`, `chat_screen.dart` |
| **Reopens your last chat** | At sign-in the dashboard loads the history and opens the most recent conversation. | `features/dashboard/dashboard_screen.dart` (`openLatest`) |
| **History screen** | The history icon in the chat's top bar opens a list of chats, newest first, with times like "14:05", "Yesterday" or "4 Mar". Tap to open, long-press to rename, swipe left to delete (with confirmation). The open chat is highlighted. | `features/chat/conversations_screen.dart`, `conversation_service.dart`, `conversation_model.dart` |
| **New chat** | The "new chat" button clears the screen; the conversation is only created on the server with the first message, so empty chats don't pile up in the history. | `chat_provider.dart` (`startNewConversation`) |
| **Earlier messages** | Long chats open on their newest 50 messages, with a "Load earlier messages" button at the top. The screen scrolls to the newest message when you open a chat or a reply arrives, but not when older messages are added on top. | `chat_screen.dart` |
| **Sending is safer** | Your message shows straight away and is replaced by the saved copy when the reply arrives. If sending fails, your text stays and a red error reply appears (it isn't saved on the server). If you switch chats while a reply is on its way, it's still saved but doesn't appear in the chat you switched to. | `chat_provider.dart` (`sendMessage`), `chat_bubble.dart` (`isError`), `chat_model.dart` (`ChatMessage.local`) |
| **Logout** | Logout and session expiry clear the history and the open chat. | `main.dart`, `dashboard_screen.dart` |

**Tests:** `Backend/tests/test_chat_history.py` (title rules, first message names the chat, a user's title is kept, paging forwards and back, bad `limit`/`before`), `mobile_app/test/chat_provider_test.dart` (reopen latest, empty start, paging, first message creates the chat, switching chats, failed send, rename and delete, logout), `test/conversations_screen_test.dart` (list renders and tap opens a chat; time formatting), with the fake backend in `test/fake_chat_backend.dart`.

**Live check (real Groq model):** two new chats were named "How do I make a good…" and "Remind me to call mom tomorrow…", and `?limit=1` returned only the newest message.

## 2.8 Environment and setup

| What | How it was implemented | Where |
|---|---|---|
| **`.env` checked** | Settings load; the Neon database connects; the Groq key returns 200; migrations were at head. `.env.example` only shows as changed because its line endings became Windows-style (CRLF). | `Backend/.env`, `Backend/app/core/settings.py` |
| **Python 3.10 compatibility** | The venv is Python 3.10, but 10 files used `from datetime import UTC` (3.11+), which crashed the app at startup. Replaced with `timezone.utc` in every file. | models, repositories, services, `utils/jwt.py`, `api/v1/health.py`, `dependencies/session.py` |

## 2.9 Earlier commit (`7fe50d1`, before this round)

Already committed on this branch:
- The router runs tools on the `tool` route (instead of returning 502), asks for details when arguments are missing, reads JSON wrapped in text or code fences, and falls back to normal conversation when the reply is unusable.
- Migration fixes: no duplicate column drops, defaults for the new timezone and language columns, and the `message_role` enum is dropped on downgrade.
- `Message.extra_data` uses JSONB on Postgres and JSON on SQLite so tests can create it.
- App: token refresh keeps the existing refresh token and retries the request once; fixed the Add Task sheet crash; per-platform API URL (`10.0.2.2` on the Android emulator) with an `API_BASE_URL` override; Android cleartext HTTP in debug builds only; microphone, speech and network permissions for iOS and macOS.

---

# Part 3 — How to implement each feature properly

The order below is the recommended build order. Each step builds on the one before it.

## General rules for every feature

These match how the project is already built; keep following them.

**Backend (`Backend/app/`)**
- Layers: `api/v1/<feature>.py` → `services/<feature>_service.py` → `repositories/<feature>_repository.py` → `models/<feature>.py`. Request and response shapes go in `schemas/<feature>.py`.
- Every query that reads user data filters by `user_id`. Another user's item returns **404**, never 403, so ids can't be probed.
- Register new models in `app/db/models.py`, then write an Alembic migration in `alembic/versions/`. Test it with `upgrade` → `downgrade` → `upgrade`.
- The venv is Python 3.10: use `timezone.utc`, not `datetime.UTC`.
- Tests run on SQLite (`tests/conftest.py`), so use column types that work on both databases (see `Message.extra_data`).
- Every endpoint gets tests: the normal flow, validation errors, and "another user can't see it".

**App (`mobile_app/lib/`)**
- One folder per feature in `features/<feature>/` containing `<feature>_model.dart`, `<feature>_service.dart` (Dio calls), `<feature>_provider.dart` (state) and the screens.
- Services take an optional `Dio? client` so tests can pass a fake backend (see `test/fake_task_backend.dart`).
- Convert errors with `ApiException.fromDio(...)` so users see the server's real message.
- Providers expose `isLoading` and `errorMessage`, and have a `clear()` that is called on logout (in `dashboard_screen.dart` and `main.dart`).

---

## Step 1 — Use the user's real timezone (feature 15) — ✅ Done

Implemented as described below; see Part 2.5 for exactly how it was built.

**Why first:** reminders, notifications and "today/tomorrow" all depend on it. Today the server's clock decides the date, which breaks as soon as the backend runs somewhere else.

**App**
1. Add the `flutter_timezone` package. It returns the device's IANA zone, such as `Asia/Karachi`.
2. After login (in `AuthProvider.loadProfile()`), if the profile's timezone differs from the device's, send `PATCH /users/me {"timezone": "<iana name>"}`.

**Backend**
1. In `schemas/user.py`, validate `timezone` with `zoneinfo.ZoneInfo(value)` and reject unknown names with 422.
2. Change `app/utils/dates.py` so `today_label(tz)` and `local_today(tz)` take the user's timezone: `datetime.now(ZoneInfo(tz))`.
3. Pass the user's timezone into `AIService`, `SemanticRouter` and `TaskService`/`ReminderService`. `ChatService.send_message` already has `user_id`, so load the user once there.

**Done when:** with the server in UTC and the phone in `Asia/Karachi`, "remind me tomorrow" after midnight local time picks the right date. Add a test that freezes the time.

---

## Step 2 — Reminders screen and notifications (features 6 and 7) — ✅ Built (device test pending)

Implemented as described below; see Part 2.6 for exactly how it was built.

**Approach:** schedule **local notifications on the phone**. The app already downloads reminders, and local notifications fire even when the app is closed or offline, with no push server to build. Server push (FCM) can come later if reminders must reach several devices.

**Backend**
1. Add an AI tool `list_reminders` (open reminders) and a `get_reminders` handler in `ReminderService`, the same way `get_tasks` works.
2. Optionally add `?from=YYYY-MM-DD&to=YYYY-MM-DD` filters to `GET /reminders`.

**App**
1. `features/reminders/`: `reminder_model.dart`, `reminder_service.dart` (`/reminders` CRUD), `reminder_provider.dart`. Copy the structure of `features/tasks/`.
2. `reminders_screen.dart`: an Upcoming list and a Done list, an add sheet with date and time pickers, swipe to delete, tap to mark done. Add it as a tab or as a section on the dashboard.
3. Notifications:
   - Add `flutter_local_notifications` and `timezone`. Call `tz.initializeTimeZones()` and set the local zone from `flutter_timezone` in `main()`.
   - Add a `NotificationService` with `scheduleReminder(Reminder r)` and `cancelReminder(String id)`. Use `zonedSchedule` with `androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle`, which needs no exact-alarm permission.
   - The notification id must be stable per reminder, e.g. `reminder.id.hashCode`.
   - Reminders without a time: notify at a default hour, e.g. 09:00.
4. Sync rule: after every `loadReminders()`, cancel all scheduled reminder notifications, then schedule every reminder that is not done and still in the future. This keeps the phone in step with reminders the chat created.
5. Call `loadReminders()` on app start, after a chat reply whose `tool == 'create_reminder'` (like `create_task` today), and when the app comes back to the foreground.
6. Permissions:
   - Android 13+ needs `POST_NOTIFICATIONS`; ask with `requestNotificationsPermission()`.
   - iOS: request alert, sound and badge permission.
   - Add the receivers from the package README to `AndroidManifest.xml` so notifications survive a reboot.
7. On logout, cancel all notifications and call `ReminderProvider.clear()`.

**Done when:** a reminder created by chat for two minutes from now shows a notification with the app closed. Marking it done or deleting it cancels the notification. Unit-test the provider with a fake backend and a fake `NotificationService`.

---

## Step 3 — Chat history (feature 8) — ✅ Done

Implemented as described below; see Part 2.7 for exactly how it was built. Titles come from the first message's words rather than an AI call.

**Backend** (mostly done)
1. Automatic titles: after the first exchange in a conversation still titled `"New Conversation"`, set the title to the first ~6 words of the user's message, or make a short LLM call. Do this in `ChatService.send_message`.
2. Add pagination to `GET /conversations/{id}/messages` (`?before=<message_id>&limit=50`) so long chats load in pages.

**App**
1. `features/chat/conversation_service.dart`: `listConversations()`, `getMessages(id)`, `rename(id, title)`, `delete(id)`.
2. `conversations_screen.dart`: newest first, showing title and time; tap to open, swipe to delete, long-press to rename; a "New chat" button.
3. Make `ChatScreen` take an optional `conversationId`. When given, load the messages and show them.
4. Replace `List<Map<String, String>>` in `chat_screen.dart` with `ChatMessage` objects. The chat state could move into a `ChatProvider` so it survives screen changes.
5. Open the most recent conversation by default in the AI Chat tab, with a history button in the app bar.

**Done when:** you close the app, reopen it and see the previous chat; switching between two conversations shows the right messages.

---

## Step 4 — More AI tools (feature 10)

**Goal:** everything you can do on the Tasks and Reminders screens can also be done by talking.

1. New tool definitions in `services/ai/tools/defination.py`, each registered in `registery.py` and mapped in `ToolExecutor.for_user()`:
   - `complete_task(title)`, `delete_task(title)`, `update_task(title, new_title?, due_date?, priority?)`
   - `list_reminders()`, `cancel_reminder(title)`
2. **Finding the item:** the AI only knows titles, not ids.
   - Add `TaskRepository.find_open_by_title(user_id, text)`: an exact match ignoring case first, then a "contains" match.
   - If exactly one item matches, act on it.
   - If several match, raise a dedicated `AmbiguousToolTarget` exception listing the options. `ChatService._run_tool` turns it into "Which one do you mean: A or B?"
   - If none match, reply "I couldn't find a task called …".
3. **Destructive actions:** for `delete_task` and `cancel_reminder`, store a pending action in the assistant message's `extra_data`, ask "Delete 'Buy milk'?", and only delete when the next user message is a yes. This needs a check in `ChatService` before routing.
4. Add a reply sentence for every tool in `ChatService._describe_tool_result`.
5. Add each new tool to the app's refresh check (`tool == 'create_task'` → any task or reminder tool).

**Done when:** "mark buy milk as done", "what reminders do I have?" and "delete the report task" (with confirmation) all work, with a test per tool and for the "several matches" case.

---

## Step 5 — Real Alerts tab and dashboard (features 11 and 12)

**Approach:** work out alerts from real data instead of storing fake ones.

**Backend**
1. `GET /api/v1/alerts` (`services/alert_service.py`) returns a list built on request from:
   - overdue open tasks → type `urgent`
   - tasks due today or tomorrow → `deadline`
   - reminders in the next 24 hours → `reminder`
2. Each alert gets a stable id such as `task-overdue:<task_id>`, plus `title`, `description`, `type` and `due_at`.
3. Read state: a small `alert_reads` table (`user_id`, `alert_id`, `read_at`) and `POST /alerts/{id}/read`, `POST /alerts/read-all`.
4. `GET /api/v1/dashboard/summary`: task counts, the next reminder, overdue count and the AI provider status (call Groq's model list with a timeout and cache it for 60 seconds).

**App**
1. Rewrite `AlertProvider` to load from `/alerts`. Delete `simulateAgentAlert()` and the fake Classroom texts.
2. Replace the hard-coded "AI Agent Status" list in `dashboard_screen.dart` with `/dashboard/summary` data. Show only real items: AI model and status, number of reminders scheduled, last sync time.

**Done when:** an overdue task shows as an urgent alert, marking it read clears the badge after a restart, and nothing on the dashboard is fake.

---

## Step 6 — Profile, settings and devices screens (features 13 and 14)

**Backend**
1. `POST /users/me/password` with `{current_password, new_password}`: check the current password, save the new hash, and **revoke all other sessions**.
2. Profile pictures: either keep `profile_picture` as a URL, or add `POST /users/me/avatar` that stores the file (S3-compatible storage or Cloudinary) and saves its URL. Check the type (png/jpeg) and size (≤ 2 MB).

**App**
1. `features/profile/profile_screen.dart`: name, email (read-only), language, timezone (filled in automatically from Step 1), and a change-password form.
2. `features/profile/devices_screen.dart`: list `GET /sessions/` with "This device" marked using `is_current`, a "Log out" button per device (`DELETE /sessions/{id}`), and "Log out all other devices" (`DELETE /sessions/`).
3. Open both from a settings icon on the dashboard header, next to the logout button.

**Done when:** you can rename yourself and see the dashboard greeting change, and logging out another device makes that device return to the login screen on its next request.

---

## Step 7 — Streaming replies (feature 18)

**Backend**
1. Add `POST /conversations/{id}/chat/stream` returning a `StreamingResponse` with `text/event-stream`.
2. Run the router first (not streamed). Tool and clarification routes send their whole reply as one event. The conversation route calls Groq with `stream=True` and sends each piece as `data: {"delta": "..."}`.
3. Save the user message first, collect the streamed text, and save the assistant message at the end. Then send `data: {"done": true, "message": <MessageResponse>}`.
4. If the client disconnects partway, still save what was generated.

**App**
1. In `ChatService` add `sendMessageStream()` using `Dio` with `ResponseType.stream`; split the bytes into lines and read the `data:` lines.
2. Add an empty assistant bubble and append each delta to it. Speak the reply only after `done`.

**Done when:** long answers appear word by word, and the saved message matches what was shown.

---

## Step 8 — Background jobs (feature 20)

Needed for Steps 9 and 10 (emails, Classroom sync).

1. Start simple: **APScheduler** inside the FastAPI process (`AsyncIOScheduler`, started in a lifespan handler in `main.py`). It's enough for one server.
2. When the backend runs as more than one copy, move to **arq** or **Celery** with Redis. The `redis` service is already sketched in `Backend/docker-compose.yml`.
3. First jobs:
   - delete expired and revoked sessions older than 30 days
   - (Step 10) sync Google Classroom every 30 minutes

---

## Step 9 — Email verification and password reset (features 16 and 17)

**Backend**
1. Email sending: an `EmailService` using SMTP or a provider such as Resend, Postmark or SendGrid. Settings go in `Settings` and `.env.example`. In tests, use a fake that records sent emails.
2. A `one_time_tokens` table: `id`, `user_id`, `purpose` (`verify_email` | `reset_password`), `token_hash` (SHA-256 like refresh tokens), `expires_at`, `used_at`.
3. Endpoints:
   - `POST /auth/verify-email/send` (logged in) → email with a code or link
   - `POST /auth/verify-email` `{token}` → sets `is_verified = true`
   - `POST /auth/forgot-password` `{email}` → **always returns 200**, so it can't be used to find out which emails are registered
   - `POST /auth/reset-password` `{token, new_password}` → new hash, token marked used, **every session revoked**
4. Limit how often these can be requested (see Step 11).

**App**
- "Forgot password?" on the login screen leads to an email form and then a code + new password form.
- A "Verify your email" banner on the dashboard while `is_verified` is false.

**Done when:** tests cover token expiry, reuse of a token, the unknown-email case, and sessions being revoked after a reset.

---

## Step 10 — Google Classroom integration (feature 19)

Only if this is really part of the product. It is the largest item.

1. **Google Cloud setup:** create a project, an OAuth consent screen and client ids (Android, iOS, Web). The Classroom scopes `classroom.courses.readonly` and `classroom.coursework.me.readonly` are sensitive, so a public release needs Google's app verification.
2. **App:** use `google_sign_in` with those scopes and `serverClientId`, get the **server auth code**, and send it to `POST /integrations/google/connect`.
3. **Backend:**
   - Exchange the code for tokens and store the **refresh token encrypted** (a `cryptography.fernet` key in settings) in an `integrations` table (`user_id`, `provider`, `encrypted_refresh_token`, `last_synced_at`).
   - A sync job (Step 8) lists courses and course work and creates or updates Tasks with `source="google_classroom"` and `external_id=<courseWork id>`. Add these two columns plus a unique index on `(user_id, source, external_id)` so syncing never creates duplicates.
   - Due dates come in UTC; convert them with the user's timezone.
   - `DELETE /integrations/google` to disconnect: revoke the token at Google and delete the row.
4. Classroom tasks then show up in the Tasks tab, Alerts (Step 5) and reminders automatically.

**Done when:** connecting an account imports assignments once, running the sync again creates no duplicates, and disconnecting stops syncing.

---

## Step 11 — Production hardening (feature 21)

1. **Secret key:** generate a long one (`python3 -c "import secrets; print(secrets.token_urlsafe(48))"`). In `Settings`, refuse to start when `app_env == "production"` and the key is shorter than 32 characters.
2. **CORS:** replace `allow_origins=["*"]` in `main.py` with a `cors_origins` list from settings. The mobile app doesn't need CORS; only a web build does.
3. **Rate limiting:** use `slowapi`, e.g. login 5/minute per IP + email, register 3/minute, chat 20/minute per user (it costs Groq tokens).
4. **Debug off:** in production set `DEBUG=false`, and hide `/docs` unless enabled.
5. **Logging:** structured logs with a request id; never log tokens, passwords or message content.
6. **Login attempts:** consider locking an account for a while after repeated failures.
7. **Python version:** rebuild the venv with Python 3.11+ (`python3.11` is installed) to match production.

---

## Step 12 — Deployment (feature 22)

1. `Backend/Dockerfile`: a `python:3.11-slim` image that installs `requirements.txt`, copies `app/`, `alembic/` and `alembic.ini`, and runs `gunicorn -k uvicorn.workers.UvicornWorker app.main:app --workers 2 --bind 0.0.0.0:8000`.
2. Run migrations at release time: `alembic upgrade head` as a release step, not inside every worker.
3. Hosting: Render, Railway or Fly.io work well with the Neon database you already have. Set secrets in the host's dashboard; never bake `.env` into the image.
4. HTTPS is required. The app should only use `https://` outside debug builds; cleartext is already limited to debug builds on Android.
5. A health check on `/api/v1/health`.
6. Add the backend service to the root `docker-compose.yml` for local full-stack runs.

---

## Step 13 — Release builds of the app (feature 23)

1. Production API URL: build with `--dart-define=API_BASE_URL=https://<your-api>/api/v1` (already supported by `AppConstants.apiBaseUrl`).
2. Icons and splash: `flutter_launcher_icons` and `flutter_native_splash` with the Liyana logo.
3. Names: set the app name to "Liyana" in `AndroidManifest.xml` and `Info.plist`, and change the `pubspec.yaml` description.
4. Android signing: create an upload keystore, add `key.properties` (git-ignored), set `signingConfigs` in `build.gradle`, and build an `appbundle`.
5. iOS: a bundle id, signing team, and a privacy description for every permission used (microphone, speech and notifications are partly added already).
6. Test on a real phone before release. Run the backend with `--host 0.0.0.0` and the app with `API_BASE_URL=http://<your-PC-LAN-IP>:8000/api/v1`, then check voice input, spoken replies and notifications (feature 9).

---

## Step 14 — Consistent naming (feature 24)

Small cleanup that can go into any of the steps above:
- Backend: `Settings.app_name`, `FastAPI(title=...)`, `.env.example` (`APP_NAME`), the Postgres container name in `Backend/docker-compose.yml`.
- App: `SentinelApp` in `app.dart` → `LiyanaApp`.
- Docs: `CURRENT_PROJECT_STATE.md` is out of date (it still says tasks aren't wired and lists files that no longer exist). Update it or replace it with this file.

---

## Summary of the build order

| Order | Step | Main result |
|---|---|---|
| 1 | Timezone ✅ | Dates are right for each user |
| 2 | Reminders screen + notifications ✅ | Reminders actually remind |
| 3 | Chat history ✅ | Conversations survive restarts |
| 4 | More AI tools | Everything can be done by chat |
| 5 | Real alerts + dashboard | No fake data left in the app |
| 6 | Profile, password, devices | Account management |
| 7 | Streaming | Faster-feeling chat |
| 8 | Background jobs | Base for 9 and 10 |
| 9 | Email verify + reset | Account recovery |
| 10 | Google Classroom | External data (optional) |
| 11 | Hardening | Safe to expose publicly |
| 12 | Deployment | Running online |
| 13 | Release builds | Installable app |
| 14 | Naming cleanup | One consistent product name |

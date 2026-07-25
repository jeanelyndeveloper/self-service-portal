# I-Reach Self-Service Portal — Work Plan & Build Prompt
Derived from the meeting with Sir Eddy (Ipsos NZ)

---

## 1. The three systems involved

| # | System | Base URL (staging) | Purpose | Auth |
|---|--------|--------------------|---------|------|
| 1 | **SM API** | `https://smstg.ipsos.co.nz` | Existing interviewer login + user profile (computer name, mobile, email) | Per-user username/password → token |
| 2 | **BO API** (Back Office) | `https://boapi.stg.ipsos.co.nz/swagger/index.html` | New interviewer lookup by email; ticket creation | **One admin account** → token (Eddy will provide) |
| 3 | **Device Management platform (RMM)** | `https://rmm.ipsos.co.nz` (dashboard) / API docs at `https://api2.ipsos.co.nz/api/schema/swagger-ui/` | Holds every interviewer laptop by hostname; runs remote scripts (the actual I-Reach update) | **One platform API token** (already issued, kept out of this repo) + hostname |

---

## 2. Flow A — Existing Interviewer (THE PRIORITY)

Eddy said explicitly: **if you only finish this, we can already deploy it.** Everything else is not critical yet.

### Step 1 — Login
- `POST https://smstg.ipsos.co.nz/api/v1/authentication`
- Body: `{ username, password }`
- Returns: **token**
- Test user: `cbg.test` (password already given to you)

### Step 2 — Get user profile
- `GET /user` (SM API)
- Header: `SM Authorization: <token from Step 1>`
- Returns: **computerName**, cellphone number, email, name, etc.
- Eddy updated `cbg.test`'s computer name to **IPLT569** so you have real data to test against.

### Step 3 — Dashboard
- Greeting uses the real name from the `/user` response: *"Welcome back, {firstName}"*
- Tiles:
  - ✅ **Update I-Reach** — the only one that matters right now
  - ❌ **Device Information** — **DELETE THIS**. Eddy: nothing there is useful to an interviewer.
  - 🔶 **Get Support** → opens/creates a ticket in Back Office (later)
  - 🔶 **Knowledge Base** → static Q&A (later)

### Step 4 — Confirm Device ID screen
**Change required from your current UI:**
- ❌ Remove the "Enter device ID" input field.
- ❌ Remove the wording *"A new version of I-Reach is available"* — we don't actually know if one is.
- ✅ Title: **"Update I-Reach Application"**
- ✅ Display the device ID pulled from `/user`:
  > "Please confirm that your device ID is **IPLT569** by clicking Continue.
  > If this is not your current device, please contact the Help Desk for assistance."
- ✅ Buttons: **Continue** / **Back**

### Step 5 — Sync & Close instructions screen
Exactly two steps, in this order:
1. **Sync I-Reach** — pushes their locally-saved offline work to the server (I-Reach works offline; skipping this = data loss).
2. **Close I-Reach** — must be closed before the update runs.

Then a confirmation checkbox:
> ☐ I have synced and closed I-Reach and I am ready for the update.

**Start Update** button stays disabled until the box is ticked.

**Confirmed by Eddy**: the script must only be called *after* the interviewer explicitly confirms they've closed I-Reach — never trigger the update API just because they landed on this screen. The checkbox + disabled button is that gate; ticking it is the only thing that unlocks Step 6.

### Step 6 — Trigger the update
- On **Start Update**: call the Device Management (RMM) platform API with:
  - the **platform token** (one fixed token for the whole app — not per user)
  - the **hostname / computer name** (this is the only thing that changes per user)
  - the **script ID** for the I-Reach update script
- The platform runs the script on that specific laptop.
- You don't need to log into the RMM dashboard yourself to build this — **John is studying the RMM API** (Swagger at `https://api2.ipsos.co.nz/api/schema/swagger-ui/`) and will hand you the exact endpoint + request parameters for triggering the I-Reach update script. Treat that as the still-open item, not the base URL/credentials.

### Step 7 — Result status (do last, ask for help)
- The platform returns an execution response/status after the script finishes.
- Eddy said to get **John or Erle** to help with this part.
- UI: spinner/progress → success or failure message with a "Contact Help Desk" fallback.
- **Confirmed by Eddy (voice walkthrough)**: the platform returns a response after execution finishes that should say whether it succeeded. Already built this way: `executeIReachUpdate()` reads an immediate status or polls a status endpoint until it gets a success/failure message (see `device_remote_datasource.dart`). Only the exact response schema is still pending from John — the general shape is no longer in question.

---

## 3. Flow B — New Interviewer (LOWER PRIORITY)

### Context
A new hire is mailed a device **plus a printed QR code**. They scan the QR with their phone → your portal opens.

> ⚠️ **Remove the QR code from your login screen.** The QR code *is* how they reach the portal — showing one inside the portal is circular.

### Step 1 — Identify them
They don't know their username/password, so:
- Screen: "Welcome to Ipsos" → ask for **email address** + **last 4 digits of mobile number**
- Backend authenticates to **BO API** with the **admin account** → token
- Confirmed by Eddy: search the **BOUser** resource by **email**, then compare the returned mobile number's last 4 digits against what they typed
- Match = authenticated, and the BOUser record also tells you the **computer name they were issued** — that's what drives which setup instructions to show next (Windows vs Android). No match = error / contact help desk.

### Step 2 — Give them their PIN
Do **not** ask them to enter a device ID — we already know what device we shipped them.

**PIN derivation rule:**
```
PIN = prefix + last 3 digits of computer name

CBG-TAB-671  → 0671   (old CBG devices, prefix "0")
IPLT569      → 8569   (new IPLT devices, prefix "8")
IPLT671      → 8671
IPLT728      → 8728
```
You construct the PIN in code and just display the final number. Don't explain the rule to the interviewer.

> ⚠️ **Confirm this with Eddy.** He gave both `0` (CBG) and `8` (IPLT) as prefixes and the transcript is a bit tangled here. All new devices are IPLT, so `8` is the working assumption.

### Step 3 — Device-specific instructions
The BO record tells you whether they got a **Windows** or **Android** device. Branch the instructions:
- Power on (say where the power button is)
- "When prompted for a PIN, enter **8569**"
- How to connect to Wi-Fi — **separate instructions for Windows 11 vs Android**
- Everything else here is generic static content.

---

## 4. Flow C — Get Support / Ticket (LATER)

- The interviewer is already logged in to SM.
- Tapping "Get Support" should call the Back Office ticket API to open a **Create Ticket** form (reporting issue, subject, project, etc.) under their own credentials.
- Eddy wants to check with **Erle** whether single sign-on is possible so they don't log in twice.

## 5. Flow D — Knowledge Base (LATER)

Static Q&A. No API. Examples:
- "How do I sync I-Reach?"
- "How do I connect to Wi-Fi?"
- "How do I log in to my device?"

---

## 6. 🔴 Architecture warning — read this before you code

You have **two secrets that must never touch the Flutter Web bundle**:
1. The **BO admin username/password/token** (new interviewer lookup)
2. The **Device Management platform token** (can run scripts on every company laptop)

Anything in a Flutter Web app is public — anyone can open DevTools and read it. Both of these must live **behind your backend** (the N8N / ASP.NET layer your teammates handle). Your Flutter app calls *your* backend; *your* backend holds the admin token and talks to BO API and the device platform.

The **existing interviewer** SM token is fine to hold client-side — it's their own token, scoped to them.

Raise this with Eddy/John before Phase 3.

---

## 7. Blocked on Eddy — chase these

- [x] Device Management platform base URL — it's the **RMM platform** (`rmm.ipsos.co.nz`), API docs at `https://api2.ipsos.co.nz/api/schema/swagger-ui/`
- [x] New-interviewer lookup mechanism — confirmed as **BOUser** search by email, returns computer name to branch device instructions
- [ ] BO API admin credentials
- [ ] The **exact RMM endpoint + parameters** to trigger the I-Reach update script — **John** is studying the RMM API and will provide this (don't reverse-engineer it yourself)
- [ ] Confirmation of the PIN prefix rule (0 vs 8)
- [ ] Exact field name for computer name in the `GET /user` response
- [ ] (Erle) SSO feasibility for the ticket system
- [ ] (John/Erle) How to read script execution status back

**Note on credentials**: RMM login and the api2 Swagger API key were shared over Slack for reference/exploration only. Do not commit them to this repo or any doc — keep them in a local, gitignored `.env` (this repo's `.gitignore` doesn't currently exclude `.env`; add that before creating one) or a secrets manager, and route the actual calls through the backend proxy per §6.

---

## 8. Suggested order of work (~40 hrs/month, weekends)

| Phase | Work | Est. |
|-------|------|------|
| 1 | SM auth service + token storage + login screen wired to real API | 4–6 h |
| 2 | `GET /user` → user model → dashboard with real name; delete Device Information tile | 3–4 h |
| 3 | Confirm Device ID screen (display, don't ask) | 2–3 h |
| 4 | Sync & Close screen + confirmation gate | 2–3 h |
| 5 | Backend proxy + trigger update script | 6–8 h |
| 6 | Status polling + success/error states | 4–6 h |
| — | **← MVP. Deployable. Tell users "go to Existing Interviewer."** | |
| 7 | Knowledge Base (static) | 3–4 h |
| 8 | Ticket creation | 5–6 h |
| 9 | New interviewer flow (BO lookup, PIN, OS-specific instructions) | 10–12 h |

Eddy's words: *"We don't need this straight away, but it will be good to have something in the next few months."* Phases 1–6 is roughly 3–4 productive Saturdays.

---
---

# 9. THE BUILD PROMPT

*Paste this into Claude Code (or your AI tool of choice) with your repo open. Replace the `<<< >>>` placeholders once Eddy sends the details.*

```
You are helping me build a Flutter Web self-service portal for Ipsos NZ field
interviewers. I am the frontend developer; a colleague handles the backend
(N8N + MS SQL Server). Work only on the Flutter side unless I say otherwise.

## GOAL OF THIS MILESTONE
Ship the "Existing Interviewer → Update I-Reach" flow end to end. This is the
only flow that matters right now; the client confirmed it can be deployed alone.

## ARCHITECTURE CONSTRAINTS
- Flutter Web. State management: BLoC.
- Two secrets (a Back Office admin token and a device-management platform token)
  must NEVER exist in the Flutter bundle. Route any call needing them through our
  backend proxy. Assume backend endpoints exist at `<<<BACKEND_BASE_URL>>>` and
  stub them with a mockable service interface so I can swap in the real thing.
- The per-user SM token is fine to keep in client memory (not localStorage).
- Use a repository pattern: `AuthRepository`, `UserRepository`, `UpdateRepository`.
- No secrets, no hardcoded credentials, no tokens in source. Use --dart-define.

## API 1 — SM API (staging)
Base: https://smstg.ipsos.co.nz

POST /api/v1/authentication
  Body: { "username": string, "password": string }
  Returns: a token.

GET /user
  Header: `SM Authorization: <token>`
  Returns the user profile including: computer name (e.g. "IPLT569"),
  cellphone number, email, display name.
  (I will paste the exact response JSON — model it strictly from that, do not
  invent field names. If I haven't pasted it yet, ASK ME before guessing.)

## API 2 — Device Management platform (via our backend proxy)
POST <<<BACKEND_BASE_URL>>>/update-ireach
  Body: { "computerName": string }
  Backend attaches the platform token + script id and triggers the remote script.
  Returns: an execution id or status.
GET <<<BACKEND_BASE_URL>>>/update-ireach/status/{executionId}
  Returns: pending | success | failed, plus a message.
Poll every 3s, timeout at 5 minutes, then show a "contact help desk" fallback.

## SCREEN SPEC — build exactly this

### 1. Landing
Two options only: [Existing Interviewer] [New Interviewer]
- DELETE the QR code from this screen. The QR code is printed and mailed to new
  hires; it is what brings them TO this portal. It must not appear inside it.
- "New Interviewer" → a "Coming soon / contact help desk" placeholder for now.

### 2. Login (Existing Interviewer)
Username + password fields → POST /api/v1/authentication.
Handle: invalid credentials, network error, loading state.
On success store token in memory, then call GET /user, then route to Dashboard.

### 3. Dashboard
- Header: "Welcome back, {name from GET /user}"
- Tiles:
  - "Update I-Reach"  → active
  - "Get Support"     → disabled, tooltip "Coming soon"
  - "Knowledge Base"  → disabled, tooltip "Coming soon"
- DELETE the "Device Information" tile entirely. The client said it has no value
  to interviewers.

### 4. Confirm Device screen
Title: "Update I-Reach Application"
- Do NOT render a device-ID text input. Do NOT say "A new version of I-Reach is
  available" (we don't know that).
- Render the computer name from GET /user as read-only display text:
  "Please confirm that your device ID is {computerName} by clicking Continue.
   If this is not your current device, please contact the Help Desk for assistance."
- Buttons: [Continue] [Back]

### 5. Prepare screen
Title: "Before you update"
Two numbered steps only:
  1. Sync I-Reach — this sends all the work saved on your device to our server.
  2. Close I-Reach — it must be fully closed before the update can run.
Checkbox: "I have synced and closed I-Reach and I am ready for the update."
[Start Update] is disabled until the checkbox is ticked.

### 6. Updating screen
Call the backend, poll for status, show progress.
Terminal states: success ("I-Reach has been updated. You can now reopen it.")
or failure ("The update could not be completed. Please contact the Help Desk.")
Do not let the user navigate away mid-update without a confirm dialog.

## WHAT I WANT FROM YOU NOW
1. Propose the folder structure and the BLoC/event/state shape for this flow.
2. Write the AuthRepository + UserRepository with a mockable http client.
3. Then build screens 1–6 in order, one at a time, pausing after each so I can test.
4. Flag anything where the spec is ambiguous instead of guessing.
```

---

## 10. Quick prompt for the New Interviewer flow (use later)

```
Now add the "New Interviewer" flow. Context: a new hire is mailed a device plus a
printed QR code that opens this portal. They do not know their username/password.

Screen: "Welcome to Ipsos"
  Fields: email address, last 4 digits of mobile number.
  Calls OUR BACKEND (never the BO API directly — it needs an admin token):
    POST <<<BACKEND_BASE_URL>>>/new-interviewer/verify
    Body: { "email": string, "mobileLast4": string }
    Backend: authenticates to boapi.stg.ipsos.co.nz with the admin account,
    looks the user up BY EMAIL, compares the last 4 digits of their mobile.
    Returns: { verified: bool, name, computerName, deviceType: "windows"|"android" }

On verified, show a Device Setup screen:
  - Do NOT ask for a device ID. We already know what we shipped them.
  - Compute the PIN in code: "8" + last 3 digits of computerName.
      IPLT569 → 8569.  (Legacy CBG-TAB-### devices use "0" + last 3 → 0671.)
      Put this in one well-named, unit-tested function: `derivePin(computerName)`.
  - Display: "When prompted for a PIN, enter 8569." Never explain the rule.
  - Branch the setup instructions on deviceType:
      windows → power on, enter PIN, connect to Wi-Fi (Windows 11 steps)
      android → power on, enter PIN, connect to Wi-Fi (Android steps)
  - Content is static; put it in a content file, not hardcoded in widgets.
```

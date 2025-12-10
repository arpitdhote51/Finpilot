# FinPilot: Browser-Based Financial Action Agent
## Round 1 Abstract & Design Strategy

---

## 1. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE LAYER                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌──────────────────────────┐              ┌──────────────────────────┐    │
│  │  Web Dashboard UI        │              │   WhatsApp Channel       │    │
│  │  (Command Center)        │              │   (Optional Extension)   │    │
│  │                          │              │                          │    │
│  │ • Text Input             │◄─────────────►│ • Message Receiver      │    │
│  │ • Voice Input (Web API)  │   WS/REST     │ • Status Updates        │    │
│  │ • Live Activity Log      │              │ • Confirmation via Web   │    │
│  │ • Conscious Pause Modal  │              │                          │    │
│  │ • Approve/Reject Buttons │              │                          │    │
│  └────────────┬─────────────┘              └──────────────────────────┘    │
│               │                                                               │
└───────────────┼───────────────────────────────────────────────────────────────┘
                │
                │ REST/WebSocket
                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR & CONTROL LAYER                              │
│                    (Node.js + Express Backend)                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  Task Orchestrator                                                     │ │
│  │  • State Machine (PENDING → PLANNING → EXECUTING → PAUSED → DONE)     │ │
│  │  • Route commands to Intent Engine & Planner                          │ │
│  │  • Enforce Conscious Pause before sensitive actions                   │ │
│  │  • Stream logs to Dashboard via WebSocket                             │ │
│  │  • Handle approval/rejection workflow                                 │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
└───────┬────────────────┬──────────────────────┬───────────────────────────────┘
        │                │                      │
        ▼                ▼                      ▼
┌──────────────────┐ ┌──────────────────┐ ┌───────────────────┐
│  BRAIN LAYER     │ │  PLANNING LAYER  │ │  HANDS LAYER      │
│  (Intent Engine) │ │  (Planner)       │ │  (Automation)     │
├──────────────────┤ ├──────────────────┤ ├───────────────────┤
│                  │ │                  │ │                   │
│ LLM: Gemini 1.5  │ │ Workflow Graphs: │ │ Playwright Browser│
│ or GPT-4o        │ │ • Bill Pay       │ │ Service           │
│                  │ │ • Gold Buy       │ │                   │
│ Input:           │ │ • Profile Update │ │ Methods:          │
│ • User command   │ │                  │ │ • open(url)       │
│ • Context        │ │ Output:          │ │ • click()         │
│                  │ │ Atomic steps     │ │ • type()          │
│ Output (JSON):   │ │ with pause pts   │ │ • select()        │
│ {                │ │                  │ │ • waitFor()       │
│  task_type,      │ │ Decision nodes:  │ │ • getPageText()   │
│  amount,         │ │ • Error checks   │ │                   │
│  biller,         │ │ • Retry logic    │ │ Optional: VLM     │
│  missing_fields  │ │ • Pause states   │ │ click-by-vision   │
│ }                │ │                  │ │                   │
│                  │ │                  │ │                   │
└──────────────────┘ └──────────────────┘ └───────────────────┘
                              │
                              │ Atomic Actions
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     DUMMY BANKING WEBSITE                                    │
│                    (React SPA or HTML+CSS)                                   │
│                    Running on localhost:3001                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  Routes:                                                                     │
│  • /dashboard      (Links to Pay Bills, Buy Gold, Profile)                  │
│  • /pay-bill       (Biller dropdown, Amount input, Error messages)           │
│  • /gold           (Amount input, Confirmation page)                         │
│  • /profile        (Phone, Address fields)                                   │
│                                                                               │
│  Features:                                                                   │
│  • Clear element labels & selectors for agent navigation                     │
│  • Error messages displayed on page (e.g., "Invalid amount")                │
│  • Success screens (e.g., "Payment successful")                              │
│  • Simulated latency to test timeouts & resilience                           │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘

COMMUNICATION FLOW:
1. User types command on Dashboard
2. Dashboard → Orchestrator (/command endpoint)
3. Orchestrator → Intent Engine (LLM call)
4. Intent Engine → Orchestrator (structured JSON)
5. Orchestrator → Planner (select workflow graph)
6. Planner → Orchestrator (sequence of atomic steps)
7. Orchestrator → Automation Service (step by step)
8. Automation → Dummy Bank (browser control)
9. At PAUSE_FOR_CONFIRM: Orchestrator → Dashboard (WebSocket approval request)
10. User approves: Dashboard → Orchestrator (/approval endpoint)
11. Orchestrator → Automation (resume final action)
12. Orchestrator → Dashboard (status + success/error)
```

---

## 2. Workflow Strategy: "Buying Digital Gold" (Detailed Flowchart)

```
START: User Command "Invest ₹100 in digital gold"
  │
  ├─► [1. PARSE INTENT]
  │   ├─ Input: Natural language command
  │   ├─ LLM Call: "Extract task_type, amount, and other fields"
  │   │   ✓ task_type = "GOLD_BUY"
  │   │   ✓ amount = 100
  │   │   ✓ currency = "INR"
  │   │   ✓ beneficiary = "Self"
  │   │   ✓ needs_clarification = false
  │   └─ State: PLANNING
  │
  ├─► [2. SELECT WORKFLOW]
  │   ├─ Match task_type = "GOLD_BUY"
  │   ├─ Load workflow graph: GOLD_BUY_WF
  │   └─ Initialize step index = 0
  │
  ├─► [3. EXECUTE: Open Dashboard Page]
  │   ├─ Action: open("http://localhost:3001/dashboard")
  │   ├─ Automation: page.goto(url)
  │   ├─ Wait for: page to fully load (wait_for_selector(".dashboard-container"))
  │   ├─ Timeout: 5s
  │   ├─ On Success: Log "Dashboard loaded", move to step 4
  │   └─ On Timeout:
  │       ├─ Retry: page.goto(url) up to 2 times
  │       └─ If still fails: Emit ERROR_LOAD_TIMEOUT, transition to ERROR_HANDLER
  │
  ├─► [4. EXECUTE: Click "Buy Gold" Button]
  │   ├─ Action: click(text="Buy Gold")
  │   ├─ Automation: page.click('text=Buy Gold') [text selector for resilience]
  │   ├─ Wait for: Navigation to /gold (wait_for_url contains "/gold")
  │   ├─ Timeout: 3s
  │   ├─ On Success: Log "Navigated to Gold page", move to step 5
  │   └─ On Failure:
  │       ├─ Check if button exists: page.isVisible('text=Buy Gold')
  │       └─ If not visible: Emit ERROR_BUTTON_NOT_FOUND, transition to ERROR_HANDLER
  │
  ├─► [5. EXECUTE: Enter Amount]
  │   ├─ Action: type(selector="#amount", value="100")
  │   ├─ Pre-check:
  │   │   ├─ Verify amount from intent is valid (> 0, numeric)
  │   │   └─ If invalid: Emit ERROR_INVALID_AMOUNT, transition to ERROR_HANDLER
  │   ├─ Automation:
  │   │   ├─ page.fill('#amount', '100')
  │   │   └─ page.locator('#amount').blur() [trigger any validation]
  │   ├─ Wait: 500ms for any validation feedback
  │   ├─ Check: getPageText() for error messages (e.g., "Invalid", "Exceeds limit")
  │   ├─ On Success: Log "Amount entered: ₹100", move to step 6
  │   └─ On Error Message Detected:
  │       ├─ Extract error text
  │       ├─ Emit ERROR_VALIDATION_FAILED + error message
  │       └─ Transition to ERROR_HANDLER (ask user for new amount)
  │
  ├─► [6. EXECUTE: Click "Proceed" Button]
  │   ├─ Action: click(text="Proceed")
  │   ├─ Automation: page.click('text=Proceed')
  │   ├─ Wait for: Confirmation page to load (wait_for_text("Confirm your investment"))
  │   ├─ Timeout: 4s (may have simulated latency)
  │   ├─ On Success: Log "Confirmation page reached", move to step 7
  │   └─ On Timeout:
  │       ├─ Retry: click Proceed again (1 attempt)
  │       └─ If fails: Emit ERROR_NAVIGATION, transition to ERROR_HANDLER
  │
  ├─► [7. BUILD CONFIRMATION SUMMARY]
  │   ├─ Orchestrator prepares summary:
  │   │   ├─ "I am ready to invest ₹100 in digital gold."
  │   │   ├─ "Amount: ₹100"
  │   │   ├─ "Investment Type: Digital Gold"
  │   │   ├─ "Confirmation required before final investment."
  │   │   └─ metadata: { taskId, timestamp, riskLevel: "medium" }
  │   └─ Emit summary to Dashboard via WebSocket
  │
  ├─► [8. PAUSE FOR CONFIRMATION]
  │   ├─ State: PAUSED_FOR_CONFIRM
  │   ├─ Orchestrator waits for user response
  │   ├─ Dashboard shows modal with summary
  │   ├─ User decision tree:
  │   │   ├─ [APPROVE] → Step 9
  │   │   ├─ [REJECT] → Step 11 (Cancellation)
  │   │   └─ [TIMEOUT after 10 minutes] → Auto-reject, log "User did not respond"
  │   └─ Log all user decisions for audit trail
  │
  ├─► [9. EXECUTE: Click "Pay" / "Confirm" Button]
  │   ├─ Condition: Only if user approved in step 8
  │   ├─ Action: click(text="Pay" or "Confirm Investment")
  │   ├─ Automation: page.click('text=Pay')
  │   ├─ Wait for: Success page or message (wait_for_text("Investment successful"))
  │   ├─ Timeout: 5s
  │   ├─ On Success: Log "Investment completed", move to step 10
  │   └─ On Failure:
  │       ├─ Check for error messages on page
  │       ├─ If found: Emit ERROR_INVESTMENT_FAILED, transition to ERROR_HANDLER
  │       └─ If page blank/broken: Emit ERROR_UNKNOWN, transition to ERROR_HANDLER
  │
  ├─► [10. VALIDATE SUCCESS & LOG COMPLETION]
  │   ├─ Verify success indicators on page:
  │   │   ├─ Text contains "successful"
  │   │   ├─ Transaction ID visible (if available)
  │   │   └─ Amount matches original intent
  │   ├─ Orchestrator:
  │   │   ├─ State: COMPLETED
  │   │   ├─ Log final message: "Gold investment of ₹100 completed successfully"
  │   │   ├─ Store transaction details (timestamp, confirmation, amount)
  │   │   └─ Emit SUCCESS event to Dashboard
  │   └─ Dashboard:
  │       ├─ Show success screen with transaction summary
  │       ├─ Display timestamp & transaction ID (if from bank)
  │       └─ Offer user next action (new command or view history)
  │
  └─► [11. CANCELLATION / ERROR RECOVERY]
      ├─ Condition: User rejects in step 8 OR error detected in steps 3–9
      ├─ State: CANCELLED or ERROR
      ├─ For rejection:
      │   ├─ Log "User rejected investment of ₹100"
      │   ├─ Optionally navigate back to dashboard
      │   └─ Emit CANCELLED event to Dashboard
      ├─ For validation errors (e.g., invalid amount):
      │   ├─ Orchestrator asks user: "That amount was invalid. Please enter a new amount."
      │   ├─ User provides new amount (e.g., "50 rupees")
      │   ├─ Re-parse intent with new value
      │   ├─ Jump back to step 5 (Enter Amount) with new value
      │   └─ Continue workflow from there
      ├─ For transient errors (timeout, network):
      │   ├─ Retry the failed step up to 2 times
      │   ├─ If persists: Ask user "The bank website is slow. Try again later?"
      │   └─ Emit ERROR event with recovery suggestion
      └─ END

────────────────────────────────────────────────────────────────────────────────

DECISION NODES & ERROR CHECKS SUMMARY:
1. [Valid Intent?] → If missing critical fields, ask clarification
2. [Workflow Found?] → If task_type not recognized, reject with explanation
3. [Page Load?] → If timeout, retry 2x, then error
4. [Button Visible?] → If not found, take screenshot, optional VLM lookup
5. [Amount Valid?] → If ≤0 or non-numeric, ask user for correction
6. [Validation Message?] → Scan page text for "Invalid", "Error", "Exceeds"
7. [Confirmation Ready?] → Always pause before final action
8. [User Approved?] → If rejected, cancel; if timeout, auto-cancel
9. [Success Message?] → Verify text on page, extract confirmation data

RESILIENCE FEATURES:
• Text-based selectors (not brittle IDs) so DOM layout changes don't break flow
• Timeouts on every wait; retry logic for transient failures
• Page text scanning for error detection (not just element checks)
• Optional VLM fallback for button location if primary selector fails
• User-in-the-loop error recovery (ask for new amount, not just crash)
• Full audit trail: every step, decision, user action logged
```

---

## 3. "Conscious Pause" Mechanism: Detailed Explanation

### 3.1 How the Agent Detects High-Stakes Actions

**Principle:** Any action that results in financial movement, account change, or payment must be preceded by an explicit human confirmation.

**Detection Strategy:**

1. **Workflow-Level Markers:**
   - Each workflow template includes explicit `PAUSE_FOR_CONFIRM` states.
   - These are hard-coded into the workflow graph for each critical operation:
     - `BILL_PAY`: Pause before `click("Pay")`
     - `GOLD_BUY`: Pause before `click("Confirm Investment")`
     - `PROFILE_UPDATE`: Pause before `click("Save Profile")`
   - No intelligent "guessing" needed; safety is deterministic.

2. **LLM-Assisted Context (Optional, for future expansion):**
   - If adding new workflows dynamically, LLM could classify actions as "high-stakes" based on keywords: "transfer", "pay", "confirm", "submit".
   - For hackathon, all workflows are pre-defined, so LLM is not involved in safety logic.

3. **Transaction Metadata Validation:**
   - Before pause, Orchestrator checks:
     - Amount > 0 and within reasonable limits (e.g., < ₹100,000 for gold)
     - Biller/beneficiary is valid
     - Account type is set
   - If metadata invalid, do not proceed to pause; emit ERROR instead.

### 3.2 The "Stop-and-Confirm" UI Flow

**Step 1: Orchestrator Reaches Pause State**
- Planner emits `PAUSE_FOR_CONFIRM` action.
- Orchestrator transitions to state: `PAUSED_FOR_CONFIRM`.
- Orchestrator builds a **human-readable summary** from the intent:
  ```json
  {
    "type": "AWAITING_APPROVAL",
    "taskId": "T-20251210-001",
    "actionType": "GOLD_INVESTMENT",
    "summary": "I am ready to invest ₹100 in digital gold.",
    "details": {
      "amount": 100,
      "currency": "INR",
      "investmentType": "Digital Gold",
      "timestamp": "2025-12-10T23:25:00Z"
    },
    "riskLevel": "medium"
  }
  ```

**Step 2: Dashboard Receives & Displays Pause Modal**
- WebSocket event sent from Orchestrator to Dashboard.
- Dashboard component switches from "Executing" state to "Awaiting Approval" state.
- Modal renders with:
  - **Heading:** "Action Confirmation Required"
  - **Icon:** (⚠️ or 🔒 for visual emphasis)
  - **Summary Text:** "I am ready to invest ₹100 in digital gold."
  - **Detailed Breakdown:**
    ```
    Investment Type:  Digital Gold
    Amount:           ₹100
    Timestamp:        Dec 10, 2025 11:25 PM
    ```
  - **Two Buttons:**
    - `[✓ Approve]` (green, prominent)
    - `[✗ Reject]` (red, secondary)
  - **Countdown Timer:** (optional, e.g., "This request expires in 10 minutes")

**Step 3: User Makes Decision**
- **User Clicks Approve:**
  - Dashboard immediately shows: "Approved. Proceeding with investment..."
  - Sends `POST /tasks/:taskId/approve` to Orchestrator.
  - Orchestrator resumes workflow from next step (execute final action).
  - Log entry: `[2025-12-10 23:25:15] User approved investment of ₹100`

- **User Clicks Reject:**
  - Dashboard shows: "Investment cancelled."
  - Sends `POST /tasks/:taskId/reject` to Orchestrator.
  - Orchestrator:
    - Sets state to `CANCELLED`.
    - Optionally navigates dummy bank back to dashboard.
    - Logs: `[2025-12-10 23:25:20] User rejected investment of ₹100`
  - User can start a new command.

- **Timeout (No response for 10 minutes):**
  - Orchestrator auto-rejects.
  - Dashboard shows: "Confirmation expired. Please try again."
  - Logs: `[2025-12-10 23:35:20] Approval timeout; request cancelled`

**Step 4: Orchestrator Enforces Pause (No Bypass)**
- **Critical safety guarantee:** The Orchestrator will **not** allow the final automation action (`click("Pay")`) to proceed until it receives explicit `/approve` endpoint call.
- Flow is synchronous and blocking:
  ```
  await orchestrator.waitForApproval(taskId, timeoutMs=600000);
  // Blocks until POST /approve or POST /reject received
  if (approved) {
    await automationService.click("Pay");
    // Only executed if explicitly approved
  }
  ```
- No backdoors, no silent approvals, no race conditions.

### 3.3 Safety Guarantees & Audit Trail

**Guarantees:**
1. **No auto-execution of final payments:** Pause is mandatory; no configuration or speed setting bypasses it.
2. **User always sees what's about to happen:** Summary includes amount, target, and action type.
3. **Clear approval record:** Every approval/rejection is timestamped and logged.
4. **Timeout protection:** Requests don't hang indefinitely; auto-cancel after 10 minutes.

**Audit Trail (Persisted):**
- For each task:
  - Command received
  - Intent parsed (with original command vs. parsed fields)
  - Workflow selected
  - Each step executed (timestamp, success/error)
  - Pause triggered (timestamp, summary shown)
  - User decision (Approve/Reject/Timeout, timestamp)
  - Final action executed (if approved)
  - Outcome (success/error, confirmation data)
- Accessible via `GET /tasks/:id/audit` for judges to inspect.

---

## 4. Tech Stack Selection & Justification

### 4.1 Frontend: React (Next.js / Vite) + WebSocket

**Choice Rationale:**
- **Real-time updates:** WebSocket for live log streaming and pause notifications.
- **Component-based:** Quick to build dashboard UI with modals, panels, status badges.
- **Developer velocity:** React + Vite provides hot reload and fast iteration during 24h hackathon.
- **Alternatives considered:**
  - Plain HTML+CSS: Slower to iterate; hard to manage state (live log, pause modal).
  - Vue.js: Equally capable but React has wider ecosystem for production-ready UI libraries.

**Why it's a fit:**
- Fast development ✓
- Real-time bidirectional comms ✓
- Polished, professional UI ✓

### 4.2 Backend: Node.js + Express

**Choice Rationale:**
- **JavaScript ecosystem:** Seamless integration with Playwright (also Node.js), no context switching.
- **Async/await:** Perfect for orchestrating multi-step workflows with waits and retries.
- **Lightweight:** Express is minimal and fast to prototype; no heavy framework overhead.
- **Alternatives considered:**
  - FastAPI (Python): Great for ML pipelines, but overkill here; would add language switching overhead.
  - Go: Faster at runtime, but steeper learning curve and harder to integrate with Playwright in time.

**Why it's a fit:**
- Perfect Playwright integration ✓
- Async workflow orchestration ✓
- Rapid development ✓

### 4.3 Browser Automation: Playwright

**Choice Rationale:**
- **Speed:** Modern, faster than Selenium; uses browser's native protocol (CDP).
- **Stability:** Better selector resilience; text selectors (`text=Pay Bills`) don't break on minor DOM changes.
- **Flexibility:** Supports screenshots, PDF export, multiple browsers; great for resilience testing.
- **Maintenance:** Actively developed; better than Selenium's legacy codebase.
- **Alternatives considered:**
  - **Selenium:** More widely known, but slower and brittle (relies on XPath/CSS often breaks on layout changes).
  - **Puppeteer:** Good, but Playwright is a superset; Playwright has better API for our use case.

**Comparison Table:**

| Criteria        | Playwright | Selenium | Puppeteer |
|-----------------|-----------|----------|-----------|
| Speed           | ⭐⭐⭐⭐⭐ | ⭐⭐⭐   | ⭐⭐⭐⭐ |
| Stability       | ⭐⭐⭐⭐⭐ | ⭐⭐⭐   | ⭐⭐⭐⭐ |
| Text Selectors  | ⭐⭐⭐⭐⭐ | ⭐⭐⭐   | ⭐⭐⭐   |
| Learning Curve  | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Dev Time (24h)  | ⭐⭐⭐⭐⭐ | ⭐⭐⭐   | ⭐⭐⭐⭐ |

**Why Playwright wins:**
- Text selectors make workflows resilient to DOM layout changes (critical for judges' "surprise command" test).
- Fast enough to handle 3 workflows + error scenarios in demo without lag.
- Native support for waits, retries, and error handling (less boilerplate code).

### 4.4 Intent Engine: Gemini 1.5 Pro (or GPT-4o as backup)

**Choice Rationale:**
- **Context window:** Gemini 1.5 Pro has 2M tokens; plenty for few-shot prompting with task definitions.
- **JSON mode:** Both Gemini and GPT-4o support structured output; reliable for schema extraction.
- **Cost:** Gemini is cheaper per token than GPT-4o; critical for hackathon budget.
- **Speed:** Gemini 1.5 Pro is faster than GPT-4o on simple JSON extraction tasks.
- **Alternatives considered:**
  - **Llama 3 (self-hosted):** Free, but requires setup and tuning; risky for time-constrained hackathon.
  - **Claude 3 (Anthropic):** Excellent quality, but pricier than Gemini and slower for this task.

**Implementation:**
- Use JSON schema validation and few-shot examples:
  ```
  System prompt: "You are a financial command parser. Extract task_type, amount, biller, etc. from user text. Only return valid JSON."
  
  Examples:
  Input: "Pay my Adani Power bill of 500 rupees"
  Output: { "task_type": "BILL_PAY", "amount": 500, "biller": "Adani Power", "needs_clarification": false }
  
  Input: "Buy gold"
  Output: { "task_type": "GOLD_BUY", "amount": null, "needs_clarification": true, "missing_fields": ["amount"] }
  ```
- If output is invalid JSON, retry with error message.
- **Cost estimate:** ~100–200 tokens per command; ~$0.001–0.002 per command.

**Why it's a fit:**
- Reliable JSON extraction ✓
- Fast & cheap ✓
- Easy to validate & debug ✓

### 4.5 Optional: Vision-Language Model (VLM) for Click-by-Vision (Stretch Feature)

**Choice:** Gemini 1.5 Pro (vision) or GPT-4o (vision)

**Use Case:**
- If a button selector fails (e.g., DOM changed), take a screenshot and ask VLM: "Where is the 'Pay' button on this page?"
- VLM returns bounding box coordinates; click via `page.mouse.click(x, y)`.

**Implementation (if time permits):**
```javascript
// If text selector fails:
const screenshot = await page.screenshot();
const response = await visionModel.ask(
  "Locate the button labeled 'Pay' on this page and return its bounding box as [x, y, width, height]",
  screenshot
);
const [x, y, w, h] = response.boundingBox;
await page.mouse.click(x + w/2, y + h/2);
```

**Why this impresses judges:**
- Shows understanding of "next-generation Computer Use agents" mentioned in problem statement.
- Demonstrates resilience beyond brittle selectors.
- Optional but **differentiator** if implemented smoothly.

**Cost:** ~10–50 cents per screenshot; use sparingly (only on fallback).

### 4.6 Dummy Bank: React SPA or Simple HTML+CSS

**Choice:** React SPA (simple) or static HTML served via Express static middleware

**Why React:**
- Easy to manage state (error messages, loading states).
- Can simulate latency with `setTimeout` on route handlers.
- Quick to iterate if judges ask for changes.

**Why Static HTML:**
- Even simpler, faster to render.
- All selectors hardcoded and stable.

**Recommendation for hackathon:** Use React SPA with key routes (`/dashboard`, `/pay-bill`, `/gold`, `/profile`). Include deliberate error-triggering (e.g., if amount < 0, show error).

### 4.7 Logging & Persistence: SQLite (or simple JSON file)

**Choice:** In-memory + periodic JSON dump (for simplicity) or SQLite if you want structured queries.

**Why JSON dump:**
- No dependency setup needed; runs anywhere.
- Easy to inspect for debugging.
- Judges can replay task history via API.

**Tables to log:**
- Tasks (id, user_command, task_type, status, created_at)
- Steps (id, task_id, step_name, action_type, result, timestamp)
- Approvals (id, task_id, user_decision, timestamp)

---

## 5. Risk Mitigation & Contingency Plans

| Risk | Mitigation |
|------|-----------|
| LLM fails to parse intent correctly | Strict schema validation; fallback to template-based parsing for simple cases |
| Playwright selector fails | Implement text selectors (resilient); optional VLM fallback for button location |
| Dummy bank page loads slowly | Add explicit waits + timeouts; retry logic; simulate slow pages in demo |
| WebSocket connection drops | Dashboard polls Orchestrator for status every 2s as fallback |
| Judges change task mid-demo | Pre-loaded workflows are parameterized; new amount/biller can update existing workflow without re-coding |
| Out of LLM API credits | Hardcode intents for demo; use free tier alternatives |
| Browser crashes | Restart browser instance; resume from last successful step in workflow log |

---

## 6. Deliverables Checklist (Round 1 → Round 2)

**Round 1 (Abstract & Design):**
- ✓ Architecture Diagram (this document, section 1)
- ✓ Workflow Strategy (detailed flowchart for Gold Buy, section 2)
- ✓ Conscious Pause Mechanism (section 3)
- ✓ Tech Stack Selection (section 4)

**Round 2 (Implementation):**
- Fully functional agent executing 3 workflows
- Dummy banking website with clear error messages
- React dashboard with live log + conscious pause modal
- Node.js backend orchestrator with WebSocket streaming
- Playwright automation service
- Demo video (10 min): Bill Pay, Gold Buy, Profile Update + error handling
- This abstract document
- Source code on GitHub with README
- Audit trail API for judges to inspect task history

---

## 7. Success Metrics Alignment

How our solution meets judging criteria:

| Criterion | Our Approach |
|-----------|--------------|
| **Task Completion Rate** | Resilient selectors + retry logic + error recovery; target >90% on 3 core workflows |
| **Safety Adherence** | Explicit `PAUSE_FOR_CONFIRM` state; no bypass; full audit trail |
| **Intent Accuracy** | Gemini 1.5 with JSON schema + few-shot examples; fallback template parsing |
| **Innovation** | Optional VLM click-by-vision; Playwright text selectors; parametric workflow graphs |

---

## 8. Conclusion

**FinPilot** is a **browser-based financial action agent** that transforms natural language commands into reliable, safe, end-to-end banking workflows. By combining a fast intent engine (Gemini), a flexible planner (workflow graphs), and a resilient automation layer (Playwright), we deliver an agent that judges can trust is both **powerful** (full browser control, multi-step tasks) and **safe** (mandatory conscious pause, audit trail, error recovery).

Our tech stack prioritizes **speed** (Playwright, Node.js for dev velocity), **cost** (Gemini), and **resilience** (text selectors, VLM fallback), making it a winning design for the hackathon and a credible prototype for real-world financial automation.

---

*FinPilot Team | December 2025 | Techfest IIT Bombay*

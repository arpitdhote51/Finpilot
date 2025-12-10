# FinPilot – Agentic Financial Web Action System  
## Design Document (Excerpt)

---

## 1. Workflow Strategy – Sample Task: Buying Digital Gold

### 1.1 High-Level Goal

Given a natural language command such as:

> “Invest ₹100 in digital gold”

the agent should autonomously navigate the dummy banking website in a browser, fill in the required fields, reach the investment confirmation screen, pause for user approval, and only then execute the final payment click.

### 1.2 Step-by-Step Workflow

**Input:**  
User command text: `Invest ₹100 in digital gold`

**Step 1 – Intent Parsing (Brain)**  
- The Intent Engine calls an LLM with a strict JSON schema to extract:
  - `task_type`: `GOLD_BUY`
  - `amount`: `100`
  - `currency`: `INR`
  - `beneficiary`: `Self`
  - `needs_clarification`: `false`
- If mandatory fields are missing (like amount), the engine flags `needs_clarification: true` and the user is asked a follow-up question before continuing. [file:1]

**Step 2 – Workflow Selection (Planner)**  
- The Planner matches `task_type = GOLD_BUY` to a predefined workflow template.
- It initializes a sequence of atomic steps for the “Buy Digital Gold” task, for example:
  1. Open dashboard page.
  2. Click “Buy Gold”.
  3. Enter amount.
  4. Click “Proceed”.
  5. Pause for confirmation.
  6. Click “Pay” or “Confirm Investment”.
  7. Verify success message. [file:1]

**Step 3 – Execute Steps via Automation (Hands)**  

1. **Open Dashboard**
   - Action: open the dummy bank dashboard URL.
   - Wait for a known selector (e.g., `.dashboard-container`) with a timeout and a small number of retries to handle slow loads. [file:1]

2. **Navigate to Gold Investment Page**
   - Action: click the “Buy Gold” element using robust text-based selectors (e.g., `text=Buy Gold`).
   - Wait until the URL or a header indicating the gold page is visible. [file:1]

3. **Fill Amount**
   - Validate that the intent’s `amount` is a positive number.
   - Action: fill the amount input (e.g., `#amount`) with `100`.
   - Briefly wait and then scan the page text for any validation error messaging (e.g., “Invalid amount”). [file:1]

4. **Handle Amount Errors (If Any)**
   - If a validation error is detected (negative amount, blank, or out-of-range), send a message back to the user:  
     “The amount entered is invalid. Please provide a valid amount.”
   - On receiving a corrected amount, update the intent and re-run from the “Fill Amount” step. [file:1]

5. **Go to Confirmation Screen**
   - Action: click “Proceed”.
   - Wait for a confirmation text like “Confirm your investment” to ensure the flow reached the pre-payment page.
   - If this times out, retry once and then mark an error state with a helpful message if it still fails. [file:1]

6. **Trigger Conscious Pause**
   - The Planner reaches a special step (`PAUSE_FOR_CONFIRM`) before any irreversible action (like clicking “Pay”).
   - Control is returned to the orchestrator to build and display a confirmation prompt to the user (detailed in the next section). [file:1]

7. **Execute Final Payment (If Approved)**
   - After user approval, the agent clicks the final “Pay” or “Confirm Investment” button.
   - It then waits for a success message like “Investment successful” and captures transaction details if available.
   - Status and summary are pushed back to the dashboard. [file:1]

8. **Completion and Logging**
   - All steps, decisions, errors, and user confirmations are written to an audit log for traceability.
   - The dashboard shows a final success state with key details (amount, time, transaction info where available). [file:1]

---

## 2. “Conscious Pause” Mechanism

### 2.1 What Is Considered High-Stakes

High-stakes actions are any browser clicks that result in:

- Moving money (payments, transfers, investments).
- Persisting sensitive profile changes (e.g., mobile number, address). [file:1]

For these actions, the workflow template inserts an explicit `PAUSE_FOR_CONFIRM` step before the click that commits the change (e.g., the final “Pay” button). [file:1]

### 2.2 How the Agent Detects Pause Points

- Each workflow’s definition marks critical steps that must not proceed automatically.
- For example, the “Buy Gold” workflow has:
  - Normal steps for navigation and form filling.
  - A dedicated “pause” step before the final payment click. [file:1]
- The Planner never directly instructs the automation layer to perform high-stakes actions; it first emits a “pause” signal to the orchestrator. [file:1]

### 2.3 Stop-and-Confirm Flow

1. **Build Human-Readable Summary**
   - Before pausing, the orchestrator composes a concise summary, such as:
     - “I am ready to invest ₹100 in digital gold.”
     - Details: amount, type of investment, timestamp, and task ID. [file:1]

2. **Display Pause Prompt in Dashboard**
   - The dashboard displays a modal or side panel with:
     - A title like “Action Confirmation Required”.
     - The summary of what the agent is about to do.
     - Detailed breakdown (amount, instrument, when, which workflow).
     - Two buttons: Approve and Reject. [file:1]

3. **Wait for User Decision**
   - The orchestrator moves the task to a `PAUSED_FOR_CONFIRM` state and waits for a response:
     - On **Approve**, the workflow resumes and the final high-stakes click is executed.
     - On **Reject**, the workflow is cancelled and the agent logs that the user rejected the action.
     - On **Timeout** (for example, after a configurable period), the request is auto-cancelled for safety. [file:1]

4. **Enforcement**
   - The orchestrator’s logic prevents the automation layer from executing any final “Pay/Transfer/Submit” action unless:
     - A corresponding approval event is received.
     - The task is still in the correct paused state (no stale approvals). [file:1]
   - This ensures the conscious pause cannot be bypassed by misconfiguration or agent error. [file:1]

5. **Audit Trail**
   - For every pause, the system logs:
     - The summary presented to the user.
     - The user’s decision and timestamp.
     - The resulting action taken (payment executed or cancelled). [file:1]
   - Judges can inspect this later to verify safety adherence. [file:1]

---

## 3. Tech Stack Selection

### 3.1 Overview

The stack is chosen to maximize:

- Development speed and hackathon productivity.
- Reliable web automation.
- Safe and accurate intent understanding.
- Clear, real-time user feedback and control. [file:1]

### 3.2 Frontend: React Dashboard

- **Choice:** React (with Vite or Next.js) for the dashboard UI.
- **Reasons:**
  - Component-based architecture makes it easy to build a command input, live log, status badges, and a confirmation modal.
  - Excellent ecosystem for rapid UI development and styling.
  - Integrates well with real-time updates over WebSockets for the live activity feed and pause prompts. [file:1]

### 3.3 Backend: Node.js Orchestrator

- **Choice:** Node.js with a lightweight HTTP framework.
- **Reasons:**
  - Works naturally with Playwright, which is also Node-based, reducing context switching.
  - Asynchronous model with `async/await` simplifies implementing multi-step workflows with timeouts and retries.
  - Easy to expose REST and real-time endpoints (for commands, approvals, and status). [file:1]

### 3.4 Browser Automation: Playwright

- **Choice:** Playwright as the automation layer controlling the browser.
- **Reasons:**
  - Modern, fast, and more stable than many legacy alternatives for web UI automation.
  - Supports robust text-based selectors like `text=Pay Bills`, which tend to survive UI layout changes better than raw CSS or XPath. [file:1]
  - Built-in waiting, retrying, and screenshot capabilities that help demonstrate resilience to slow pages or changed element positions. [file:1]
- **Why not Selenium:**
  - Heavier setup, more boilerplate for waits, and more fragile selectors.
  - Slower feedback loop during intense hackathon development. [file:1]

### 3.5 Intent Engine: Cloud LLM (e.g., Gemini or GPT Class Model)

- **Choice:** A cloud-hosted large language model for intent parsing.
- **Reasons:**
  - Quickly turns natural language commands into structured JSON containing task type, amount, biller/beneficiary, and other fields.
  - Can be guided with few-shot examples and a strict schema, reducing the likelihood of malformed outputs. [file:1]
  - Reduces the need for complex custom NLP pipelines, freeing time to focus on the browser agent and safety features. [file:1]
- **Why not local/self-hosted models (for this hackathon):**
  - Setup, tuning, and resource management overheads are high.
  - Time constraints favor a reliable managed API, as suggested by the problem statement. [file:1]

### 3.6 Optional Vision-Language Model (VLM)

- **Choice:** Vision-enabled LLM as an optional “Explorer Mode.”
- **Use:**
  - As a fallback, the system can capture a screenshot of the dummy bank page and ask the VLM to locate a particular button (for example, “Pay”).
  - This can be used in the demo to show resilience when selectors are changed intentionally. [file:1]
- **Why it adds value:**
  - Demonstrates forward-looking “Computer Use” style interaction mentioned in the brief.
  - Differentiates the solution from simple, brittle automation scripts while still being optional to core functionality. [file:1]

---

## 4. Summary

This design combines a clear, deterministic workflow strategy for one sample task (buying digital gold) with a strong, enforced conscious pause mechanism and a carefully chosen tech stack optimized for speed, safety, and robustness. It aligns tightly with the FinAgent Hackathon objectives of end-to-end web action automation, safety adherence, and innovation in intelligent UI interaction. [file:1]

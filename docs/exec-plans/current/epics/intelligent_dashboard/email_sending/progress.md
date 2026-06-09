# Progress — email_sending (MER-5257 → MER-5642)

Live status of the work. Detailed task content lives in `plan.md`; this file is the at-a-glance tracker.

- Jira (backend, merged): [MER-5257](https://eliterate.atlassian.net/browse/MER-5257)
- Jira (frontend, active): [MER-5642](https://eliterate.atlassian.net/browse/MER-5642)
- Plan (full detail): [plan.md](plan.md)
- PRD: [prd.md](prd.md)
- Requirements: [requirements.yml](requirements.yml)
- Open gaps: [gaps.md](gaps.md)
- Figma node (Support Email): https://www.figma.com/design/2DZreln3n2lJMNiL6av5PP/Instructor-Intelligent-Dashboard?node-id=955-17500
- Figma node (Assignment Email): https://www.figma.com/design/2DZreln3n2lJMNiL6av5PP/Instructor-Intelligent-Dashboard?node-id=1115-18333

## Current Status

- **Phase:** Phases 4–6 COMPLETE. Phase 6 manual QA done (2026-06-08..09) — all cases 6.1–6.21 pass; 4 bugs found → fixed via TDD → committed; 1 backlog logged; AI-review loop CLOSED; B1 RESOLVED. Remaining = docs commit + GenAI backlog ticket + archive.
- **Last updated:** 2026-06-09
- **Next step:** commit docs (this file + `gaps.md` + `prd.md`) → write the **GenAI model inflight-counter underflow** backlog ticket (see 6.4 note) → archive feature docs (`current/` → `archive/`). Final gate (6.19) already green.
- **Branch:** `MER-5642-context-aware-email-draft-modal-ui-implementation` (PR #6606)
- **PR 1 (Phases 1+2):** MERGED to master (`09fdf332bc` — PR #6556)
- **Phase 3:** COMPLETE (all B2/B3 gaps resolved in prior sessions)
- **Phase 4:** COMPLETE (modal LiveComponent + tests + Button `:close` fix)
- **Phase 5:** COMPLETE — 5.1–5.7 all committed + pushed; 5.7 banner VERIFIED (Session 13)
- **Phase 6:** COMPLETE — manual QA Blocks A–D all pass (Session 15)
- **B1:** RESOLVED — `Button` atom-key globals fix committed (kept `[ENHANCEMENT]` per type-stickiness; Session 14)

## Status legend

- `[ ]` not started
- `[~]` in progress
- `[x]` complete

## Phases & Steps

### Phase 1 — Backend Domain Services ✅

- [x] 1.1 — Situation enum + lookup map
- [x] 1.2 — Context builder service
- [x] 1.3 — AI draft facade
- [x] 1.4 — Prompt composer
- [x] 1.5 — GenAI Feature Config "Instructor Email"

### Phase 2 — Placeholder Substitution + Send Pipeline ✅

- [x] 2.B5 — Public API parent module + EmailContext extension
- [x] 2.1 — Whitelist substitution module
- [x] 2.2 — Per-recipient template realization
- [x] 2.3 — Oban worker (one job per recipient)
- [x] 2.4 — Send-time placeholder validation
- [x] 2.5 — Per-recipient result summary + telemetry

### Phase 3 — Figma / UI Workflow Alignment ✅

- [x] 3.1 — Run `ui_workflow` against Figma node 955:17500 (equivalent design context + screenshot + variable defs fetched, brief embedded in `gaps.md` decisions)
- [x] 3.2 — Resolve B2 design state gaps (G-D01..G-D14) — all 14 RESOLVED
- [x] 3.3 — Resolve B3 token drift (G-T01..G-T03) — all 3 RESOLVED

### Phase 4 — Reusable Draft Email Modal (UI + a11y)

#### Pre-work
- [x] 4.0a — Add `Fill-Buttons-fill-primary-bold` token to `assets/tailwind.tokens.js`
- [x] 4.0b — Decision: drop `INSTRUCTOR_EMAIL_MAX_RECIPIENTS` cap

#### Implementation Steps

- [x] **4.1 — LiveComponent scaffold + state model**
- [x] **4.2 — Recipient chip pills + overflow + remove**
- [x] **4.3 — Tone buttons (Neutral / Encouraging / Firm)**
- [x] **4.4 — Subject input**
- [x] **4.5 — Body editor (Slate RichTextEditor + markdown→Slate conversion)**
- [x] **4.6 — Generate / Send / Cancel buttons + backend wiring**
- [x] **4.7 — Focus trap + keyboard ops**
- [x] **4.8 — Loading / error / empty / validation states**
- [x] **4.9 — Live region announcements**
- [x] **4.10 — Testing**

#### Extra work (discovered during Phase 4)
- [x] **Button `:close` variant aria-label fix** — pre-existing bug where custom `aria-label` was swallowed. Root cause: HEEx `@rest` keys are atoms, code read string keys. Fixed in `button.ex` `normalize_button_assigns/1`.
- [x] **Unused function cleanup** — removed `inject_summary_recommendation/3` and `assert_eventually/2` from `instructor_dashboard_live_test.exs` (pre-existing dead code causing compile warnings).

### Phase 5 — Entry-Point Integrations

- [x] 5.1 — Student Support tile launcher
- [x] 5.2 — Assessments tile launcher
- [x] 5.3 — Student Overview launcher (swap legacy EmailModal → DraftEmailModal in `students.ex`)
- [x] 5.4 — Content → Student list launcher (same shared `students.ex` mount)
- [x] 5.5 — Learning Objectives → Student list launcher (`student_proficiency_list.ex`; wired + tested, committed `54f0bd2e41`)
- [x] 5.6 — Additional entry points (G-J01 resolved: closed list = the 5 explicit entry points)
- [x] 5.7 — "Email sent" banner — VERIFIED 2026-06-01. Chain: modal send success (`draft_email_modal.ex:365-366`) → `send(self(), {:flash_message, {:info, "Email sent to N student(s)"}})` → parent `handle_info` (`instructor_dashboard_live.ex:1170-1171`) → `put_flash(:info, …)` → renders in `#flash_container` z-50 (`layouts/instructor_dashboard.html.heex:17`), above sticky thead z-[40]. Manually dismissible; no auto-dismiss (design polish, flagged G-D10). Copy decision: kept "Email sent to N student(s)" per ticket AC §2.5.a + PRD L48 — §2.5.b's "Queued N emails" accuracy revision intentionally NOT adopted ("sent" is the term instructors expect; enqueue-vs-deliver distinction is internal).

#### Extra work (GenAI cleanup, discovered during Phase 5 — driven by AIDraftFacade needing `response_format: %{type: "json_object"}`)

- [x] **Provider opts plumbing** — added `provider_opts:` pass-through from `Execution.generate_with_metadata/5` → `Completions.generate/4` → `Provider.generate/4`. `OpenAICompliantProvider.completion_params/4` now appends `response_format`, `temperature`, `max_tokens` when present. Behaviour callback `Provider.generate/4` updated. Three providers (`OpenAICompliantProvider`, `ClaudeProvider`, `NullProvider`) + 4 test mocks updated.
- [x] **AIDraftFacade JSON mode** — passes `provider_opts: [response_format: %{type: "json_object"}]` for Ollama API-level JSON constraint. JSON repair pipeline kept as defense-in-depth.
- [x] **LLMBridge type-vs-impl mismatch fix** — `@type opts` declared `temperature`/`max_tokens` since Aug 2025 (MER-4864) but `call_with_routing/3` dropped them. Now wired through `provider_opts:`.
- [x] **LLMBridge signature refactor** — `next_decision/2` → `next_decision/3`. Required `%ServiceConfig{}` struct pattern-matched as 2nd positional arg (replaces runtime `Map.fetch!`). Optional knobs as `opts \\ []` keyword list. New `@type completion_opts` documents all four optional keys (`temperature`, `max_tokens`, `section_id`, `actor_id`) — old type spec under-declared `section_id`/`actor_id`. Caller in `server.ex` updated.
- [x] **LLMBridge dead-code removal** — `call_provider/3` orphan from MER-5222 (Jan 2026) refactor. Audit found zero live callers (only its own def + skipped placeholder test). Deleted public function + skipped describe block + unused `Completions` alias.

#### Open GenAI items (flag for PR reviewer / Darren)

- [ ] **Claude `response_format` gap — needs empirical check + decision.** `ClaudeProvider.generate/4` silently drops `provider_opts`. Anthropic API (Claude 3.x) has no `response_format` parameter; only OpenAI-compliant providers (Ollama, OpenAI) honor the JSON-mode constraint added this session. Risk: if any active `ServiceConfig` uses Claude as primary or backup for a feature whose facade passes `response_format` (currently only `:instructor_email` via `AIDraftFacade`), routing to Claude returns unconstrained text — JSON repair pipeline + `:parse_failure` UX absorbs the impact but Generate-button retries increase. **Cannot verify from local env (no prod DB access).** Mitigation options if Claude routing is real:
  - **E** — feature/capability flag at routing layer so JSON-required features never pick Claude providers (cleanest).
  - **D** — implement native Anthropic JSON via forced tool use (most reliable; coexistence with agent tool calling needs design; Claude 4 unsupported by current `ClaudeProvider`).
  - **A** — moduledoc note in `ClaudeProvider` documenting the drop (always do this regardless).

  **Ask Darren:** is Claude in any active ServiceConfig today (or planned)? Answer determines whether this is paperwork (A) or implementation (D/E).

#### Extra work (discovered during Phase 5 manual QA)

- [x] **Send-close teardown regression (all entry points).** After **Send**, the modal closed server-side (parent removes the component via `:if`), but `phx-remove` does NOT fire on wholesale `LiveComponent` removal — so `Modal.show_modal`'s `overflow-hidden` on `<body>` + the fixed backdrop + focus trap leaked. Result: page scroll dead, clicks blocked, flash trapped under the sticky header. Cancel/X were unaffected because they run `Modal.hide_modal` client-side before closing. **Fix:** on send success, `draft_email_modal.ex` sets a `closing` flag and renders a one-shot `phx-hook="OnMountAndUpdate"` element with `data-event={Modal.hide_modal(@modal_dom_id)}`, replaying the same teardown before removal. Failure path unchanged. Single shared-component change → fixes 5.1–5.5. Verified manually (browser-only behavior; not unit-testable). Re-check: QA step 6.9 "Page stays responsive after close".
- [x] **Flash banner hidden behind sticky table header.** The instructor-dashboard flash container was `z-40` and the insights tables' sticky `<thead>` is `z-[40]` — equal z-index, so the header painted over the "Email sent" banner (and any flash on those tabs). **Fix:** bumped the flash container to `z-50` in `instructor_dashboard.html.heex`. Pre-existing; surfaced by the send flash on the Learning Objectives tab.
- [x] **DotDistributionChart React duplicate-key + hover bug (Learning Objectives proficiency chart).** Tower dots were keyed by `towerDot.student_id`, but objective proficiency rows (`Metrics.student_proficiency_for_objective`) expose `id`, not `student_id` → `student_id` was `undefined`, giving every tower dot `key="undefined"` (React "two children with same key" warning) and a shared `dotId` (hovering one dot highlighted all). Surfaced by seeding multiple students at the same proficiency value (a tower). **Fix:** key/id tower dots by the map index in `DotDistributionChart.tsx`. Pre-existing; separate component from the email feature.

### Phase 6 — End-to-End Verification + Manual QA

#### Quick-Start Access (read this first — make access easy)

**1. Log in once (admin can open any section's instructor dashboard):**
- Go to `http://localhost/authors/log_in`
- Email: `admin@example.edu` · Password: `changeme`
- (Admin passes the dashboard gate `is_section_instructor_or_admin?` — no per-section instructor account needed; none are enrolled.)

**2. Entry-point URLs (paths — prepend `http://localhost`):**

| Case | Entry point | Path |
|------|-------------|------|
| 6.1 | Student Support tile | `/sections/example_course_section/instructor_dashboard/insights/dashboard?dashboard_scope=course` |
| 6.2 | Assessments tile | same dashboard page (scroll to the **Assessments** tile) |
| 6.16 | Overview → Students | `/sections/example_course_section/instructor_dashboard/overview/students` |
| 6.17 | Content → student list | `/sections/dashboard_hierarchy_demo/instructor_dashboard/insights/content` → click **Unit 1** → **Module 1** |
| 6.18 | Objectives → proficiency | `/sections/dashboard_objectives_demo/instructor_dashboard/insights/learning_objectives` → expand an objective → pick a proficiency level |

**3. Which students to select** (`example_course_section` roster):
- **Have email (will receive):** Alice Johnson, Bob Smith, Carol Williams, David Lee, Emma Garcia, Frank Brown, Henry Wilson.
- **No email (use for the excluded-note — 6.8 / 6.21):** **Grace Davis**, **Admin User**.
- Tip: select e.g. *Alice Johnson + Bob Smith + Grace Davis* → you'll see Alice/Bob as chips **and** the "1 selected student … does not have an associated email" note (Grace).

**4. AI generate (6.4):** runs on **local Ollama** (`llama3.1:8b`) — no cloud key. Ensure `ollama serve` is running (`ollama list` shows the model). Click **Generate New Draft** → subject + body fill in (first run may take a few seconds).

#### Suggested Run Order (avoid re-opening the modal / re-navigating)

Cases are grouped by feature, not execution order. Run them in this order so the shared `DraftEmailModal` is exercised **once**, then each entry point only gets a "does it open with the right context" check (no duplicate modal-internal testing).

- **Block A — One full modal pass** (open the modal ONCE via Overview→students; run every in-modal behavior in that session; end by sending):
  6.16 (open) → 6.3 tone → 6.4 generate/regenerate → 6.6 subject → 6.20 debounce → 6.21 Send-state → 6.14 toolbar → 6.7 recipients → 6.8 excluded → 6.11 keyboard → 6.10 cancel → **6.9 send** (closes modal — check teardown/flash here).
- **Block B — Entry-point opens** (verify each launcher opens the modal with correct recipients/context; do NOT re-test modal internals):
  6.1 Support tile · 6.2 Assessments · 6.17 Content · 6.18 Objectives · 6.15 button styles.
- **Block C — Error / edge:**
  6.5 generate error (e.g. stop `ollama serve`, then Generate) · 6.12 context-builder error.
- **Block D — Automated gates:**
  6.19 (`mix test` + `mix format --check-formatted`).

> **Manual-testing phase:** only commit if a case surfaces a **bug or an improvement** → then fix via TDD → commit. Otherwise just tick the checkboxes; no commits.

#### Prerequisites

- Admin login: http://localhost/authors/log_in → `admin@example.edu` / `changeme`
- Verify `:instructor_email` FeatureConfig: `Oli.Repo.get_by(Oli.GenAI.FeatureConfig, feature: :instructor_email)`
- Dashboard URL: http://localhost/sections/example_course_section/instructor_dashboard/insights/dashboard?dashboard_scope=course
- Admin sections list: http://localhost/admin/sections
- Seed demo data: **already present in this machine's dev DB** (verified 2026-06-08) — `example_course_section` (9 students, 2 without email), `dashboard_hierarchy_demo` (8), `dashboard_objectives_demo` (8). Enrolled-but-no-activity students intentionally surface in every entry point (Support→"Not enough information", Objectives→"Not enough data", Assessments→"not completed", Overview→listed), so no seeded attempts are needed. ⚠️ The original `scripts/dev/seed_dashboard_data.exs` is **lost** (was dev-only / uncommitted); the data survives in the dev DB but would need re-creation if the DB is reset or on a fresh environment.
- AI draft generation runs against **local Ollama** (no cloud key/cost): `:instructor_email` FeatureConfig → RegisteredModel `ollama-local` (provider `:open_ai`, model `llama3.1:8b`, `url_template http://localhost:11434`). Requires `ollama serve` running with the model pulled (`ollama list`). Generate-success (6.4) is testable locally; verified the OpenAI-compatible `/v1/chat/completions` + `response_format: json_object` returns `{subject, body}`.
- Hierarchy demo section (6.17): http://localhost/sections/dashboard_hierarchy_demo/instructor_dashboard/insights/content
- Objectives demo section (6.18): http://localhost/sections/dashboard_objectives_demo/instructor_dashboard/insights/learning_objectives

#### 6.1 — Student Support Tile → Modal — ✅ PASS (2026-06-08)

- [x] Navigate to dashboard URL. Wait for tiles to load.
- [x] Click a bucket (Struggling/Excelling/On Track/Inactive) to expand student list
- [x] Select students via checkboxes
- [x] Click **"Email Selected"** button
- [x] Modal opens with selected students as recipient chips
- [x] Tone buttons visible: Neutral (selected), Encouraging, Firm
- [x] Subject input empty, Body editor empty
- [x] "Generate New Draft" enabled
- [x] "Send" appears disabled — greyed + `aria-disabled="true"`, but still keyboard-focusable (not hard-`disabled`); empty subject + body
- [x] Footer shows "Fields contained in square brackets like {first_name} will be personalized automatically." (matches Figma node 1115:18333; note: the "square brackets / {braces}" wording is a known design inconsistency carried from the mock — not an impl bug)

> Verified: bucket `on_track` → toggled Carol (id 6) + Grace (id 10, no email) → "Email Selected" → modal opened with Carol chip + Grace in the excluded note. Recipient wiring correct. (Context `situation_key` not distinguishable here — dev students have no activity → all map to `beginning_course`; data limitation, not a wiring bug.)

#### 6.2 — Assessment Tile → Modal — ✅ PASS (2026-06-08)

- [x] Same dashboard page
- [x] Expand an assessment row (click it)
- [x] Click **"Email Students Not Completed"**
- [x] Modal opens with auto-populated recipients (students without attempts)
- [x] Same modal structure as 6.1

> Verified: expanded "Page one" (assessment_id 2, status 6/8 completed) → "Email Students Not Completed" → `grades_oracle.students_without_attempt_emails` (row_count=2, ~90ms single query, no N+1) → modal auto-populated the 2 non-completers (Emma Garcia + Frank Brown). Recipients correctly derived from completion data — the core context-aware behavior.

#### 6.3 — Tone Selection — ✅ PASS (2026-06-08)

- [x] Open modal via either tile
- [x] Click **Encouraging** — shows `aria-pressed="true"`, Neutral shows `false`
- [x] Click **Firm** — Firm pressed, others not
- [x] Changing tone does NOT auto-trigger generation

> Verified via server logs: `set_tone encouraging` then `set_tone firm` fired, **no** generate event; Subject + Body stayed empty. Radio-like single selection, readable selected style (post-contrast-fix).

#### 6.4 — Generate Draft — ✅ PASS (2026-06-08)

- [x] Click **"Generate New Draft"**
- [x] During generation: button shows "Generating draft..." with spinner, button disabled
- [x] On success: subject populated, body populated, button changes to "Regenerate Draft"
- [x] "Send" button becomes enabled
- [x] Click **"Regenerate Draft"** — new draft replaces previous subject + body
- [x] While regenerating, "Send" returns to disabled (greyed / `aria-disabled`), then re-enables when the new draft arrives (#1)

> Verified via Ollama (`llama3.1:8b`): placeholders (`{course_name}`, `{instructor_name}`, `{first_name}`) preserved as tokens for send-time personalization; firm tone reflected; regenerate produced distinct subject+body. Config lookup = 3 queries/generate (feature_config → service_config → registered_model), **no recipient N+1**.

> **⚠️ BACKLOG (separate ticket — NOT MER-5642; write at end of manual testing): GenAI model inflight-counter underflow.**
> **Symptom:** `[warning] GenAI counter below zero for {:inflight, :model, 1}; clamping to 0` fires once per draft generation.
> **Root cause (confirmed by code read):** asymmetric admit/release in the shared GenAI routing layer.
> - `OliWeb`… → `Oli.GenAI.Router.admit_model_if_enabled/1` increments the model inflight counter **only if** `model_limit_enabled?/1` (routing breaker enabled for the model). Breaker **disabled** → returns `:ok` **without** incrementing.
> - `build_plan` always tags the plan `admission: :admit`.
> - `Oli.GenAI.Execution.release_admission!/1` **unconditionally** decrements the model counter for any non-`:bypass` plan.
> - So a model with the breaker disabled (local Ollama, id 1): admit `+0`, release `−1` → counter underflows. Pool counter is balanced (always `+1/−1`).
> **Impact:** functionally clamped to 0 today (harmless), but the model inflight count is wrong → under real load the routing breaker's concurrency tracking is skewed.
> **Scope:** shared GenAI routing infra (`lib/oli/gen_ai/router.ex`, `lib/oli/gen_ai/execution.ex`, `lib/oli/gen_ai/admission_control.ex`) — MER-5642 only *exercises* it; NOT introduced here. Out of scope for this PR.
> **Proposed fix (one line):** in `admit_model_if_enabled/1`, the `else` branch should still `AdmissionControl.increment_model(model.id)` (track inflight without enforcing a cap — mirrors the `max_concurrent: nil` path in `admit_model/1`), so admit/release stay balanced.
> **Test plan:** ExUnit regression — admit a model with breaker disabled, then release, assert `model_count` stays `>= 0` and no underflow warning; assert balanced count after a full admit→release cycle.

#### 6.5 — Generate Draft Error — ✅ PASS (2026-06-08)

- [x] Trigger error (disconnect network / AI service down)
- [x] Error message appears (e.g., "Draft generation timed out")
- [x] Generate button re-enables for retry

> Verified by stopping the local Ollama service (`brew services stop ollama`) → Generate New Draft → inline red error **"AI service is temporarily unavailable. Please try again."**; modal stayed open; Generate re-enabled (not spinning). Graceful degradation confirmed. (Wording is the service-unavailable path, distinct from the G-J08 no-draft-yet fallback — both valid.)

> **Two bugs found during the 6.18 objectives re-test + fixed (committed):**
> 1. **Email modal z-index / overlay (commit `ef5d5acf41`).** From the Objectives entry point, the Draft Email modal was rendered inside the objectives table's expanded `<td>` (`StudentProficiencyList`), trapping it under the table's sticky `thead z-[40]` so the header bled over the modal. We introduced this nesting in 5.5 (`54f0bd2e41`). Fix: hoist the modal to a sibling of the table in `LearningObjectives` (state lifted via `email_modal_payload` → EmailButton → root router → LearningObjectives), mirroring the working `Students` path. Verified: 88 component + 239 dashboard-live tests; browser-confirmed the modal now overlays the dimmed page cleanly.
> 2. **Dangling `<label>` a11y (commit `087cc4d915`).** The "To:" (`recipient_chip_list`) and "Body:" (`draft_email_modal`) labels were `<label>` elements labelling ARIA `role="group"`/`role="textbox"` containers via `aria-labelledby` — DevTools "label not associated with a form field". Fix: `<label>` → `<span>` (ids/classes/aria refs unchanged; identical SR behavior). Subject keeps its real `<label for>`.

#### 6.6 — Subject Editing — ✅ PASS (2026-06-08)

- [x] Edit subject field → value updates
- [x] Clear subject completely → "Send" returns to disabled (greyed / `aria-disabled`)
- [x] Type new subject → "Send" re-enables (if body present)

> Subject pushes per-keystroke (`update_subject`, ~0.3–0.8ms reply) — intentional, not debounced (gives instant Send gating; subject is a short field). Body is the debounced one (6.20). No action.

#### 6.7 — Recipient Management — ✅ PASS (2026-06-08)

- [x] Click X on a recipient chip → chip removed
- [x] Remaining recipients still shown
- [x] Remove all recipients → "Send" disabled (greyed / `aria-disabled`)
- [x] Empty state: "No students currently need this message" (full: "…You can review the draft, but sending stays disabled until at least one recipient is available.")

> **Bug found + fixed (TDD): stale Send-validation message.** After clicking Send while incomplete, the inline error (e.g. "Add a subject before sending.") persisted unchanged after the user filled that field — it was only cleared on `generate_draft`, never on `update_subject`/`update_body_slate`/`remove_recipient`/`set_tone`. Fix: new `clear_validation/1` (clears both visible `:error` and the SR `:live_announcement`) called from all four edit handlers — matches the click-to-validate design (error shows on Send attempt, clears on next edit). Test `draft_email_modal_test.exs:534`. 32 modal tests pass.

#### 6.8 — Excluded Recipients — ✅ PASS (2026-06-08)

- [x] Open modal where a selected student has no email on file
- [x] Note appears: "N selected student(s)" + " do/does not have an associated email…"; names are in the tooltip (`title`) AND exposed via `aria-label` on the focusable span (screen-reader/keyboard accessible — see U1 fix). **Verified:** selected Alice+Bob+Grace (no email) → note "1 selected student does not have an associated email and will not receive this message."; Alice/Bob remain valid chips. `title`+`aria-label` carry the name(s) (`recipient_chip_list.ex:80-81`, capped at 3 + "…and N others", "Unknown student" fallback).

#### 6.9 — Send Email — ✅ PASS (2026-06-08)

- [x] Generate draft (or manually fill subject + body), at least one recipient
- [x] Click **"Send"**
- [x] Modal closes
- [x] **Page stays responsive after close**: scroll works, no leftover backdrop blocking clicks, flash banner visible (not trapped under the sticky header). Guards the send-close teardown regression.
- [x] Flash message: email sent confirmation ("Success! Email sent to 1 student(s)")
- [x] Verify Oban jobs: `Oli.Repo.all(Oban.Job) |> Enum.filter(& &1.worker == "Oli.InstructorDashboard.Email.SendWorker")`

> ✅ 1 SendWorker job enqueued — args: `to: alice.johnson@example.edu`, `subject: "HI"`, html+text body, `section_id: 1`, `situation_key: "beginning_course"`, `user_id: 4`. Flash visible below nav, page interactive (teardown clean).
> **Also closes 6.20 box 2/3 + 6.21 box 3:** typed body to "…going to be late." then immediately clicked Send → Oban job body = the **full** text (debounced push flushed, no lost trailing chars); Send was enabled and dispatched.

#### 6.10 — Cancel / Close

- [x] Open modal, make changes (tone, subject)
- [x] Click **"Cancel"** → modal closes
- [x] Reopen modal
- [x] Click X (close) button → modal closes
- [x] Inspect X button: `aria-label="Close draft email modal"`
> ✅ PASS (2026-06-08) — both `close_email_modal` paths (Cancel + X) fire and close; X aria-label confirmed in snapshot.

#### 6.11 — Keyboard Navigation — ✅ PASS (2026-06-08)

- [x] Open modal
- [x] Tab through: chips → subject → tone buttons → Generate → body → Cancel → Send → Close (X)
- [x] Focus stays trapped inside modal (doesn't escape to background)

> Focus trap holds, all controls reachable, Esc closes. On open, initial focus lands on the **first focusable element** (the first recipient chip's remove-X) via the shared modal's `JS.focus_first` (`modal.ex:324`). **Researched (W3C ARIA APG — Dialog/Modal pattern):** default = focus first focusable element ✅; the "focus the least-destructive action" exception applies only to *irreversible final steps* (delete data, financial transaction) — removing a recipient chip is trivially reversible, so it does **not** apply. Behavior is APG-compliant. **Not a bug; accepted as-is.**
- [ ] Press **Escape** → modal closes

#### 6.12 — Context Builder Error — ✅ PASS (by automated test) (2026-06-08)

- [x] Hard to trigger manually — requires invalid situation_key (no UI path produces one)
- [x] If testable: error "Unable to prepare email context" shown, Generate disabled. **Covered by** `draft_email_modal_test.exs:581` (`situation_key: :nonexistent_situation` → asserts "Unable to prepare email context"); passes.

#### 6.14 — Body editor toolbar restricted to Link (Task 1) — ✅ PASS (2026-06-08)

- [x] Open any Draft Email modal (e.g. via 6.1)
- [x] In the Body editor toolbar, only the **Link** button is visible (no bold/italic/code/blocks/undo)
- [x] Select text → click Link → inline link popover still works (editing flow intact). **Verified:** selected "syllabus" → Link → Settings dialog (Page-in-course / External / Media + URL) → Save; slate node `type: "a", href: "https://example.com", linkType: "url"`. Link UI fetches course pages only on open (`GET …/link`, 200/57ms).

#### 6.15 — "Email Selected" button matches Figma (button fix) — ✅ PASS (2026-06-08)

- [x] On the Student Support tile (6.1), select ≥1 student to enable the button
- [x] Inspect the **Email Selected** button (enabled state): transparent background, 8px corner radius, 4px gap between mail icon and label, white `#FFFFFF80` border

> Verified in code (`email_button.ex:28`, `:minimal` variant used by support tile `student_support_tile.ex:418`): `!bg-transparent` (transparent ✅), `!rounded-lg` (8px ✅), `!gap-1` (4px ✅); border from `:secondary` → `border-Border-border-bold` = `#FFFFFF80` dark (matches Figma dark mock) / `#8AB8E5` light (token counterpart). All four properties match.

#### 6.16 — Student Overview → Modal (5.3) — ✅ PASS (2026-06-08)

- [x] Navigate to http://localhost/sections/example_course_section/instructor_dashboard/overview/students
- [x] Select students via row checkboxes (e.g. Bob Smith, Alice Johnson — both have email)
- [x] Click **Email** → **Send email**
- [x] The **context-aware Draft Email modal** opens (tone buttons + "Generate New Draft" — NOT the old plain modal) with selected emails as recipients

> **Bug found + fixed (tone-button contrast).** Selected tone button rendered blue text on a dark-blue fill in **light mode** (unreadable). Root cause: active state used `bg-Fill-Buttons-fill-secondary-hover` (light `#1B67B2`) paired with blue text. Verified vs Figma node `955:17500` (no dark-blue selected-tone fill in design) + DS node `1007:432` (secondary button) + the codebase secondary-button primitive (`button.ex:594` uses `Surface-surface-secondary-hover`). Fix: active branch → `bg-Surface-surface-secondary-hover` (light `#F2F9FF`+blue text; dark `#2F2C33`+white). Localized to the modal — rejected the global token-value fix (would regress the support-tile `View Profile` hover, which is white-on-`#1B67B2`). 31 modal tests pass; no behavior test touched the class.

#### 6.17 — Content → Student list → Modal (5.4) — ✅ PASS (2026-06-08)

- [x] Navigate to the hierarchy demo section content URL (Prerequisites)
- [x] Click a **Unit** to reach its student-insights list (nav goes Units → unit list directly; there is **no** "Module 1" drill-down at this level — earlier doc wording was inaccurate, corrected)
- [x] Select students → **Email** → **Send email**
- [x] Draft Email modal opens, scoped to the container, with recipients

> Verified: `dashboard_hierarchy_demo` (section_id 3) → Content → Unit 1 student list → selected ids 4 (Alice) + 5 (Bob) → modal opened with both chips, no excluded note (matches DB roster). Roster confirmed via direct Ecto query.

#### 6.18 — Learning Objectives → Student list → Modal (5.5) — ✅ PASS (2026-06-08)

- [x] Navigate to the objectives demo section learning-objectives URL (Prerequisites)
- [x] Expand objective **parent1** → click a proficiency level (e.g. **Low**)
- [x] Select students in the proficiency list → **Email** → **Send email**
- [x] Draft Email modal opens with the objective context (Low → `:low_proficiency_objectives`) and recipients

> Verified: `dashboard_objectives_demo` (section_id 4) → expanded objective parent1 (id 82) → **High** band → `show_students_list proficiency_level: "High"` → selected ids 11 (Henry) + 4 (Alice) → modal opened with both chips. Recipients scoped to the objective's proficiency band (context-aware). Roster confirmed via direct Ecto query.

#### 6.19 — Automated Checks — ✅ PASS (2026-06-09)

- [x] `mix format --check-formatted` — clean (exit 0)
- [x] `mix test …/draft_email_modal_test.exs` — **32** pass (added stale-validation regression test)
- [x] `mix test …/markdown_to_slate_test.exs` — **8** pass
- [x] `mix test …/instructor_dashboard_live_test.exs` + `…/learning_objectives/` — **95** pass (incl. new LearningObjectives modal-render-outside-table test)
- [x] `mix test …/button_test.exs` — **11** pass (Button `aria_disabled`, atom-key globals, backward-compat)
- [x] `mix test …/link_validator_test.exs` + `…/sections_test.exs` — pass (incl. `/course/link` single-slug, `get_section_with_base_project`)
- [x] No new compile warnings (`mix compile --warnings-as-errors` clean)

> Run 2026-06-09: format clean; **262** MER-5642-related tests pass across the listed files (167 unit/component + 95 live/objectives). No warnings.

#### 6.20 — Body editor debounce (browser-only; no unit test)

The body editor pushes are debounced (400ms) via `RichTextEditor` `onEditDebounceMs`, flushed on blur/unmount. This path runs through Slate + the LiveReact bridge and is not unit-tested — verify manually:

- [x] Open a Draft Email modal; type a multi-word body. Confirm typing is smooth (pushes coalesced, not per-keystroke). **Verified 2026-06-08:** ~7 `update_body_slate` pushes for ~70 chars (one push spanned "ed to put more a" = 16 chars) — clearly coalesced, not per-keystroke.
- [x] Type body + subject, then **immediately click Send** (within ~400ms of the last keystroke). The sent email body must contain the **full latest text** (blur-on-Send flushes the pending push — guards against losing the last characters). **Verified at 6.9:** Oban job body = full typed text, no lost trailing chars.
- [x] Generate a draft, edit the body, Send → body reflects the edits. **Verified at 6.9:** sent body matched the edited text.
- [x] Sanity: the other `RichTextEditor` callers (course-authoring page options, curriculum entry options) are unaffected (no `onEditDebounceMs` passed → unchanged behavior). **Verified:** `grep onEditDebounceMs` → set only at `draft_email_modal.ex:169` (=400); absent prop → `debouncedPush = null` → immediate push (unchanged).

#### 6.21 — Send button state: aria-disabled + click-to-validate (U4, #1)

The Send button is no longer hard-`disabled`; it is **`aria-disabled`** (greyed but focusable) and validates on click. Verify:

- [x] With an incomplete draft (missing recipients, subject, or body), inspect "Send": greyed, `aria-disabled="true"`, and **keyboard-focusable** (Tab reaches it; not the HTML `disabled` attribute). **Verified 2026-06-08:** code `modal:212 aria_disabled={@send_disabled}` (no hard `disabled`); screenshot shows Send with a **focus ring** (focusable → confirms aria-disabled, not hard-disabled).
- [x] Click (or Enter/Space) "Send" while incomplete → it does **NOT** send; an inline message names what's missing, e.g. "Add a subject and a body before sending." (omits any item already present). **Verified:** subject-only-missing → inline red **"Add a subject before sending."**; no send fired (modal stayed open).
- [x] Complete the draft (≥1 recipient + subject + body) → "Send" becomes enabled (no `aria-disabled`), and clicking it sends. **Verified at 6.9:** Send enabled with recipient+subject+body, click dispatched + enqueued the job.
- [x] Screen reader announces the Send button's disabled/enabled state as it changes (it's reachable, unlike a hard-disabled button). **Verified:** button reachable (focus ring) + status live-region present ("Draft generated. Review the subject and body before sending.").

## PR split

- [x] PR 1 — Backend domain + send pipeline (Phases 1, 2) — MERGED (`09fdf332bc`, PR #6556)
- [~] PR 2 — Modal + entry-point wiring + verification (Phases 4-6) — branch `MER-5642-context-aware-email-draft-modal-ui-implementation`

## Gap status (from `gaps.md`)

| Section | Owner | Open | Proposed | Asked | Answered | Resolved | Total |
|---------|-------|------|----------|-------|----------|----------|-------|
| B1 — Jira scope (Jess + Darren) | Jess / Darren | 0 | 0 | 0 | 0 | 12 | 12 |
| B2 — Figma design states (design) | design team | 0 | 0 | 0 | 0 | 14 | 14 |
| B3 — Token drift (design) | design team | 0 | 0 | 0 | 0 | 3 | 3 |

Update these counts as `gaps.md` items move through statuses.

## Session History

### Session 1 — 2026-05-04
- Fetched Jira ticket + 3 comments.
- Fetched Figma node `955:17500` (dark variant only).
- Token mapping completed; identified DR1/DR2/DR3 drift.
- Confirmed prior-art folder `docs/exec-plans/current/epics/intelligent_dashboard/email_sending/` already contains `informal.md`, `prd.md`, `requirements.yml`.
- Verified PRD/requirements coverage vs Jira+comments; found 4 transcription gaps (PRD-G1..G4).
- Wrote `gaps.md` with 29 open decisions across B1/B2/B3.
- Updated `prd.md` and `requirements.yml` to capture PRD-G1..G4 (added FR-013, FR-014, FR-015, AC-016).
- Built dev LiveView at `/dev/mer-5257` for live doc viewing.
- Wrote `plan.md` (six phases, four PRs) and this `progress.md`.

### Session 2 — 2026-05-05
- Closed all B1 gaps via codebase research + parallel agents + user decisions:
  - G-J01 (entry points) RESOLVED via codebase exhaustive scan — 5 entry points confirmed.
  - G-J02 (situation enum) RESOLVED — 7 keys derived from existing tile projectors.
  - G-J03 (EmailContext field shape) RESOLVED — fields derived from existing projector @types.
  - G-J04 (partial-fail policy) RESOLVED — send valid + notify failures; no retry UI in v1.
  - G-J05 (required fields) RESOLVED — recipients > 0 + non-empty subject + non-empty body.
  - G-J06 (recipient cap) RESOLVED — env var `INSTRUCTOR_EMAIL_MAX_RECIPIENTS` default 100, fail-closed.
  - G-J11 (feature flag) RESOLVED — no flag (trust PRD §11).
  - G-J12 (AI quota) RESOLVED — Option C, defer per-section quota.
- Reverted G-J07 (manual recipients) after finding `EmailList` precedent; surfaced to Jess; she answered: section-enrolled students only.
- Closed all B2 gaps:
  - G-D01 (light mode) verified missing in Figma; resolved via token-system insight (Tailwind tokens carry both light + dark variants).
  - G-D02..G-D14 RESOLVED via parallel agent research; reused existing patterns (button primitives, `summary_tile` AI spinner, `student_support_parameters_modal` validation banner, `OverflowChipList`, base modal Cancel pattern, Slate `RichTextEditor`).
- Closed all B3 token drift gaps:
  - G-T01 RESOLVED — add new token `Fill-Buttons-fill-primary-bold` (#0062F2), do not overwrite existing.
  - G-T02 RESOLVED — scrollbar drift, browser-managed, ignore.
  - G-T03 RESOLVED — light value used cross-mode for scrollbar contrast, no token change.
- Confirmed via Slack with Jess: G-J07 enrolled-only, G-J08 interim copy approved, G-D05 banner pattern + resolver fallback approved, G-D09 Slate-restricted approach.
- Updated `prd.md`, `requirements.yml`, `plan.md`, `gaps.md`, this file.
- Committed Phase 0 artifacts as `[FEATURE] [MER-5257] Add Phase 0 planning docs and dev doc viewer` (`82f99e0ae4`).
- Pushed branch + opened draft PR.
- **Next:** begin Phase 1.1 — Situation enum + lookup map module, following the closed list of 7 situation keys from G-J02.

### Session 3 — 2026-05-08
- Phase 1 already implemented in prior sessions (chunks 1.1-1.5 complete with full ExUnit coverage). This session focused on verification + hardening.
- Added manual verification script `scripts/dev/email_sending_phase_1_check.exs` covering 7 sections (Situation, ContextBuilder, PromptComposer, DB rows, AIDraftFacade with mocks, telemetry, optional real-AI). 35/35 sections pass.
- Honest gap analysis: real provider error shapes coverage. Read `lib/oli/gen_ai/execution.ex` + `router.ex` + provider modules; enumerated every error shape that reaches `coerce_execution_error/1`. Verdict: every shape lands somewhere, all timeouts mapped to `:timeout`, everything else to `:provider_error`. Three sub-categories (429 rate limit, capacity rejection, mis-config) collapse into `:provider_error` — flagged as Phase 4+ candidate to split if UI copy distinguishes.
- Researched real-AI test patterns via `/research validate` skill. Two parallel agents (codebase precedent + industry patterns). Findings: codebase has zero precedent for real-AI tests; brainlid/langchain Elixir-LLM precedent uses tagged-live + fixtures; ExVCR doesn't support Tesla/Req.
- Decided against tagged-live ExUnit test (would always be skipped locally; required infra absent). Instead: added fixture replay layer — 5 inline private-function fixtures in `ai_draft_facade_test.exs` (3 happy-path situation/tone variants + 2 edge fixtures: markdown-fenced JSON, trailing prose). Documents current parser strict behavior on messy outputs.
- Phase 1 verification now multilayered: (1) mocked unit tests (84 total) for contract correctness, (2) fixture replay (5) for ambient regression catching, (3) manual script (`EMAIL_PHASE1_REAL_AI=1` env-gated) for real-provider smoke.
- Personal-config artifacts (NOT in repo): added `~/.claude/projects/<key>/memory/feedback_pattern_prereq_audit.md` (rule about auditing pattern prerequisites before recommending) + `~/.claude/projects/<key>/infra/INFRA.md` (codebase capabilities inventory).
- Drift surfaced: `oli-torus/.claude/commands/spec_review.md` references `.agents/skills/spec_review/` — directory does not exist. Cleanup candidate (separate commit).
- **Next:** commit Phase 1 (this session's plan/progress doc updates + chunk 1.x code + tests + script). After commit: decide Phase 2 vs B1-B3 gap-research refresh.

### Session 4 — 2026-05-11
- Locked remaining Phase 2 architectural decisions in `plan.md` (committed `0f87bebd1b` + `5510b2a937`): Option B substitution timing, dedicated `SendWorker`, token-to-value mapping, sender identity, Premailex reuse, `Oban.insert_all` error semantics, telemetry locus.
- Audited codebase prerequisites before coding: `Premailex` dep (`mix.exs:208`), `Oli.Mailer` interface (Swoosh, `deliver_later/1` accepts list → one job per email), `Oli.Email.base_email/0` for system from + instructor reply_to, `Oli.Mailer.SendEmailWorker.serialize_email/1` reusable, brace preservation through `Oli.Rendering.Content.Html.escape_xml!/1` + client `html.tsx:88` writer.
- Implemented Phase 2: 5 new lib modules (`email.ex` parent + `substitution.ex`, `realization.ex`, `validator.ex`, `send_worker.ex`) + 5 test files (54 new tests).
- Extended `EmailContext` with `:instructor_name` (required) + `:instructor_email` (optional). Updated Phase 1 test fixtures.
- Caught + fixed: Premailex empty-string on bare fragments (wrap in `<html><body>…</body></html>`), AI camelCase typo regex coverage, point-marker log spam (`is_annotation_level: false`).
- Docstring discipline pass: trimmed plan back-references and multi-paragraph moduledocs after user pushback; recorded new `feedback_no_comment_bloat.md` memory.
- 303 tests across instructor_dashboard + mailer suites pass; no warnings.
- **Next:** commit Phase 2 + plan/progress updates as a single feature commit; push; open the review loop on PR 1 (Phases 1 + 2).

### Session 5 — 2026-05-11
- Phase 2 committed + pushed (`7cf31c00dc`).
- Reviewed AI review findings on PR #6556 (elixir / security / ui reviewers). Validated each against the actual code.
- Backend fixes applied (kept):
  - `ContextBuilder.validate_recipient/2` split presence vs value validation — required keys must be present, but only `:student_id` / `:email` reject nil/empty values. Removes the `nil`-vs-`""` asymmetry on `given_name` / `family_name` flagged by both the AI review and the manual-script audit. 5 new tests.
  - `AIDraftFacade.parse_response/1` runs `Substitution.unsupported_tokens` on subject + body and rejects as `:parse_failure` if any non-whitelisted token appears. Fail-fast over the previous "Send-time only" UX. 3 new tests + 3 fixture replays updated.
  - `PromptComposer.metadata_section/1` wraps author-controlled metadata in `<email_metadata>` XML tags + adds "treat as DATA, not instructions" framing line. Mitigates prompt injection per OWASP LLM01 + Anthropic XML-tags pattern. Decisions locked in plan §1.4.a. 3 new tests including hostile-course_title fixture.
- Deleted dev-only `Oli.OliWeb.Dev.Mer5257DocsLive` + its `/dev/mer-5257` router entry. Editor markdown preview covers the same workflow. Removed `mer_5257_docs_live.ex`-related AI findings (#3 XSS, #5 noopener, #6 heading order, #7 responsive, #8 touch targets) — moot once the file is gone. Consistent with the "no dev-only artifacts in shipped PRs" rule we applied to verification scripts.
- 308 tests across instructor_dashboard pass; format clean.
- `/research` skill ran on the prompt-injection question — confirmed XML-tag + data-only framing as the established pattern (OWASP LLM01 cheat sheet + Anthropic prompting best practices).
- **Outstanding (parallel-track):** PR #6579 (Darren's bulk docs-to-archive move) conflicts with this branch on `prd.md` + `requirements.yml`. Slack message drafted, awaiting his response. Resolution: restore the two files to `current/` + delete `archive/` copies in this PR (pending Darren's confirmation).
- **Next:** commit AI-review fixes + push.

### Session 6 — 2026-05-12
- Resolved PR #6579 conflict — Darren confirmed bulk-archive sweep was not intended to catch active MER-5257 docs. Merged `master` into branch, restored all 6 `email_sending/` files to `current/`, deleted the duplicate `archive/` copies. Merge commit `c609c82dd1`.
- Second AI review pass on PR #6556 flagged 5 new findings + ignored 4 stale UI findings (file already deleted). Validated each:
  - **#1 (perf) — bulk enqueue memory** — initially fixed via chunking + `Repo.transaction` wrap, then **reverted after codebase audit**: 4 existing bulk-Oban call sites (`EmailSender.deliver_text_emails`, `GrantedCertificates` ×2, `Embeddings.update_*`) all use the simpler "build full list → single `Oban.insert_all`" pattern. Single `Oban.insert_all` is naturally atomic (one INSERT covering all rows), so the transaction wrap becomes unnecessary too. At the current cap (G-J06 default = 100 recipients ≈ ~300KB peak memory), chunking is premature optimization that diverges from precedent. Align with codebase: removed `@chunk_size` + `chunk_realize_and_enqueue/3`; restored simple `Realization.realize` → `enqueue` → `Oban.insert_all`. If the cap is raised significantly and memory becomes measurable, refactor then with evidence. 60-recipient test retained as scaling smoke.
- **Structured per-recipient errors (post-revert hardening):** the earlier design relied on `Substitution.apply/2` raising `ArgumentError` to halt a partial send. The raise propagated unchanged to the eventual Phase 4 LiveView — the instructor would see a process crash + reconnect with NO actionable error, violating PRD §Reliability ("deterministic success/failure outcomes"). Refactored the substitution pipeline to emit structured errors instead:
    - `Substitution.apply/2` now returns `{:ok, String.t()} \| {:error, [{:nil_value, token}]}` (no raise; accumulates every nil-token in one shot).
    - `Realization.realize/2` now returns `{:ok, [realized]} \| {:error, [{:realize_failed, email, token}]}` — names the specific recipient + token per failure.
    - `Email.send_emails/2` chains validator + realize via `with`; both stages surface their reasons in the caller-facing `{:error, reasons}` tuple. New `:realize_blocked` telemetry event (sanitized of PII) fires when realize catches what validator missed (race-condition or validator-gap detection).
    - LiveView (Phase 4) can pattern-match on `{:error, reasons}` and render an actionable per-recipient list in the modal — "Could not send to alice@x.edu, bob@x.edu — first name missing."
  - Doctests for both `{:ok, ...}` and `{:error, ...}` paths updated. Realization tests + Substitution tests + email_test telemetry tests adjusted for the new return shape. 528 tests pass.
  - **#2 (perf) — feature_config `Repo.all` + in-memory pick** — REAL; was my Phase 1 code (commit `39343e7977`). Fixed: `order_by: [desc_nulls_last: g.section_id]` + `limit: 1` + `Repo.one`. Same semantics, single-row fetch. Existing tests cover.
  - **#3 (elixir) — `Substitution.apply/2` over-broad** — REAL interaction bug with Session 5's #1 fix: `ContextBuilder` now allows `nil`/`""` for name fields; static templates with no `{first_name}`/`{student_name}` token would still crash because `apply/2` iterated the whole whitelist. Fixed: guard `String.contains?(acc, token)` before fetching the value. Existing test flipped + new test confirms no-op behavior on unused tokens.
  - **#4 (security) — PII in `:validation_blocked` telemetry** — REAL leak: validator returns raw student emails inside `{:unresolvable_placeholder, token, emails}`, which was emitted verbatim to telemetry handlers. Fixed: new `sanitize_reasons_for_telemetry/1` strips the email list down to `length(emails)` before emit; caller-facing return value retains the full email list for UI display. New test verifies sanitization + caller fidelity.
  - **#5 (security) — prompt metadata delimiter breakout** — REAL: my `<email_metadata>` mitigation from Session 5 was bypassable via a course title containing literal `</email_metadata>`. Fixed: new private `escape/1` helper XML-escapes `&`, `<`, `>` in all interpolated metadata values (course_title, scope_label, assessment/objective/content_item titles, support bucket label). Plan §1.4.a updated with the hardening note. Two new tests cover delimiter-breakout attempt + general metacharacter escape.
- 525 tests pass across instructor_dashboard + gen_ai; format clean.
- **Outstanding:** none for this PR. PR 1 (Phases 1 + 2) is ready for human review.
- **Next:** commit + push the AI-review hardening batch.

### Session 7 — 2026-05-12
- Third AI review pass on PR #6556 (after `44ac7e060a` push) surfaced 6 new findings. Validated each against actual code.
- **#1 (perf) — bulk enqueue memory** — re-flagged. Re-rejected with the Session 6 codebase audit rationale (4 production call sites all use single `Oban.insert_all`; chunking is premature at cap=100). Decision recorded in progress.md Session 6; AI lacks that context.
- **#2 (perf) — validator `O(tokens × recipients)`** — fixed. `check_token_resolvability/3` now precomputes each recipient's values map ONCE (`{email, values}` tuples), then iterates tokens against that precomputed list. `values_for/2` is called N times (was N × M). Cheap refactor — same logic, reordered. Existing tests cover.
- **#3 (elixir/security) — HTML-escape recipient values in `html_body`** — REAL XSS vector. A recipient `given_name` of `<script>alert()</script>` would be injected as live markup into the outgoing email's HTML body. Fixed: `Realization.realize_one/3` now builds two values maps — raw values for `subject` + `text_body`, HTML-escaped values (`&`, `<`, `>`, `"`, `'`) for `html_body`. Plan §2.2.i locks the rule. Two new tests cover hostile `<script>` in given_name + ampersand/quote escaping.
- **#4 (elixir) — validator missed tokens used only in `html_body`** — REAL. `Validator.check_token_resolvability/3` only scanned `template.subject + template.text_body`. Widened to include `template.html_body`. New test confirms a token present only in html_body is now caught.
- **#5 (security) — AI-generated link phishing risk** — researched via `/research` skill (twice). First pass identified OWASP LLM01 + Anthropic patterns + EchoLeak (CVE-2025-32711) + Netcraft's 30% URL-hallucination rate + CVE-2026-26133 (Copilot summary phishing). Second pass validated `Phoenix.Router.route_info/4` as the runtime route-verification mechanism — already used in 2 existing oli-torus call sites (`set_route_name.ex:24`, `certificate_settings_live.ex:47`). Implementation: AI prompt forbids absolute URLs (allows only relative paths); `AIDraftFacade.sanitize_links/1` strips any markdown link whose URL has a scheme, host, doesn't start with `/`, contains `..` traversal segments, or fails `route_info`. Emits `:link_stripped` telemetry with count on every parse. Plan §1.4.b + §1.4.c locked. 10 new tests cover: valid path kept; absolute URL stripped; `javascript:` stripped; protocol-relative stripped; `..` traversal stripped; unknown route stripped; selective strip in mixed body; no-links body unchanged; telemetry fires on strip; telemetry does NOT fire on clean body. Future enhancement (Phase 5+): URL-menu pattern for safely allowing AI-suggested in-system links with per-entry-point allowlist.
- **#6 (security) — raw provider errors leaked through telemetry** — REAL. `emit_event(:failed, ..., %{reason: coarse, raw_reason: inspect(reason, ...)})` exposed provider error payloads (possibly containing prompt fragments, headers, tokens) to telemetry handlers. Fixed: dropped `raw_reason` entirely; emit only the coarse atom. Removed the `@inspect_opts` module attribute. Existing telemetry test updated to assert no `:raw_reason` key + no provider details in metadata.
- 541 tests + 2 doctests across instructor_dashboard + gen_ai pass; format clean.
- **Outstanding:** none for this PR.
- **Next:** commit + push the AI-review pass-3 hardening batch.

### Session 8 — 2026-05-13
- Fourth AI review pass on PR #6556 surfaced 6 new findings. Validated each.
- **#1 (perf) — chunk bulk job insertion** — third re-flag. Decision unchanged: rejected per Session 6 codebase audit (4 production call sites all use single `Oban.insert_all`; cap=100 → ~300KB peak memory; single INSERT is atomic). Documented again.
- **#2 (elixir) — `Oli.InstructorDashboard.Email.AIDraftFacade` calls `OliWeb.Router`** (cross-layer dependency) — REAL per `ARCHITECTURE.md` (which documents `Phoenix → Domain`, one direction). However, proper fix requires either moving link sanitization to an `OliWeb.Email.LinkSanitizer` module + injecting it as a callable opt into `AIDraftFacade.generate/2`, OR making the caller (Phase 4 LiveView) responsible for sanitization. Both options carry security regression risk if implemented now (default-no-sanitize). Decision: **defer to Phase 4** — wire the OliWeb sanitizer through Phase 4 LiveView as a natural boundary. Documented as Phase 4 prerequisite in plan.md (TBD entry). Precedent: 4 existing `Oli.*` modules also reference `OliWeb.*` (`Oli.Grading`, `Oli.Application`, `Oli.Email`, `Oli.Utils`) — known cross-layer pattern in this codebase.
- **#3 (elixir) — optional prompt metadata not escaped** — REAL gap in §1.4.a coverage. `format_optional/2` interpolated `format_value(value)` directly. Fixed: `format_optional/2` now wraps `format_value(value)` in `escape/1`. Closes the `</email_metadata>` delimiter-breakout vector for any value flowing through assessment/objective/content_item/support_bucket optional fields (e.g., `proficiency_label`). New test: `objective.proficiency_label = "</email_metadata>..."` is escaped, no breakout.
- **#4 (elixir) — substitution reprocesses replacement values** — REAL security correctness bug. Old `Enum.reduce(@token_pairs, template, ...)` accumulated `acc` across passes; a recipient with `given_name = "{course_name}"` would substitute first_name → `"{course_name}"`, then next pass would see and substitute that into the real course name. **Fixed**: `Substitution.apply/2` now uses single-pass `Regex.replace/3` over the ORIGINAL template. Values inserted are literals — regex does not re-scan. Plan §2.1.d locked. Two new tests cover the chain-substitution attack.
- **#5 (elixir) — unsupported placeholder detection too narrow** — REAL. Old regex `~r/\{[a-zA-Z_]+\}/` only matched bare letters/underscores. Tokens like `{first-name}`, `{first_name1}`, `{First Name}`, `{ first_name }` slipped through detection. **Fixed**: broadened to `~r/\{[^{}]+\}/` — any non-empty brace-delimited string. Plan §2.1.e locked. Four new tests cover hyphenated, digit-suffixed, spaced-letter, and leading-whitespace variants.
- **#6 (security) — instructor_email not validated before Reply-To** — REAL. `maybe_reply_to/2` set the `Reply-To` header from `context.instructor_email` without format check. **Fixed**: `Validator.check_instructor_email/2` runs alongside recipient email validation. If set, must match `@email_regex`; otherwise returns `{:invalid_instructor_email, addr}` reason. Nil/empty instructor_email is acceptable (no Reply-To set). `Email.sanitize_reasons_for_telemetry/1` extended to strip the address (`:invalid_instructor_email` atom only). 4 new tests cover nil, empty, malformed, valid.
- 553 tests + 2 doctests pass; format clean.
- **Outstanding:** #2 architectural decoupling deferred to Phase 4 — TODO entry will live in Phase 4 plan section.
- **Pre-commit `/security-review` skill run:** no HIGH-confidence vulnerabilities. Documented in security-review output.
- **Pre-commit `/review` skill run (general code quality):** 1 Important + 4 Minor findings — all applied in-session before commit:
  - **Important — `SendWorker.perform/1` `:failed` telemetry inspected `reason`/`exception`** (same PII leak Pass 3 #6 fixed in AIDraftFacade). Replaced with new `classify_error/1` returning a coarse atom (`:timeout`, `:network`, `:delivery_error`, `:exception`). Symmetric with AIDraftFacade approach.
  - **Minor — `:link_stripped` telemetry missing base metadata.** Now includes `feature`, `situation_key`, `tone`, `recipient_count` — consistent with sibling `:generated` / `:failed` draft events. `parse_response/1` now takes context to pass through.
  - **Minor — `recipient[:given_name]` Access syntax inconsistent with sibling dot accesses.** Switched to `recipient.given_name` (key presence guaranteed by ContextBuilder).
  - **Minor — `Validator.check_token_resolvability/3` precomputed `recipient_values` even when no recipient-derived tokens were used.** Short-circuit on empty `used`.
  - **Minor — `Realization.nilify/1` and `student_name/1` didn't treat whitespace-only names as nil.** `String.trim` before comparison so `given_name: "   "` is treated as missing data and surfaces via validator's `:unresolvable_placeholder` instead of silently producing `"Hi    "`. Two new validator tests cover whitespace-only first_name + student_name.
- 555 tests + 2 doctests pass after review fixes.
- **Next:** commit + push.

### Session 9 — 2026-05-13
- Fifth AI review pass (post `abb7abe90e` push): only 2 new findings (both elixir, same root cause), perf + security clean. Pass-over-pass noise: 6 → 5 → 6 → 2 — converging.
- **#1 + #2 (elixir) — `send_emails/2` `enqueued` count inaccurate when duplicate recipients hit Oban's unique constraint.** Realistic scenario: Phase 5 entry-point projection puts the same student in multiple buckets; `Realization.realize/2` emits 2 entries; `Oban.insert_all/1` inserts 1 + conflicts 1; we report `enqueued: 2` — wrong. **Fixed (two-layer):**
  - **Validator: new `check_duplicate_recipients/2`** — returns `{:duplicate_recipients, [user_ids]}` reason when any `student_id` appears more than once. Blocks Send upstream with actionable feedback. Plan §2.4.h locked. 3 new tests.
  - **`Email.enqueue/3` returns truth** — `Oban.insert_all/1` returns `[%Oban.Job{}]` with `conflict?` flag per row; count rows where `conflict? == false`. Defense-in-depth against future validator bypass. Plan §2.5.e locked.
  - `Email.sanitize_reasons_for_telemetry/1` extended to strip the `user_ids` list from `:duplicate_recipients` (count only) before telemetry emit.
- 558 tests + 2 doctests pass.
- **Outstanding:** #2 architectural decoupling (Oli → OliWeb in AIDraftFacade) still deferred to Phase 4.
- **Next:** run local `/security-review` + `/review` skills, then commit + push.

### Session 10 — 2026-05-13
- Sixth AI review pass (post `f50e74ec7f`): 5 new findings. Evaluated each with rigor.
- **2 FALSE POSITIVES** (no action):
  - #2 perf — `reasons ++ errs` claimed quadratic. In `a ++ b` Elixir's cost is O(length(a)) — `reasons` (small new) on LEFT means O(per-iteration-new-errors), total LINEAR. AI got the direction backward.
  - #4 elixir — claimed Oban uniqueness `keys` doesn't inspect args. Oban's default `fields` includes `:args`; `keys` filters which args to compare. Our existing dedup integration test (`email_test.exs` "Oban unique [draft_id, user_id]") passes — proves it works.
- **1 RE-FLAG** (no action): #1 perf chunking — fourth time. Decision stands per Session 6 codebase audit.
- **2 REAL** (doc-only updates, applied this session):
  - #3 elixir — API shape mismatch between `AIDraftFacade.generate/2` (returns `subject_template`/`body_template` markdown) and `Email.send_emails/2` (accepts `subject`/`body_slate`). NOT a bug — Phase 4 modal mediates the markdown→Slate conversion per plan §4.5. Updated `AIDraftFacade.generate/2` `@doc` to explicitly call out the shape difference + the modal's conversion responsibility.
  - #5 security — link sanitizer accepts ANY GET route in `OliWeb.Router`, including `/admin`, `/instructor`, `/author`. Phoenix authz would 403 student access but UX is poor. Real defense-in-depth gap. Folded into the existing Phase 5+ URL-menu future-work item (§1.4.b) — same backlog entry now covers BOTH (a) per-entry-point URL allowlist for AI prompt grounding AND (b) student-appropriate route allowlist for parser-side rejection.
- **Diminishing returns hit.** Pass-over-pass new findings: 6 → 5 → 6 → 2 → 2 → 5 (this pass = 3 non-actionable + 2 doc-only). NO new code bugs.
- 558 tests + 2 doctests still pass; format clean.
- **Outstanding:** none for PR 1. #2 architectural decoupling + #5 URL-menu pattern queued for Phase 5.
- **Next:** commit doc-only updates + push. Hand off PR to human reviewer (Darren/team). Local AI review iteration loop has converged.

### Session 11 — 2026-05-25 (MER-5642 planning)

- New ticket MER-5642 covers Phases 4-6 (frontend UI). New branch: `MER-5642-context-aware-email-draft-modal-ui-implementation`.
- PR 1 (Phases 1+2) confirmed MERGED to master (`09fdf332bc`, PR #6556). All backend code available on new branch.
- **Figma context gathered:**
  - Node `955:17500` (Support Email) — primary reference, dark mode. Design context + variable defs fetched.
  - Node `1115:18333` (Assignment Email) — confirms hyperlinks in body, numbered lists.
  - Light mode auto-derived from token system (G-D01 resolved).
- **Figma skill audit:** Only one exists — `~/.claude/rules/figma-to-code.md` (root-level). MCP server skills (`/figma-use`, `/figma-generate-design`) are for writing to Figma, not our use case.
- **Compatibility audit (all components verified against current codebase):**
  - `Modal.modal` — fully compatible. Has `:custom_footer` slot, `<.focus_wrap>` focus trap, Escape close, backdrop click-away, `z-[2000]`.
  - `Button.button` primitive — `:primary`, `:secondary`, `:close` variants. `:icon_left`/`:icon_right` slots. `phx-disable-with` support.
  - `OverflowChipList` hook — battle-tested, already in existing email modal. `data-overflow-chip` / `data-overflow-toggle` structure.
  - Slate `RichTextEditor` — `allowBlockElements={false}` for inline-only. LiveView bridge via `OliWeb.Common.React.component/4` + `phx-update="ignore"`. Link insert via `LinkCmd.tsx`.
  - Icons: `ai_spinner` (188), `send` (2142), `close` (601), `close_sm` (617) — all present in `icons.ex`.
- **Critical dependency verified:** `serializeMarkdown()` exists in `assets/src/components/editing/markdown_editor/content_markdown_serializer.ts`. Converts markdown string → Slate JSON nodes. Used by `MarkdownEditor.tsx`. Phase 4 needs this for AI draft body → Slate editor.
- **Missing items identified:**
  - `Fill-Buttons-fill-primary-bold` token — NOT in `tailwind.tokens.js`. Must add per G-T01.
  - `INSTRUCTOR_EMAIL_MAX_RECIPIENTS` — decided to DROP. No existing email send in codebase has a recipient limit. Follow convention. Add later if abuse surfaces.
- **Phase 4 plan expanded** in progress.md with implementation detail per step (4.0a pre-work through 4.10 testing).
- Deferred items from PR 1 review still queued: #2 architectural decoupling (Oli → OliWeb cross-layer in AIDraftFacade), #5 URL-menu pattern. Both Phase 5+.
- **Next:** begin Phase 4.0a (token addition) then 4.1 (LiveComponent scaffold).

### Session 12 — 2026-05-25 (Phase 4 completion + Phase 5 wiring)

- **Phase 4 completed** — DraftEmailModal LiveComponent fully built (scaffold, recipients, tone, subject, body editor, generate/send/cancel, focus trap, loading/error states, live announcements, tests).
- **Pre-existing Button `:close` variant bug fixed:**
  - Root cause: Phoenix HEEx stores `@rest` keys as atoms (e.g., `:"aria-label"`), not strings. `@rest["aria-label"]` always returned `nil` → `close_aria_label(nil)` → hardcoded `"Close"`, swallowing any custom `aria-label`.
  - Fix: extract `:"aria-label"` and `:title` in `normalize_button_assigns/1` (Elixir code, before HEEx evaluation) where `@rest` keys are still accessible. Updated `:close` template to use explicit assigns + `Map.drop(@rest, [:"aria-label", :title])`.
  - Removed unused `close_aria_label/1` and `close_title/2` helpers.
  - File: `lib/oli_web/components/design_tokens/primitives/button.ex`
- **Phase 5 wiring (5.1 + 5.2):**
  - `StudentSupportTile` — swapped `StudentSupportEmailModal` → `DraftEmailModal`, added `@bucket_to_situation` mapping, `support_bucket_context/1` helper (proper `%{label:, count:}` map).
  - `AssessmentsTile` — swapped similarly, added `assessment_scope_label/1`, `assessment_context/1` helpers.
  - `InstructorDashboardLive` — added `handle_info({:generate_draft, ...})` using `Task.Supervisor.async_nolink(Oli.TaskSupervisor, ...)` with ref tracking in `draft_tasks` map. Success/crash handlers guarantee `deliver_draft_result` always fires.
- **Code review (10 findings addressed):**
  - generate_draft message changed to 3-tuple `{:generate_draft, id, email_context}` (context passed through)
  - `excluded_recipient_students` moved from render to update/2
  - `support_bucket` type mismatch fixed (was bare string, now proper map)
  - `generate_draft/2` signature corrected (takes `(context, opts)` not `(context, tone)`)
  - Duplicate `:DOWN` handler merged with existing recommendation task handler
  - Removed redundant `try/rescue` — switched to `Task.Supervisor.async_nolink` pattern
  - `Process.demonitor(ref, [:flush])` on success path (removes monitor + flushes queued `:DOWN`)
- **Integration tests added** for LiveView `handle_info` handlers (3 tests: success, crash, unknown ref).
- **Flaky test fix:** added `on_exit` callback in `instructor_dashboard_live_test.exs` to wait for `Oli.TaskSupervisor` children before test process exits. Root cause: `start_dashboard_runtime_loads/4` spawns `Task.Supervisor.start_child` with `timeout: :infinity`, tasks outlive test process and crash when Ecto Sandbox connection owner dies.
- **Compile warning fix:** removed duplicate `replace_liveview_sockets/2` helper — reused existing recursive version at line 1113.
- 38 dashboard live tests + 20 DraftEmailModal tests pass.
- **Next:** Phase 6 — E2E verification + browser testing.

### Session 13 — 2026-06-01..06 (AI-review hardening, rounds 1–2)

- **Reconciled** stale `progress.md` (Phase 5 header/5.5/5.7) and corrected Phase 6 checklist strings (6.1 footer copy, 6.8 excluded note, 6.19 test counts).
- **Verified 5.7** "Email sent" banner end-to-end (flash → parent `put_flash` → `#flash_container` z-50). Kept "Email sent to N student(s)" copy per ticket AC over plan §2.5.b's "Queued" wording.
- **Manual-QA / Playwright evaluation:** considered a Playwright E2E suite (infra exists at `assets/automation/`, YAML scenario seeding). Concluded a full suite is overkill — ExUnit already covers server logic; only ~4 browser-only behaviors are uniquely E2E. Chose ExUnit TDD for fixes + a short manual smoke for the browser-only set.
- **AI-reviewer mechanism mapped:** CI uses **OpenAI Codex CLI**, per-role specialists (`.github/workflows/ai-review.yml` + `.review/*.md`), **diff-only / added-lines-only** (silent post-filter). `ui` glob excludes the modal (`lib/oli_web/components/...`).
- **Blind round (15 agents, 3×/role)** → deduped → compared to CI's posted comments → adversarial validation. Artifacts in `ai-review/` (blind/, comparison.md, validation.md). Key insight: Claude and Codex are **complementary** (Claude=cross-file logic/a11y; Codex=security/perf) — union both, don't expect parity.
- **Fixed (TDD, committed):** X1 rebuild email_context on remove; E6 actionable send-error messages; M2+E2 single-query slugs, drop rescue; M1 tone whitelist (no crash); U1 excluded names a11y; U2 subject `aria-required`; U4 Send → `aria-disabled` + click-to-validate (+ additive `Button` `aria_disabled`); E4 `MarkdownToSlate` (reuse `TorusDoc` parser, flatten blocks, validate link targets); round-2: shared `DraftEmailModal.recipients/3` (keep no-email + display_name), compute excluded names once, `/course/link` single-slug regex, MarkdownToSlate link guard.
- **Verified not-required (cited):** X4/X5 render rescan (`:if`+change-tracking); **X6 fan-out backpressure — G-J12 (AI quota deferred)**; U6 i18n (not the repo convention); **S1 authz — mount-gated** (`ensure_instructor`, not UI-only); **S2 send-time re-resolution — snapshot accepted** (short drift window, server-set recipients); E8 footer copy **faithful to Figma** (mock itself says "square brackets like {first_name}"); U3 tone `aria-pressed` (WCAG-valid; no reusable radiogroup component exists); U5 generating cue (live region already announces); M3/E5 broad `{ref,result}` (no behavior change).
- **False positives (proven):** X2/CE-r2-3 arity (prod uses nil branch), X3 close-path (atom keys correct), X7 `/course/link` scheme (cond ordering), E7 variant default, X8 DotChart (CI fix non-functional).
- **Held (decision pending):** **B1** — pre-existing non-close `Button` variants read string `@rest` keys (always nil → dead truncate/override/dedup helpers). Same class as the Session-12 close-variant fix, not propagated. Outside MER-5642 diff.
- **Lists-in-Figma vs inline-only editor:** confirmed via Figma node 1115:18333 (numbered list + hyperlink in body); resolved per Jess — RTE inline+link approved, mock list is illustrative.
- 2 PR pushes (round 1 + round 2 pending). All touched suites green; `mix format` clean.
- **Next:** push round-2 commits (CI round 3); manual smoke of browser-only behaviors; then archive feature docs.

### Session 14 — 2026-06-08 (HANDOFF → manual testing)

**Current phase: MANUAL TESTING (Phase 6).** All code complete + pushed; branch `MER-5642-context-aware-email-draft-modal-ui-implementation`, PR #6606. HEAD = `0765194b9f`-era + later commits (`7d0a422140` excluded-names/ref-comment, `8f09cb3318` map-shown-names, `0765194b9f` regenerate-Send-disable). `git log master..HEAD` for the full list.

**Done + pushed:** Phases 4–5 (modal + 5 entry points), all AI-review rounds 1–3 resolved (fixed or verified-not-required), B1 (button atom-key globals), legacy `Students.EmailModal` retired. Every fix was TDD'd.

**AI-review loop: CLOSED (converged).** Remaining CI flags are adjudicated re-flags / proven false positives (X7 link-scheme false, X8 DotChart index-key correct, X6 fan-out = G-J12 deferred, render-path rescan = `:if`+change-tracked). Do not "fix" those.

**How to resume manual testing:**
- Read Phase 6 above: **Quick-Start Access** (login `admin@example.edu`/`changeme`; per-case URLs; which students to pick) → **Suggested Run Order** (Blocks A–D) → cases 6.1–6.21 (checkboxes).
- Dev DB already seeded (3 demo sections, students incl. 2 no-email). AI generate runs on **local Ollama** (`llama3.1:8b`, `ollama serve` must be up).
- Evaluate observed UI/behavior against **MER-5257 AC** (Atlassian MCP `getJiraIssue`) + **Figma 955:17500** Support / **1115:18333** Assignment (Figma MCP). Fetch references **on-demand, minimal slices** (context frugality).
- **Commit ONLY if a case surfaces a real bug/improvement** → verify vs code → TDD → one commit ([ENHANCEMENT] [MER-5642], type-sticky; no co-author trailer). Otherwise just tick checkboxes.

**Uncommitted (intentional, manual phase):** docs only — `progress.md` (this + Session 13 + Phase 6 quick-start/run-order/case updates), `prd.md` + `gaps.md` (recipient-cap reconcile), and untracked `ai-review/` (blind round, comparison, validation). Commit these at wrap-up.

**Pending after manual testing:** commit docs → archive feature docs (`current/`→`archive/`, per Darren convention) → final `mix test` + `mix format --check-formatted`.

**Parked / out-of-scope:** seed script `seed_dashboard_data.exs` lost (data survives in dev DB; recreate only if DB reset); `:instructor_dashboard` `on_mount` relies on `SetSection`+HTTP pipeline rather than an explicit instructor-role on_mount (pre-existing, separate).

### Session 15 — 2026-06-08..09 (Phase 6 manual QA — COMPLETE)

Ran Phase 6 via browser MCP (assistant drove navigation/observation; user performed precise clicks after browser-MCP click-targeting proved unreliable on the LiveView tables). Evaluated each case against MER-5257 AC + Figma 955:17500 / 1115:18333.

- **All cases pass** (Blocks A–D, 6.1–6.21). Each marked above with verification notes.
- **4 bugs found → fixed (TDD where applicable) → committed:**
  1. `d320b652f2` — selected **tone-button contrast** (light mode): active state used `bg-Fill-Buttons-fill-secondary-hover` (#1B67B2) + blue text = unreadable. Verified vs Figma (no dark-blue selected-tone fill) + DS button + codebase secondary-button primitive → `bg-Surface-surface-secondary-hover`.
  2. `3d35079e0c` — **stale Send-validation message**: inline error (and SR `live_announcement`) persisted after the user filled the missing field. Added `clear_validation/1` on all edit handlers. Regression test added; TDD caught an incomplete first fix (cleared `:error` only, not the SR region).
  3. `ef5d5acf41` — **objectives email-modal z-index/overlay**: the modal was rendered inside the objectives table's expanded `<td>` (introduced in 5.5), trapping it under the sticky `thead z-[40]`. Hoisted it to a sibling of the table in `LearningObjectives` (state lifted via `email_modal_payload` → EmailButton → root router → LearningObjectives), mirroring the working `Students` path. Browser-verified.
  4. `087cc4d915` — **dangling `<label>` a11y**: "To:" + "Body:" labelled ARIA `role` containers via `aria-labelledby` (DevTools "label not associated with a form field"). `<label>` → `<span>`. Browser-confirmed cleared.
- **Backlog logged (separate ticket, pending writeup):** GenAI **model inflight-counter underflow** — `admit_model_if_enabled/1` skips the model increment when the routing breaker is disabled, but `release_admission!/1` always decrements → `{:inflight, :model, _}` underflows (clamped, warning per generate). Root cause + one-line fix + test plan captured in the 6.4 note. Out of MER-5642 scope (shared GenAI routing infra).
- **Researched + cleared (not a bug):** modal **initial-focus** lands on the first focusable element (a recipient remove-X). Confirmed APG-compliant (W3C ARIA Authoring Practices — Dialog/Modal: default = first focusable; the "least-destructive" exception is only for *irreversible* final-step actions, which chip-removal is not).
- **Doc fix:** 6.17 nav wording (no "Module 1" drill-down; clicking a Unit lands directly on its student list).
- **DB-verified rosters** for `dashboard_hierarchy_demo` + `dashboard_objectives_demo` via direct Ecto query (caught that the no-email student there is **Admin User**, not Grace).
- **Final gate (6.19):** `mix format --check-formatted` clean; **262** MER-5642 tests pass; `mix compile --warnings-as-errors` clean.
- **Next:** commit docs (this file + `gaps.md` + `prd.md`; **exclude** untracked `ai-review/` — conclusions already in Session 13) → write the GenAI inflight-counter backlog ticket → archive feature docs.

## Figma Audit — DraftEmailModal vs node 955:17500

Detailed audit in [figma-audit.md](figma-audit.md). Summary: 28 items found, 28 fixed, 4 accepted minor differences.

# Email Sending — Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/intelligent_dashboard/email_sending/prd.md`
- Requirements: `docs/exec-plans/current/epics/intelligent_dashboard/email_sending/requirements.yml`
- Informal source: `docs/exec-plans/current/epics/intelligent_dashboard/email_sending/informal.md`
- Open gaps: `docs/exec-plans/current/epics/intelligent_dashboard/email_sending/gaps.md`
- Live progress tracker: `docs/exec-plans/current/epics/intelligent_dashboard/email_sending/progress.md`
- Jira: `MER-5257`
- Parent epic: `MER-5198` (Instructor Intelligent Dashboard)
- Figma node: https://www.figma.com/design/2DZreln3n2lJMNiL6av5PP/Instructor-Intelligent-Dashboard?node-id=955-17500

## Scope

Deliver the AI-powered Draft Email modal and supporting backend services so instructors can compose and send context-aware outreach from multiple instructor-dashboard entry points without leaving their current workflow. The implementation includes situation contract, context builder, AI draft facade, prompt composer, GenAI Feature Config, whitelist placeholder substitution, per-recipient send pipeline via Oban, reusable accessible LiveComponent modal, and entry-point launchers.

## Out of scope

- Autonomous or scheduled email sending.
- Student-facing AI authoring tools.
- New outbound email provider integration.
- Feature-flag rollout mechanics (PRD §11 documents no flag).
- Per-instructor email preferences or saved templates.

## Clarifications & Default Assumptions

- Existing Torus email delivery infrastructure (Oban-based) is reused; no new provider.
- Existing GenAI synchronous completion stack is reused via a thin instructor-dashboard facade.
- Domain code lives under `Oli.InstructorDashboard.*` (or equivalent existing namespace), not in global GenAI helpers.
- Modal is a reusable LiveComponent so multiple entry points can mount it.
- Light mode styling is derived from token system; dark-only Figma node (G-D01) is the reference for component structure, not the only target.
- Last-write-wins for concurrent send actions; per-recipient jobs are idempotent at the existing delivery layer.
- Scenario tests (`Oli.Scenarios`) are NOT the default verification path; ExUnit + LiveView tests + targeted integration tests are sufficient (per PRD §16).
- Open gaps (`gaps.md` B1, B2, B3) are tracked and resolved as implementation reaches the corresponding phase. Work that depends on an unresolved gap is gated explicitly in the phase's `Gate` section.

## Phase 1 — Backend Domain Services

- **Goal:** establish the non-UI domain foundation (situation contract, context builder, AI draft facade, prompt composer, GenAI Feature Config) that all entry points and the modal will consume. Covers `FR-001`, `FR-002`, `FR-003`, `FR-013`.
- **Tasks:**
  - [ ] Step 1.1 — Add `Situation` enum module + canonical-description lookup map. Closed list resolved (G-J02): `:struggling_students`, `:active_students_on_track`, `:excelling_students`, `:inactive_students`, `:incomplete_assessment`, `:low_proficiency_objectives`, `:beginning_course`. Each key derives from an existing tile projector or PRD taxonomy. Validate `:beginning_course` (MEDIUM confidence, ai_infra fallback) during implementation.
  - [ ] Step 1.2 — Add `ContextBuilder` service that returns a normalized `EmailContext` struct (G-J03 resolved). Cross-cutting: `section_id`, `course_title`, `scope_label`, `situation_key`. Recipients: `student_id`, `email`, `given_name`, `family_name`, `progress_pct`, `proficiency_pct`, `activity_status`, `last_interaction_at`. Optional per entry point: `assessment` (`title`, `available_at`, `due_at`, `completion_ratio`, `completion_status`, `mean_score`, `median_score`, `histogram`), `objective` (`title`, `proficiency_label`, `proficiency_distribution`), `content_item` (`title`, `label`, `resource_type`), `support_bucket` (`label`, `count`, `active_count`, `inactive_count`). Default tone `:neutral`. All fields derive from existing projector `@type`s.
  - [ ] Step 1.3 — **Tier A.** AI draft facade. Accepts an `%EmailContext{}`, calls `Oli.GenAI.Execution.generate_with_metadata/5` with the prompt produced by `PromptComposer`, parses the AI's JSON response into `{:ok, %{subject_template, body_template}}`, or returns a coarse `{:error, reason}` tuple. Architectural decisions (locked):
    - **1.3.a** GenAI infra: `Oli.GenAI.Execution.generate_with_metadata/5` (matches `Recommendations.ex:588`).
    - **1.3.b** Output parsing: AI returns JSON `{"subject": "...", "body": "..."}`. Facade uses `Jason.decode/1` + pattern match. No regex, no delimited splitting.
    - **1.3.c** Timeouts/retry: adopt Execution defaults (8s connect / 60s receive per `RegisteredModel`); Router-level fallback chain; no opt overrides.
    - **1.3.d** Error reasons surfaced to UI: minimal set `:timeout`, `:provider_error`, `:parse_failure`. Granular underlying errors logged for diagnostics.
    - **1.3.e** Batched (`generate_with_metadata`); no streaming. Matches sibling Recommendations.
    - **Telemetry:** emit `instructor_dashboard.email_draft_generated` and `email_draft_regenerated` with success/failure variants (per PRD §12).
  - [x] Step 1.4 — `PromptComposer` module assembling role framing, situation description, tone directive, personalization placeholder list, optional metadata sections, and a JSON-output schema instruction. Returns `[%{role: :system, content: String.t()}]` (mirrors `Recommendations.Prompt.build_messages/2`). DONE in this session; output schema instructs AI to return `{"subject": "...", "body": "..."}`.
  - [ ] Step 1.5 — **Tier A.** Register new GenAI Feature Config `:instructor_email`. Architectural decisions (locked):
    - **1.5.a** New ServiceConfig `"instructor-email-default"` whose `primary_model_id` points to the same `RegisteredModel` row as `standard-no-backup` today (lazy-bind). Admins swap via `OliWeb.GenAI.FeatureConfigsView` if a different model is desired later.
    - **1.5.b** Seeds-only registration. No data migration. Matches Nico's pattern in commit `b981d4fe04` (MER-5305).
    - **1.5.c** Global default (`section_id: nil`). Per-section overrides handled by the admin LiveView at `lib/oli_web/live/gen_ai/feature_configs_view.ex`.
    - **1.5.d** No schema migration needed (`gen_ai_feature_configs` table already exists from `20250721171203_genai_infra.exs`).
    - Concrete change set: add `:instructor_email` atom to `@features` in `lib/oli/gen_ai/feature_config.ex:16`; add `Repo.insert!(%ServiceConfig{name: "instructor-email-default", ...})` and `Repo.insert!(%FeatureConfig{feature: :instructor_email, ...})` to `priv/repo/seeds.exs` inside the existing GenAI seed block.
  - [ ] Emit telemetry: `instructor_dashboard.email_draft_generated` (success/failure variants).
- **Testing Tasks:**
  - [ ] Contract tests for situation key stability across builds.
  - [ ] Unit tests for prompt composer covering all tone variants and presence/absence of optional context fields.
  - [ ] Tests for ContextBuilder shape (required keys present, recipient-emails resolved, situation key matches entry-point input).
  - [ ] Tests for facade output shape and recoverable failure handling.
- **Definition of Done:** all five domain modules exist with documented public API; tests pass; the new GenAI Feature Config is loaded by application configuration.
- **Gate:** backend unit tests pass; situation map covers the entry points scheduled for Phase 5 (depends on `G-J02` resolution or documented sample fallback).
- **Dependencies:** PRD/requirements signed off.
- **Parallelizable Work:** Phase 3 (UI workflow alignment) can start once the facade output shape (subject_template, body_template) is stable.
- **Verification layers (added during Session 3 — beyond original plan):**
  - **Layer 1 — Mocked unit tests (84 total).** Function-injection at module boundary via `execution_fun:` opt (mirrors `Recommendations` precedent). Covers contract correctness for every public function.
  - **Layer 2 — Fixture replay (5 tests, inline).** Synthetic AI responses as private `fixture/1` clauses in `ai_draft_facade_test.exs`, injected via `execution_fun:`. Includes 3 happy-path situation/tone variants + 2 edge fixtures (markdown-fenced JSON, trailing prose). Runs on every `mix test` — catches parser regressions deterministically. Refreshable from real provider output via `EMAIL_PHASE1_REAL_AI=1` script.
  - **Layer 3 — Manual real-provider smoke script.** `scripts/dev/email_sending_phase_1_check.exs`. Env-gated via `EMAIL_PHASE1_REAL_AI=1`. 35/35 sections pass against fresh DB. Costs ~$0.001 per real-AI run.
  - **Decision (documented for Phase 4+):** Tagged-live ExUnit test (`@tag :live_ai`) NOT added. Industry default (LangChain Docs T1, brainlid/langchain T3) but prerequisites absent in codebase: no nightly CI, no API key in CI secrets, no live-tag convention. Pattern's value collapses to zero locally. Reconsider when (a) nightly CI added, or (b) second AI feature ships needing same verification.

## Phase 2 — Placeholder Substitution + Send Pipeline

- **Goal:** realize per-recipient subject/body and dispatch via existing Torus delivery; validate placeholders at send time and block on invalid. Covers `FR-009`, `FR-010`, `FR-011`, `FR-015`.
- **Tasks:**
  - [ ] Step 2.1 — Whitelist placeholder substitution module supporting `{first_name}`, `{student_name}`, `{instructor_name}`, `{course_name}` (initial set; extend once `G-J03` performance-signal fields are confirmed). Implementation must be deterministic and non-evaluative; do not interpret arbitrary user-provided expressions.
  - [ ] Step 2.2 — Per-recipient template realization function: given edited subject/body templates + resolved recipient/instructor/course values, returns concrete strings.
  - [ ] Step 2.3 — Oban worker enqueues one job per recipient via the existing email delivery mechanism. Worker is idempotent and respects existing delivery retries.
  - [ ] Step 2.4 — Send-time placeholder validation: walks subject + body, identifies any unsupported or unresolvable placeholder, and blocks dispatch with a helpful message naming the offending placeholder.
  - [ ] Step 2.5 — Per-recipient result summary returned to the UI (no silent partial success).
  - [ ] Emit telemetry: `email_send_attempted`, `email_send_succeeded`, `email_send_failed`, `email_validation_blocked`.
- **Testing Tasks:**
  - [ ] Unit tests for substitution covering: known token replacement, unknown token reporting, no leakage of resolvable raw tokens.
  - [ ] Tests for the Send-time validator (invalid placeholder text appears in the message).
  - [ ] Integration test for one-job-per-recipient dispatch count.
  - [ ] Test for partial-fail behavior matching the policy chosen in `G-J04`.
- **Definition of Done:** end-to-end backend send works for a sample recipient list; validation blocks invalid placeholders; partial-fail policy locked.
- **Gate:** backend tests pass; `G-J04` resolved.
- **Dependencies:** Phase 1 facade output shape stable.
- **Parallelizable Work:** Phase 3 design alignment can run in parallel.

### Phase 2 — Architectural decisions (locked 2026-05-08, per Path B' "no silent decisions" rule)

These decisions are derived from MER-5257 ticket + Darren's Jira comment + Jess's Jira comment + codebase precedent research (B-items audit). See progress.md Session 3 entry for the audit detail.

**B5 — Public API shape (applies to entire Phase 2):**
- **2.B5.a** New flat parent module `Oli.InstructorDashboard.Email` exposes the public API. Mirrors `Oli.InstructorDashboard.Recommendations` precedent (`recommendations.ex` + sibling internal modules in `recommendations/` folder).
- **2.B5.b** External callers (Phase 4 modal, Phase 5 entry points) import only `Oli.InstructorDashboard.Email`. Internals (`Substitution`, `SendWorker`, `AIDraftFacade`, etc.) stay private to the folder.
- **2.B5.c** Public functions (initial): `generate_draft/2` (delegates to existing `AIDraftFacade.generate/2`), `validate/2`, `send_emails/2`.

**Step 2.1 — Whitelist substitution:**
- **2.1.a** Whitelist tokens: `{first_name}`, `{student_name}`, `{instructor_name}`, `{course_name}`. Locked in Phase 1 chunk 1.4 PromptComposer; Phase 2 substitution module reuses this list.
- **2.1.b** Direct token replacement (string scan + replace from a known map). NOT EEx — no template evaluation, no expression interpretation. Per Darren §8.
- **2.1.c** Missing or empty placeholder values surface as a validation error at Send time (chunk 2.4); substitution does NOT silently leave raw tokens — that would violate ticket negative AC ("Do not expose raw AI placeholders... when data is available").

**Step 2.2 — Per-recipient template realization:**
- **2.2.a** Input: edited `subject_template` + `body_template` + `EmailContext.recipients` + course/instructor metadata.
- **2.2.b** Output: `[%{user_id, email, subject, body}]` — concrete per-recipient strings. Pure function, no DB writes.

**Step 2.3 — Oban worker (B2 idempotency):**
- **2.3.a** Queue: `:mailer` (existing, sized 10 default — `config/config.exs:248-267`).
- **2.3.b** `unique: [keys: [:draft_id, :user_id], states: [:available, :scheduled, :retryable], period: :infinity]` — protects against Oban retries duplicating sends. Mirrors `Oli.Delivery.Attempts.PageLifecycle.GradeUpdateWorker` precedent (`grade_update_worker.ex:25-40`).
- **2.3.c** `draft_id` = UUID generated when instructor clicks Send; lives only in worker args (ephemeral; no DB persistence per ticket — see B1 below).
- **2.3.d** `max_attempts: 3` (mirrors `Oli.Delivery.Sections.Certificates.Workers.Mailer:2`).
- **2.3.e** Phase 4 modal MUST also use `phx-disable-with` on Send button to prevent double-click during in-flight enqueue (see Phase 4 step 4.6); UI-side double-click + Oban dedup form defense-in-depth.

**Step 2.4 — Send-time validation (B3 timing):**
- **2.4.a** Server-authoritative at Send. Layer 2 of validation (per B3 audit). Per Darren comment 44655 + Jess comment 44656 — both explicitly state validation must trigger at Send.
- **2.4.b** Validates: `recipients > 0` (G-J05); each email well-formed; every placeholder in subject + body is in whitelist AND resolvable for every recipient.
- **2.4.c** Returns `{:ok, _}` (proceed to enqueue) OR `{:error, [{:placeholder, "..."} | {:recipient, ...} | ...]}` for UI display.
- **2.4.d** Phase 4 modal will ALSO run option (3) flow: validate after AI generation (early UX feedback) + at Send (server-authoritative). Track `dirty?` flag in LiveView assigns to know whether to show stale errors after manual edits. Phase 2 backend just provides the authoritative validator; Phase 4 wires the UI flow.
- **2.4.e** Layer 3 (perform-time revalidation in Oban worker) deferred — only add if recipient-row-mutation race surfaces in production.

**Step 2.5 — Per-recipient result summary (B4):**
- **2.5.a** Per ticket: success → "Email sent" banner. Per Darren §9: "Send/enqueue failure: no silent partial success; return actionable feedback." NOT persisted in DB (ticket + comments do not require audit/history schema).
- **2.5.b** Coarse banner format: full success → "Email sent (N recipients)"; partial fail → "Sent N, failed M" + listed reasons + failed recipient emails. Returned in flash payload from server `send_emails/2` response.
- **2.5.c** Telemetry events `email_send_attempted/_succeeded/_failed/_validation_blocked` provide observability beyond the user-facing banner.

**B1 — Draft persistence (NOT a real decision; documented for clarity):**
- Ticket + comments do not require draft persistence. PRD §91 explicitly notes "None required for baseline workflow unless implementation introduces persisted draft/session state." Phase 1 `AIDraftFacade` already returns ephemeral data. Phase 2 stays ephemeral — drafts live in Phase 4 LiveView assigns until Send.

## Phase 3 — Figma / UI Workflow Alignment

- **Goal:** resolve B2 design state gaps and B3 token drift before building the modal. Covers preparation for `FR-007`, `FR-012`, `FR-014`, `AC-016`.
- **Tasks:**
  - [ ] Step 3.1 — Run the `ui_workflow` skill against Figma node `955:17500` to produce a UI implementation brief.
  - [ ] Step 3.2 — Resolve B2 gaps with the design team: light mode (`G-D01`), hover/focus/disabled states (`G-D02`), loading state (`G-D03`), AI failure UI (`G-D04`), validation error UI (`G-D05`), empty state (`G-D06`), `+N more` chip overflow (`G-D07`), manual-add affordance (`G-D08`), hyperlink edit UI (`G-D09`), `Email sent` banner placement (`G-D10`), mobile (`G-D11`), Cancel button disposition (`G-D12`), Send-button duplication (`G-D13`), subject single-line (`G-D14`).
  - [ ] Step 3.3 — Resolve B3 token drift: `Fill-Buttons-fill-primary` (`G-T01`), `Border/border-input` (`G-T02`), `Fill-Accent-fill-accent-grey-muted` (`G-T03`).
  - [ ] If implementation boundaries change as a result of design decisions, update this `plan.md` and document FDD-level decisions in a follow-up `fdd.md`.
- **Testing Tasks:**
  - [ ] Capture planned UI verification notes for focus trap, Esc/outside-click behavior, keyboard chip ops, and screen-reader labels.
- **Definition of Done:** every B2 + B3 gap has either a concrete decision or an explicit fallback documented in `gaps.md` and `progress.md`.
- **Gate:** design states documented; token decisions locked; `gaps.md` B2/B3 sections show all items `ANSWERED` or `RESOLVED`.
- **Dependencies:** `gaps.md` B2 + B3 items raised with owners.
- **Parallelizable Work:** Phases 1 and 2 can continue in parallel.

## Phase 4 — Reusable Draft Email Modal (UI + a11y)

- **Goal:** build the reusable Draft Email LiveComponent with chips, tone, regenerate, hyperlink editor, focus management, and full keyboard/screen-reader support. Covers `FR-004`, `FR-005`, `FR-006`, `FR-007`, `FR-011`, `FR-012`, `FR-014`, `AC-016`.
- **Tasks:**
  - [ ] Step 4.1 — LiveComponent state model (recipients, subject, body, tone, draft id, validation errors, loading flags).
  - [ ] Step 4.2 — Recipient chip pills with X-icon remove, Backspace/Delete on focused chip, accessible label per chip, `+N more` overflow per `G-D07`, manual-add affordance per `G-D08`.
  - [ ] Step 4.3 — Tone buttons (Neutral / Encouraging / Firm) with `aria-pressed`, default Neutral, no auto-regenerate on selection.
  - [ ] Step 4.4 — Subject single-line input with ellipsis truncation per `G-D14`.
  - [ ] Step 4.5 — Body input via Slate `RichTextEditor` restricted to inline + link only (per G-D09). Vertical scroll (`AC-016`) preserved. Implementation MUST follow existing Slate patterns: read `assets/src/components/content/RichTextEditor.tsx`, `assets/src/components/editing/elements/link/{LinkCmd.tsx,LinkModal.tsx,LinkElement.tsx}`, and at least 2-3 existing call sites (`MultiInputStem.tsx`, `FeedbackCard.tsx`, `PopupContentEditor.tsx`) before configuring. Toolbar limited to Insert Link button only; schema rejects block elements / math / embeds / images / code / tables. Slate JSON serialization to HTML via existing `assets/src/data/content/writers/html.tsx` for `html_body`; plain-text fallback for `text_body` via Premailex. AI prompt produces markdown link syntax `[label](url)` deserialized to Slate JSON on modal load.
  - [ ] Step 4.6 — `Generate New Draft` button (applies selected tone, replaces subject/body), `Send` button (triggers Phase 2 validation), `Cancel` button per `G-D12` decision. **Both `Generate` and `Send` MUST use `phx-disable-with` to prevent double-click during in-flight action** (avoids duplicate AI calls on Generate; complements Phase 2 Oban worker `unique: [draft_id, user_id]` dedup on Send by blocking the UI-side window where two distinct `draft_id`s could be enqueued).
  - [ ] Step 4.7 — Focus management: focus moves to To field on open, focus trap inside modal, Escape closes and returns focus to launcher, logical Tab/Shift+Tab order.
  - [ ] Step 4.8 — Visual states: loading (`G-D03`), AI generation error (`G-D04`), validation error (`G-D05`), empty (`G-D06`).
  - [ ] Step 4.9 — Live region for recipient add/remove announcements; validation errors programmatically linked to fields.
  - [ ] Step 4.10 — Smoke harness page (dev-only) that mounts the modal in isolation for manual testing and screen-reader walkthroughs.
  - [ ] Emit telemetry: `instructor_dashboard.email_draft_opened`, `instructor_dashboard.email_draft_regenerated`.
- **Testing Tasks:**
  - [ ] LiveView tests for: tone selection does not regenerate; regenerate replaces subject/body and preserves recipient edits; chip remove via mouse and keyboard; manual recipient add; focus trap; Escape close; validation error blocks Send and surfaces the offending placeholder.
  - [ ] Manual keyboard-only walkthrough across every control.
  - [ ] Manual screen-reader verification (dialog labeling, dynamic recipient announcements, validation announcements).
- **Definition of Done:** modal renders standalone via the smoke harness; all LiveView tests pass; manual a11y walkthrough notes documented in `progress.md`.
- **Gate:** a11y verified; no per-pointermove churn in event log; LiveView tests green.
- **Dependencies:** Phases 1, 2, 3.
- **Parallelizable Work:** Phase 5 launchers can be drafted once the modal's open/close API is stable.

## Phase 5 — Entry-Point Integrations

- **Goal:** wire the modal into every supported entry point with the correct situation context. Covers `FR-001` per entry point.
- **Tasks:**
  - [ ] Step 5.1 — Student Support tile launcher.
  - [ ] Step 5.2 — Assessments tile launcher.
  - [ ] Step 5.3 — Student Overview launcher.
  - [ ] Step 5.4 — Content → Student list launcher.
  - [ ] Step 5.5 — Learning Objectives → Student list launcher.
  - [ ] Step 5.6 — Any additional entry points from `G-J01` resolution.
  - [ ] Step 5.7 — `Email sent` confirmation banner placement per `G-D10` decision.
  - [ ] Each launcher passes correct context (situation key, recipient subset, content/assessment metadata, performance signals).
- **Testing Tasks:**
  - [ ] Per-entry-point integration tests verifying context fidelity (situation key matches entry-point semantics; recipients match selection).
  - [ ] Manual context-quality spot checks across all entry points to confirm AI drafts reflect the initiating situation.
- **Definition of Done:** every entry point opens the modal with the correct context; banner appears on successful send.
- **Gate:** integration tests green; `G-J01` resolved (final entry-point list closed); `G-D10` resolved.
- **Dependencies:** Phases 1, 2, 4 stable.
- **Parallelizable Work:** Phase 6 verification scaffolding can start in parallel with the last few launchers.

## Phase 6 — End-to-End Verification + Manual QA

- **Goal:** prove the full feature meets requirements, telemetry fires correctly, accessibility is verified, and code passes format/lint.
- **Tasks:**
  - [ ] Step 6.1 — Run targeted backend, LiveView, integration, and Oban worker test suites.
  - [ ] Step 6.2 — Verify all telemetry events fire with correct dimensions (section, entry point, situation key).
  - [ ] Step 6.3 — Manual keyboard-only walkthrough across all controls and chip operations.
  - [ ] Step 6.4 — Screen-reader verification (dialog labeling, live regions, validation announcements).
  - [ ] Step 6.5 — Context-quality spot checks across all entry points.
  - [ ] Step 6.6 — Verify `Email sent` banner placement per design.
  - [ ] Step 6.7 — `mix format` + targeted lints.
  - [ ] Step 6.8 — Update `requirements.yml` `proofs` to reference test files; flip statuses to `verified` where applicable.
  - [ ] Step 6.9 — Prepare review notes covering security (placeholder safety, authorization), performance (per-recipient fan-out), telemetry, and UI/accessibility.
- **Testing Tasks:**
  - [ ] All targeted commands from previous phases.
  - [ ] Broader dashboard test file if multiple LiveView paths changed.
- **Definition of Done:** every FR and AC has automated coverage or documented manual verification; manual a11y notes added to `progress.md`; review prep ready.
- **Gate:** all targeted tests + format/lint pass; review notes complete.
- **Dependencies:** Phases 1–5 complete.

## Parallelization Notes

- Phase 1 (backend domain) and Phase 3 (UI workflow alignment) can overlap once the AI draft facade output shape is fixed.
- Phase 2 (send pipeline) is mostly independent of Phase 3 and can run in parallel with Phase 1's tail end.
- Phase 4 (modal UI) cannot start before Phase 3 design decisions are landed.
- Phase 5 (launchers) can begin drafting against the modal's open/close API once Phase 4's component contract is stable.
- Phase 6 (verification) is serialized after Phase 5 completes.

## Phase Gate Summary

- Gate A: domain modules + GenAI Feature Config in place; situation map covers planned entry points.
- Gate B: send pipeline + Send-time validation work end-to-end; partial-fail policy locked.
- Gate C: design states and token decisions documented; `gaps.md` B2/B3 cleared.
- Gate D: modal LiveComponent passes LiveView tests and manual a11y walkthrough.
- Gate E: every entry point wired with correct context; banner verified.
- Gate F: targeted tests, format, lint, and review notes complete.

## PR Split

| PR | Contents | Phases |
|----|----------|--------|
| PR 1 | Backend domain services (situation, context builder, facade, prompt composer, GenAI Feature Config) + placeholder substitution + send pipeline | 1, 2 |
| PR 2 | Modal LiveComponent (UI + a11y, smoke harness, design alignment) | 3, 4 |
| PR 3 | Entry-point integrations + banner + final verification | 5, 6 |

**Rationale for combining Phases 1 + 2 in PR 1 (decided 2026-05-08):** the two phases are tightly coupled — Phase 2's substitution/send pipeline directly consumes Phase 1's facade output shape (`subject_template`, `body_template`). Reviewing both together gives reviewers the complete backend story (AI draft → per-recipient template realization → Oban dispatch) in one pass with shared context. Trade-off accepted: Phase 1 commits sit in the open draft PR until Phase 2 lands, delaying Phase 1 feedback. Mitigated by Codex CI running on each push.

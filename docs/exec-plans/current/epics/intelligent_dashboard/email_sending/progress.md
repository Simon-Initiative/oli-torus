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

- **Phase:** Phase 5 — IN PROGRESS (wiring complete, pending Phase 6 E2E verification)
- **Last updated:** 2026-05-25
- **Next step:** Phase 6 — E2E verification + browser testing
- **Branch:** `MER-5642-context-aware-email-draft-modal-ui-implementation`
- **PR 1 (Phases 1+2):** MERGED to master (`09fdf332bc` — PR #6556)
- **Phase 3:** COMPLETE (all B2/B3 gaps resolved in prior sessions)
- **Phase 4:** COMPLETE (modal LiveComponent + tests + Button `:close` fix)
- **Phase 5:** IN PROGRESS (5.1 + 5.2 wired, 5.3-5.7 not started)

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
- [ ] 5.3 — Student Overview launcher
- [ ] 5.4 — Content → Student list launcher
- [ ] 5.5 — Learning Objectives → Student list launcher
- [x] 5.6 — Additional entry points (G-J01 resolved: closed list = the 5 explicit entry points)
- [ ] 5.7 — "Email sent" banner

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

### Phase 6 — End-to-End Verification + Manual QA

#### Prerequisites

- Admin login: http://localhost/authors/log_in → `admin@example.edu` / `changeme`
- Verify `:instructor_email` FeatureConfig: `Oli.Repo.get_by(Oli.GenAI.FeatureConfig, feature: :instructor_email)`
- Dashboard URL: http://localhost/sections/example_course_section/instructor_dashboard/insights/dashboard?dashboard_scope=course
- Admin sections list: http://localhost/admin/sections

#### 6.1 — Student Support Tile → Modal

- [ ] Navigate to dashboard URL. Wait for tiles to load.
- [ ] Click a bucket (Struggling/Excelling/On Track/Inactive) to expand student list
- [ ] Select students via checkboxes
- [ ] Click **"Email Selected"** button
- [ ] Modal opens with selected students as recipient chips
- [ ] Tone buttons visible: Neutral (selected), Encouraging, Firm
- [ ] Subject input empty, Body editor empty
- [ ] "Generate New Draft" enabled
- [ ] "Send" disabled (empty subject + body)
- [ ] Footer shows "AI-generated content may contain errors"

#### 6.2 — Assessment Tile → Modal

- [ ] Same dashboard page
- [ ] Expand an assessment row (click it)
- [ ] Click **"Email Students Not Completed"**
- [ ] Modal opens with auto-populated recipients (students without attempts)
- [ ] Same modal structure as 6.1

#### 6.3 — Tone Selection

- [ ] Open modal via either tile
- [ ] Click **Encouraging** — shows `aria-pressed="true"`, Neutral shows `false`
- [ ] Click **Firm** — Firm pressed, others not
- [ ] Changing tone does NOT auto-trigger generation

#### 6.4 — Generate Draft

- [ ] Click **"Generate New Draft"**
- [ ] During generation: button shows "Generating draft..." with spinner, button disabled
- [ ] On success: subject populated, body populated, button changes to "Regenerate Draft"
- [ ] "Send" button becomes enabled
- [ ] Click **"Regenerate Draft"** — new draft replaces previous subject + body

#### 6.5 — Generate Draft Error

- [ ] Trigger error (disconnect network / AI service down)
- [ ] Error message appears (e.g., "Draft generation timed out")
- [ ] Generate button re-enables for retry

#### 6.6 — Subject Editing

- [ ] Edit subject field → value updates
- [ ] Clear subject completely → "Send" becomes disabled
- [ ] Type new subject → "Send" re-enables (if body present)

#### 6.7 — Recipient Management

- [ ] Click X on a recipient chip → chip removed
- [ ] Remaining recipients still shown
- [ ] Remove all recipients → "Send" disabled
- [ ] Empty state: "No students currently need this message"

#### 6.8 — Excluded Recipients

- [ ] Open modal where a selected student has no email on file
- [ ] Note appears: "N selected student(s) without email" with tooltip listing names

#### 6.9 — Send Email

- [ ] Generate draft (or manually fill subject + body), at least one recipient
- [ ] Click **"Send"**
- [ ] Modal closes
- [ ] Flash message: email sent confirmation
- [ ] Verify Oban jobs: `Oli.Repo.all(Oban.Job) |> Enum.filter(& &1.worker == "Oli.InstructorDashboard.Email.SendWorker")`

#### 6.10 — Cancel / Close

- [ ] Open modal, make changes (tone, subject)
- [ ] Click **"Cancel"** → modal closes
- [ ] Reopen modal
- [ ] Click X (close) button → modal closes
- [ ] Inspect X button: `aria-label="Close draft email modal"`

#### 6.11 — Keyboard Navigation

- [ ] Open modal
- [ ] Tab through: chips → subject → tone buttons → Generate → body → Cancel → Send → Close (X)
- [ ] Focus stays trapped inside modal (doesn't escape to background)
- [ ] Press **Escape** → modal closes

#### 6.12 — Context Builder Error

- [ ] Hard to trigger manually — requires invalid situation_key
- [ ] If testable: error "Unable to prepare email context" shown, Generate disabled

#### 6.13 — Automated Checks

- [ ] `mix format --check-formatted`
- [ ] `mix test test/oli_web/components/delivery/instructor_dashboard/draft_email_modal_test.exs` — 20 pass
- [ ] `mix test test/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live_test.exs` — 38 pass
- [ ] No new compile warnings from our changes

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

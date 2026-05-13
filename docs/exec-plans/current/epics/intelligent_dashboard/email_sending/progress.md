# Progress — email_sending (MER-5257)

Live status of the work. Edit this file as items complete; the live page at `/dev/mer-5257` reads it on each click. Detailed task content lives in `plan.md`; this file is the at-a-glance tracker.

- Jira: [MER-5257](https://eliterate.atlassian.net/browse/MER-5257)
- Plan (full detail): [plan.md](plan.md)
- PRD: [prd.md](prd.md)
- Requirements: [requirements.yml](requirements.yml)
- Open gaps: [gaps.md](gaps.md)
- Figma node: https://www.figma.com/design/2DZreln3n2lJMNiL6av5PP/Instructor-Intelligent-Dashboard?node-id=955-17500

## Current Status

- **Phase:** Phase 2 COMPLETE — staged locally (5 new lib modules + 5 test files + Phase 1 fixture updates + plan/progress doc updates). Awaiting commit.
- **Last updated:** 2026-05-11
- **Next step:** Commit Phase 2, push, then open the PR 1 review loop (bundles Phases 1 + 2). After review: Phase 3 / 4 (modal).
- **Branch:** `MER-5257-ai-email-capabilities-updates` (2 plan-commits ahead of remote; Phase 2 implementation uncommitted on top)
- **Verification (Phase 2):**
  - New ExUnit tests: 17 (`substitution_test.exs`) + 9 (`realization_test.exs`) + 12 (`validator_test.exs`) + 4 (`send_worker_test.exs`) + 12 (`email_test.exs` integration) = 54 new tests
  - Phase 1 test fixtures updated (`context_builder_test.exs` +2, `prompt_composer_test.exs` / `ai_draft_facade_test.exs` factories) — backward-compat preserved
  - Combined instructor-dashboard + mailer suite: 303 tests, 0 failures
  - `Oli.Rendering.Content.Html.escape_xml!/1` brace-preservation regression test guards Option B post-render substitution
  - Mechanical: `mix format --check-formatted` ✓ + `mix compile --warnings-as-errors` ✓
- **Verification (Phase 1):**
  - 84 mocked unit tests + 5 fixture replay tests + manual `scripts/dev/email_sending_phase_1_check.exs` (35/35) — all still green

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

- [ ] 4.1 — LiveComponent state model
- [ ] 4.2 — Recipient chip pills + remove + manual add
- [ ] 4.3 — Tone buttons (Neutral / Encouraging / Firm)
- [ ] 4.4 — Subject input
- [ ] 4.5 — Body textarea + scroll + hyperlink editor
- [ ] 4.6 — Generate / Send / Cancel buttons
- [ ] 4.7 — Focus trap + keyboard ops
- [ ] 4.8 — Loading / error / empty / validation states
- [ ] 4.9 — Live region announcements
- [ ] 4.10 — Smoke harness page

### Phase 5 — Entry-Point Integrations

- [ ] 5.1 — Student Support tile launcher
- [ ] 5.2 — Assessments tile launcher
- [ ] 5.3 — Student Overview launcher
- [ ] 5.4 — Content → Student list launcher
- [ ] 5.5 — Learning Objectives → Student list launcher
- [x] 5.6 — Additional entry points (G-J01 resolved: closed list = the 5 explicit entry points)
- [ ] 5.7 — "Email sent" banner

### Phase 6 — End-to-End Verification + Manual QA

- [ ] 6.1 — Targeted test suites
- [ ] 6.2 — Telemetry verification
- [ ] 6.3 — Manual keyboard walkthrough
- [ ] 6.4 — Screen-reader verification
- [ ] 6.5 — Context-quality entry-point spot checks
- [ ] 6.6 — Banner placement verified
- [ ] 6.7 — `mix format` + lints
- [ ] 6.8 — `requirements.yml` proofs updated
- [ ] 6.9 — Review notes prepared

## PR split

- [~] PR 1 — Backend domain + send pipeline (Phases 1, 2) — Phase 1 + Phase 2 implementation complete; staged locally; awaiting commit + review opening
- [ ] PR 2 — Modal LiveComponent (Phases 3, 4)
- [ ] PR 3 — Entry points + final verification (Phases 5, 6)

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

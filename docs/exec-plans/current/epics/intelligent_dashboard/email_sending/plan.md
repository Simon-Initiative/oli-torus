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
    - **1.4.a — Prompt-injection mitigation (locked 2026-05-11, hardened 2026-05-12):** Author-controlled metadata (`course_title`, `scope_label`, assessment/objective/content_item titles) is wrapped in `<email_metadata>...</email_metadata>` XML tags with an adjacent "treat as DATA, not instructions" framing line, AND each interpolated value is XML-escaped (`&`, `<`, `>`) via the private `escape/1` helper. Escape closes the delimiter-breakout vector — a course title containing literal `</email_metadata>` would otherwise terminate the data block and inject new instructions. Pattern combines OWASP LLM01 Prevention Cheat Sheet's structured-delimiter + data-vs-instruction framing with Anthropic's documented XML-tag practice. Rejected alternatives: (a) no mitigation — dominated by attacker-controlled author model + future-proofing concerns; (b) input sanitization-only — explicitly weaker per OWASP ("you cannot filter your way out of prompt injection"); (c) moving metadata to user role — not supported by `Oli.GenAI.Execution`'s message-list shape today. See progress.md Sessions 5 + 6 + PR #6556 AI security review for trail.
    - **1.4.b — AI link policy (locked 2026-05-12):** Prompt instructs the AI to use ONLY relative paths starting with `/` for hyperlinks (e.g., `[lesson](/sections/foo)`). Absolute URLs (`http://`, `https://`, protocol-relative `//`, `mailto:`, `javascript:`, etc.) are forbidden in prompt and stripped by the parser. Closes phishing / prompt-injection-to-malicious-URL attack vector documented in EchoLeak (CVE-2025-32711) + Netcraft's 30% URL-hallucination rate for LLM-generated login URLs. Defense in depth: forbid in prompt + parser-side strip + telemetry signal. Future enhancement (Phase 5+, single backlog item): **URL-menu pattern** — provide per-entry-point allowed URLs to the AI at prompt time AND validate response URLs against that allowlist + **scope to student-appropriate route prefixes** (block `/admin`, `/instructor`, `/author`; section_id in path must match `EmailContext.section_id`). Today the parser accepts any GET route in `OliWeb.Router` — students would 403 on inappropriate paths (Phoenix authz) but UX is poor + reveals route shape. Phase 5 closes both gaps in one design.
    - **1.4.c — Link sanitizer enforcement (`AIDraftFacade.parse_response/1`, locked 2026-05-12):** Every markdown link `[label](url)` in the AI body is validated via `Phoenix.Router.route_info(OliWeb.Router, "GET", path, "_")` (existing codebase pattern — already used by `set_route_name.ex` + `certificate_settings_live.ex`). Reject if: (a) URL has any scheme (covers `http`, `https`, `javascript`, `data`, `file`, `mailto`, etc.); (b) URL has a host (protocol-relative `//host`); (c) path doesn't start with `/`; (d) path contains `..` segments (OWASP path traversal); (e) `route_info` returns `:error`. Stripped links keep their label text; the link wrapper is removed. Emits `[:oli, :instructor_dashboard, :email, :draft, :link_stripped]` telemetry on each parse with count metadata — maintenance signal that the AI is generating forbidden links despite prompt instruction.
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
  - [x] Step 2.1 — Whitelist placeholder substitution module supporting `{first_name}`, `{student_name}`, `{instructor_name}`, `{course_name}` (initial set; extend once `G-J03` performance-signal fields are confirmed). Implementation must be deterministic and non-evaluative; do not interpret arbitrary user-provided expressions. _Implemented: `Oli.InstructorDashboard.Email.Substitution`._
  - [x] Step 2.2 — Per-recipient template realization function: given edited subject/body templates + resolved recipient/instructor/course values, returns concrete strings. _Implemented: `Oli.InstructorDashboard.Email.Realization`._
  - [x] Step 2.3 — Oban worker enqueues one job per recipient via the existing email delivery mechanism. Worker is idempotent and respects existing delivery retries. _Implemented: `Oli.InstructorDashboard.Email.SendWorker` + parent `Oli.InstructorDashboard.Email.send_emails/2` orchestrator using `Oban.insert_all/1`._
  - [x] Step 2.4 — Send-time placeholder validation: walks subject + body, identifies any unsupported or unresolvable placeholder, and blocks dispatch with a helpful message naming the offending placeholder. _Implemented: `Oli.InstructorDashboard.Email.Validator`._
  - [x] Step 2.5 — Per-recipient result summary returned to the UI (no silent partial success). _Implemented: `send_emails/2` returns `{:ok, %{enqueued, draft_id}}` or `{:error, reasons}`; per-recipient outcomes surface via telemetry._
  - [x] Emit telemetry: `email_send_attempted`, `email_send_succeeded`, `email_send_failed`, `email_validation_blocked`. _Namespaced `[:oli, :instructor_dashboard, :email, :send, *]`; emitted in `SendWorker.perform/1` (per recipient) and `Email.send_emails/2` (batch validation_blocked)._
- **Testing Tasks:**
  - [x] Unit tests for substitution covering: known token replacement, unknown token reporting, no leakage of resolvable raw tokens. _`substitution_test.exs` — 17 tests._
  - [x] Tests for the Send-time validator (invalid placeholder text appears in the message). _`validator_test.exs` — 12 tests covering all reason types._
  - [x] Integration test for one-job-per-recipient dispatch count. _`email_test.exs` — verifies `enqueued: N` and per-recipient `user_id` arg._
  - [x] Test for partial-fail behavior matching the policy chosen in `G-J04`. _`send_worker_test.exs` validates per-recipient telemetry locus; partial failures surface via `:send :failed` telemetry rather than a real-time aggregated banner (per §2.5.b)._
  - [x] Brace-escape regression (§2.2.d) — guards Option B post-render substitution against future writer drift.
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
- **2.B5.d** `EmailContext` (`email_context.ex`) extended with two new fields, both populated by `ContextBuilder` from the LiveView `current_user`:
  - `:instructor_name` — required (added to `@enforce_keys`). Used for `{instructor_name}` token resolution at substitution time.
  - `:instructor_email` — optional. Used by `SendWorker` to set `reply_to:` per §2.3.h so student replies route to the instructor.
  Rationale: cleaner than passing instructor as a separate `send_emails/2` arg — the struct is already the canonical carrier for cross-cutting metadata, and both fields come from the same `current_user` source so they belong together.

**Step 2.1 — Whitelist substitution:**
- **2.1.a** Whitelist tokens: `{first_name}`, `{student_name}`, `{instructor_name}`, `{course_name}`. Locked in Phase 1 chunk 1.4 PromptComposer; Phase 2 substitution module reuses this list.
- **2.1.b** Direct token replacement (string scan + replace from a known map). NOT EEx — no template evaluation, no expression interpretation. Per Darren §8.
- **2.1.c** Missing or empty placeholder values surface as a validation error at Send time (chunk 2.4); substitution does NOT silently leave raw tokens — that would violate ticket negative AC ("Do not expose raw AI placeholders... when data is available").
- **2.1.d** Single-pass substitution via `Regex.replace/3` (locked 2026-05-13). Replacement values are inserted as literals — the regex does NOT re-scan the accumulated string. Closes a chain-substitution vector: a recipient whose `given_name` is literally `"{course_name}"` would otherwise have that string substituted again into the real course title on the next pass. Single-pass treats values as opaque text.
- **2.1.e** Broad unsupported-token detection regex `~r/\{[^{}]+\}/` (locked 2026-05-13). Catches malformed tokens that the whitelist regex (`{first_name|student_name|instructor_name|course_name}`) ignores: `{first-name}`, `{firstName}`, `{first_name1}`, `{First Name}`, `{ first_name }`. Empty `{}` is ignored. Without this, malformed tokens would slip through validation and reach recipients as raw text.

**Step 2.2 — Per-recipient template realization:**
- **2.2.a** Input from Phase 4 modal: `subject_template` (plain string), `body_template_slate` (Slate JSON), `EmailContext.recipients`, course/instructor metadata.
- **2.2.b** Substitution timing — **Option B locked: post-render string replace**:
  1. Server renders `body_template_slate` → HTML ONCE via `Oli.Rendering.Content.HTML.render` (template-with-tokens-intact).
  2. Server converts HTML → plain text ONCE via Premailex (template-with-tokens-intact).
  3. Per recipient: `String.replace/3` tokens in `subject_template`, rendered `html_body`, rendered `text_body` from resolved values map.
- **2.2.c** Safety basis (verified 2026-05-10): braces `{` `}` pass through both server (`Oli.Rendering.Content.HTML.escape_xml!/1` at `lib/oli/rendering/content/html.ex:1015-1019` → Phoenix.HTML `html_escape` only escapes `<>&"'`) and client (`assets/src/data/content/writers/html.tsx:88` — `decodeURI(encodeURI(text))` is identity for braces). Tokens survive rendering as literals → safe for post-render string replace.
- **2.2.d** Regression test required: assert `Oli.Rendering.Content.HTML.escape_xml!("{first_name}") == "{first_name}"` — guards against future writer drift that would silently break substitution.
- **2.2.e** Rejected Option C (pre-render Slate tree walk): equally safe but N renders per send (one per recipient) vs Option B's 1 render + N cheap string ops. Trade-off picked: perf + 5 LOC vs ~20 LOC tree walker + future-proofing. Regression test closes the future-proofing gap.
- **2.2.f** Output: `[%{user_id, email, subject, html_body, text_body}]` — concrete per-recipient strings. Pure function, no DB writes.
- **2.2.g** Token-to-value mapping (verified against Phase 1 `PromptComposer.ex:19` whitelist + `EmailContext` struct):
  - `{first_name}` → `recipient.given_name`
  - `{student_name}` → `"#{given_name} #{family_name}"` (trim trailing space if `family_name` is nil)
  - `{course_name}` → `context.course_title`
  - `{instructor_name}` → `context.instructor_name` (per 2.B5.d)
- **2.2.h** HTML → plain text via `Oli.Email.html_text_body/1` (`lib/oli/email.ex:79-86`) — reuses existing Premailex wrapper (`Premailex.to_inline_css/1` + `Premailex.to_text/1`). Do not reinvent.
- **2.2.i** HTML-escape recipient/context values before substituting into `html_body` (locked 2026-05-12). `Realization.realize_one/3` builds two values maps: raw values for `subject` + `text_body`, HTML-escaped values for `html_body`. Closes XSS vector — a recipient `given_name` of `<script>alert()</script>` would otherwise be injected as live markup into the outgoing email's HTML body. Escape covers `&`, `<`, `>`, `"`, `'`.

**Step 2.3 — Oban worker (B2 idempotency):**
- **2.3.a** Queue: `:mailer` (existing, sized 10 default — `config/config.exs:248-267`).
- **2.3.b** `unique: [keys: [:draft_id, :user_id], states: [:available, :scheduled, :retryable], period: :infinity]` — protects against Oban retries duplicating sends. Mirrors `Oli.Delivery.Attempts.PageLifecycle.GradeUpdateWorker` precedent (`grade_update_worker.ex:25-40`).
- **2.3.c** `draft_id` = UUID generated when instructor clicks Send; lives only in worker args (ephemeral; no DB persistence per ticket — see B1 below).
- **2.3.d** `max_attempts: 3` (mirrors `Oli.Delivery.Sections.Certificates.Workers.Mailer:2`).
- **2.3.e** Phase 4 modal MUST also use `phx-disable-with` on Send button to prevent double-click during in-flight enqueue (see Phase 4 step 4.6); UI-side double-click + Oban dedup form defense-in-depth.
- **2.3.f** Dedicated worker module `Oli.InstructorDashboard.Email.SendWorker` (NOT the generic `Oli.Mailer.SendEmailWorker`). Reason: adding `unique: [draft_id, user_id]` to the generic worker would pollute it for all email sends (registration, certs, help). Dedicated worker isolates instructor-email semantics. Pattern mirrors `Oli.Delivery.Sections.Certificates.Workers.Mailer` precedent.
- **2.3.g** Worker job args: `%{"email" => serialized_swoosh, "draft_id" => uuid, "user_id" => id, "section_id" => id, "situation_key" => atom_string}`. Reuses `Oli.Mailer.SendEmailWorker.serialize_email/1` + `deserialize_email/1` (already public — `send_email_worker.ex:14`, `:26`).
- **2.3.h** Sender identity (verified against `Oli.Email.help_desk_email/6` precedent at `lib/oli/email.ex:12-20`): `from:` = system address via `Oli.Email.base_email/0` (config-driven, SES-verified); `reply_to: {instructor_name, instructor_email}` so student replies route to instructor. Do NOT set `from:` to instructor — breaks SES/SPF.
- **2.3.i** `Oban.insert_all/1` raises on system-level failure (per `auto_submit_custodian.ex:59` comment). Do not wrap in try/rescue; let exceptions propagate. Per-recipient delivery failures are handled inside `perform/1` post-enqueue (telemetry + Oban retries), not surfaced from `send_emails/2`.
- **2.3.j** `SendWorker.perform/1` `:failed` telemetry emits `:error_category` only (locked 2026-05-13). Provider/Swoosh error reasons are NOT inspected into telemetry — they may contain SMTP responses, auth fragments, or recipient data. `classify_error/1` maps raw reasons to `:timeout`, `:network`, `:delivery_error`, or `:exception` (rescue path). Symmetric with `AIDraftFacade`'s `raw_reason` drop locked in Session 7.

**Step 2.4 — Send-time validation (B3 timing):**
- **2.4.a** Server-authoritative at Send. Layer 2 of validation (per B3 audit). Per Darren comment 44655 + Jess comment 44656 — both explicitly state validation must trigger at Send.
- **2.4.b** Validates: `recipients > 0` (G-J05); each email well-formed; every placeholder in subject + body is in whitelist AND resolvable for every recipient.
- **2.4.c** Returns `{:ok, _}` (proceed to enqueue) OR `{:error, [{:placeholder, "..."} | {:recipient, ...} | ...]}` for UI display.
- **2.4.d** Phase 4 modal will ALSO run option (3) flow: validate after AI generation (early UX feedback) + at Send (server-authoritative). Track `dirty?` flag in LiveView assigns to know whether to show stale errors after manual edits. Phase 2 backend just provides the authoritative validator; Phase 4 wires the UI flow.
- **2.4.e** Layer 3 (perform-time revalidation in Oban worker) deferred — only add if recipient-row-mutation race surfaces in production.
- **2.4.f** Resolvability check (`check_token_resolvability/3`) narrowed to recipient-derived tokens only (`{first_name}`, `{student_name}`). Context-derived tokens (`{course_name}`, `{instructor_name}`) are guaranteed non-nil by `ContextBuilder.fetch_required/3` (rejects both nil and `""`) plus `EmailContext.@enforce_keys`, so iterating recipients for them would be dead work.
- **2.4.g** `check_instructor_email/2` (locked 2026-05-13): if `context.instructor_email` is set (non-nil non-empty), validates the well-formed-email regex. Malformed addresses return `{:invalid_instructor_email, addr}` reason and block Send. Required because `instructor_email` flows into the outbound `Reply-To` header where malformed values can break clients or misdirect replies. Empty/nil instructor_email is acceptable (no Reply-To set).
- **2.4.h** `check_duplicate_recipients/2` (locked 2026-05-13): rejects any `context.recipients` list where a `student_id` appears more than once. Returns `{:duplicate_recipients, [user_ids]}` reason. Required because `SendWorker`'s `unique: [keys: [:draft_id, :user_id], ...]` constraint silently skips the duplicate insert at the Oban layer — without this validator check, `enqueue/3` would return an accurate (smaller) count but the instructor sees fewer emails than expected with no explicit feedback. Catches realistic Phase 5 entry-point bugs where a projection puts the same student in multiple buckets.

**Step 2.5 — Per-recipient result summary (B4):**
- **2.5.a** Per ticket: success → "Email sent" banner. Per Darren §9: "Send/enqueue failure: no silent partial success; return actionable feedback." NOT persisted in DB (ticket + comments do not require audit/history schema).
- **2.5.b** Banner copy revised based on §2.3.i audit: `send_emails/2` returns at ENQUEUE time, not at delivery time. Final banner = "Queued N emails for delivery." On `Oban.insert_all` exception (system-level failure): "Could not queue emails — please retry." Real delivery failures surface via telemetry + Oban dashboard, NOT as a real-time banner (would require synchronous wait on N async jobs). `send_emails/2` return shape: `{:ok, %{enqueued: N, draft_id: uuid}}`.
- **2.5.c** Telemetry events emitted per recipient inside `SendWorker.perform/1` (consistent namespace with existing `[:oli, :instructor_dashboard, :email, :draft, *]` events from `AIDraftFacade`):
  - `[:oli, :instructor_dashboard, :email, :send, :attempted]` at perform start
  - `[:oli, :instructor_dashboard, :email, :send, :succeeded]` on `Oli.Mailer.deliver/1` `:ok`
  - `[:oli, :instructor_dashboard, :email, :send, :failed]` on `Oli.Mailer.deliver/1` error or rescue
  - Metadata: `%{section_id, draft_id, user_id, situation_key, attempt: job.attempt}`
- **2.5.d** `[:oli, :instructor_dashboard, :email, :send, :validation_blocked]` emitted from `validate/2` BEFORE enqueue (batch-level, once per Send click). Metadata: `%{section_id, situation_key, reasons: [...] }`.
- **2.5.e** `send_emails/2` `:ok` payload `enqueued` value is the **actual** count of fresh inserts from `Oban.insert_all/1` (rows where `conflict? == false`), NOT the input recipient count (locked 2026-05-13). Truth from the side effect, defense-in-depth against future bypass of §2.4.h's duplicate check.

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

## Phase 7 — Instructor Link Mode (post-review fix, PR #6606)

**Why:** Manual testing as an instructor (vs. the admin/author account used earlier, which masked it) revealed the body editor's link feature is non-functional for instructors — the feature's intended users. Root cause: the modal reuses the authoring `LinkModal`, which (a) fetches project pages from the author-only endpoint `GET /api/v1/project/:project/link` (`:require_authenticated_author`) → instructors get `302 → /authors/log_in` → "Failed to initialize"; and (b) the toolbar/⌘L insert sets `href` = selected text → normalizes to `http://…`, which the email `LinkValidator` rejects at send (internal `/course/link/:slug` only). Net: an instructor cannot produce a single sendable link.

**Validated** across 3 Codex review rounds. Email links are internal-only by security contract (`LinkValidator`); `/course/link/:slug` is rewritten to a section delivery URL at render (`html.ex:829`). Out-of-scope side issues filed separately: TRIAGE-2352 (chart dup-key), TRIAGE-2353 (lesson-route 500 on unresolvable slug — covers post-send deleted-page links, a pre-existing delivery-routing bug; no send-time filter can prevent it).

**Page source decision (locked):** link to all non-hidden section lessons via `SectionResourceDepot.get_lessons(section_id)`. No gating/schedule/`removed_from_schedule` pre-filter — delivery enforces availability at click time (`LessonLive`/`InitPage` → `Gating.blocked_by`), matching every other internal-link picker in Torus. Save `revision_slug` (not resource slug).

### Design — the two non-obvious pieces

**1. Picker-first insert (riskiest).** Both the toolbar button (`DescriptiveButton.onMouseDown`) and ⌘L (`hotkey.ts`) call `command.execute(context, editor)` directly. In email mode, `LinkCmd.execute` must NOT wrap the selection with a free-text href. Instead:
  - capture the current selection up front (`Editor.rangeRef(editor, editor.selection)`) so it survives the modal stealing focus;
  - `window.oliDispatch(modalActions.display(<page picker>))` — reuse the `LinkModal` email-mode render;
  - on confirm: restore the range (`Transforms.select(editor, rangeRef.unref())`), then `Transforms.wrapNodes(editor, Model.link(\`/course/link/\${slug}\`), { split: true })`;
  - on cancel: `rangeRef.unref()`, no-op.
  - If the selection is collapsed (no text selected), insert the page title as the link text.

**2. Mode + page list plumbing.** Extend `CommandContext` with an optional `linkContext?: { mode: 'email'; pages: { id; slug; title; numbering_index }[] }` (absent = current authoring behavior, unchanged). Thread: `draft_email_modal.ex` loads `get_lessons` → DTO → passes as a new `linkContext` prop on the `RichTextEditor` React component → `RichTextEditor`/`Editor` merge it into `commandContext` → reaches `LinkCmd.execute` and `LinkModal` (both already receive `commandContext`).

### File-by-file
- `assets/src/components/editing/elements/commands/interfaces.ts` — add optional `linkContext` to `CommandContext`.
- `lib/.../tiles/draft_email_modal.ex` — load `SectionResourceDepot.get_lessons(section_id)`, project to DTO, pass as `linkContext` prop (mode `email`).
- `assets/src/components/content/RichTextEditor.tsx` — accept `linkContext` prop, fold into `commandContext`.
- `assets/src/components/editing/elements/link/LinkCmd.tsx` — email-mode branch: picker-first (above).
- `assets/src/components/editing/elements/link/LinkModal.tsx` — email-mode render: skip `Persistence.pages`; page-select sourced from `linkContext.pages`; no URL/media radios; force existing internal links to `page` mode (don't trust stale `linkType`, `:34`); save `/course/link/:revision_slug`. Empty list → explain "no linkable pages" + disable confirm.
- (authoring path: untouched in all files — guarded behind `linkContext?.mode === 'email'`.)

### Tests (TDD order)
1. Server DTO assembly (Elixir, `draft_email_modal` test): props carry only projected visible page metadata for the section, using `revision_slug`; hidden excluded; `removed_from_schedule` included.
2. `LinkModal` email mode (jest, `--coverage=false`): skips `Persistence.pages`; renders page-select only; initializes an existing `/course/link` link to `page` mode; saves selected `revision_slug`; empty-pages state.
3. `LinkCmd` email mode (jest): toolbar + ⌘L open the picker; confirm wraps the preserved selection with `/course/link/:slug`; cancel no-ops; collapsed-selection inserts page title.
4. Regression: authoring mode unchanged (no `linkContext` → existing fetch + radios).
5. `LinkValidator` (exists) + `html.ex` rewrite (exists) remain the backend guardrails.

**Gate:** all targeted jest + Elixir tests pass; `mix format`; authoring link flow manually unaffected; instructor can insert + edit a course-page link end-to-end and send.

### Review corrections (Codex round, locked — supersede the above where conflicting)

**Blocking — verified:**
- **Do NOT use `Model.link(\`/course/link/${slug}\`)`** — `Model.link` always runs `normalizeHref` (`factories.ts:168`) → `http:///course/link/slug`, recreating the bug. Extend the factory with an explicit page mode, e.g. `Model.link(href, 'page')` that skips normalization and sets `linkType: 'page'`; external callers (default) keep normalizing unchanged.
- **⌘L address-bar steal:** `hotkey.ts:20` link branch never calls `e.preventDefault()`. Add it (+ test). Safe globally — address-bar steal is undesirable in authoring too.

**Selection restore (mirror the shipped pattern):** follow `pageLinkActions.tsx` (promise-returning modal → mutate Slate in `.then`, no `ReactEditor.focus` needed — transforms are model ops). Safeguards: `if (!editor.selection) return;` up front; `Editor.rangeRef(editor, sel, { affinity: 'inward' })`; on confirm `const range = ref.unref(); if (!range || !ReactEditor.hasRange(editor, range)) return;` then pass `{ at: range }` to `wrapNodes` (selection) / `insertNodes` (collapsed → link node with page-title child). Make confirm/cancel cleanup **idempotent** (modal dismiss can also fire `onCancel`).

**Toggle preserved:** when the selection is already inside a link, the command must keep its current **unwrap** behavior (`LinkCmd.tsx:15-19`) — do NOT open a second picker.

**Context plumbing:** prefer passing the full nested `commandContext` from `draft_email_modal.ex` rather than a parallel top-level prop; if a prop is used, merge explicitly (don't replace caller fields at `RichTextEditor.tsx:117`). **`Editor`'s `React.memo` comparator (`Editor.tsx:57`) ignores `commandContext`** → add it to the comparator (or guarantee full context on the first LiveReact bridge render). Test the two-pass LiveReact init.

**A11y (MER-5257 ACs):** give the modal a real title (currently `title=""`, `LinkModal.tsx:193`); move initial focus to the page-select (not the close button); verify the nested focus trap (React modal over the Phoenix Draft Email modal); sort pages by `numbering_index` then `title`+`id` (deterministic for null/equal).

**Edge cases:** empty pages → explanatory state + Save disabled (never `toInternalLink(null)`); one page → preselect + Save enabled.

**Added tests:** created href is exactly `/course/link/x` (never `http:///…`); ⌘L calls `preventDefault`; null/invalidated `RangeRef` exits safely; active-link invocation unwraps (no nesting); one undo restores pre-insert doc; collapsed insertion yields page-title text; full `commandContext` survives LiveReact prop updates / `React.memo`; modal accessible name, initial focus, keyboard select, Escape/cancel + focus return.

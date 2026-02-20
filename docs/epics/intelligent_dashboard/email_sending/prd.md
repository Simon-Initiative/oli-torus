# Context-Aware AI Email Sending — PRD

## 1. Overview
Feature Name: Context-Aware AI Email Sending

Summary: Provide a reusable dashboard email workflow that generates context-aware AI draft subject/body templates, supports tone-driven regeneration, and sends individualized emails to selected recipients. The architecture splits non-UI domain services (context, prompting, template realization) from reusable modal UI for testability and reuse.

Links: `docs/epics/intelligent_dashboard/email_sending/informal.md`, `docs/epics/intelligent_dashboard/ai_infra/informal.md`, `https://eliterate.atlassian.net/browse/MER-5257`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Instructor outreach from dashboard contexts lacks standardized context-aware AI draft generation.
  - Entry points across tiles/pages need a common contract for situation semantics and recipient context.
  - Placeholder realization and per-recipient send orchestration are not formalized.
- Affected users/roles:
  - Instructors communicating with selected students.
- Why now:
  - Email is a core action path tied to dashboard insights and intervention workflows.

## 3. Goals & Non-Goals
- Goals:
  - Create non-UI services for context building, prompt composition, AI draft generation, and template realization.
  - Deliver reusable `Draft Email` modal callable from multiple dashboard entry points.
  - Support tone selection and regenerate-on-demand behavior.
  - Send one personalized email job per recipient via existing delivery mechanism.
- Non-Goals:
  - Building a standalone campaign management system.
  - Provider-specific LLM experimentation beyond contract boundaries.
  - Instructor-level persistent personalization profiles.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Instructor in section dashboard context.
- Use Cases:
  - Instructor opens email modal from Student Support for struggling students and gets context-specific draft.
  - Instructor switches tone and regenerates draft before editing/sending.
  - Instructor sends personalized emails to selected recipients plus manual additions.

## 5. UX / UI Requirements
- Key Screens/States:
  - Reusable `Draft Email` modal with recipients, subject, body, tone controls, generate button, send action.
  - Loading and failure states for AI generation/regeneration.
  - Editable subject/body with placeholder guidance.
- Navigation & Entry Points:
  - Entry from supported dashboard locations (Student Support, Assessments, Student Overview, Content/LO student lists, etc.).
- Accessibility:
  - Modal focus trap and return, keyboard control for recipient chips and actions.
  - Tone controls expose selected state semantics.
  - Validation and dynamic update announcements for assistive tech.
- Internationalization:
  - Labels and helper text externalized.
- Screenshots/Mocks:
  - Refer to Jira/Figma assets linked from `docs/epics/intelligent_dashboard/email_sending/informal.md`.

## 6. Functional Requirements
| ID | Description | Priority | Owner |
|---|---|---|---|
| FR-001 | Implement reusable non-UI context builder that reads required data and returns normalized email context (section/course/instructor, recipients, situation, optional signals, default tone). | P0 | Data/AI |
| FR-002 | Define stable `situation` contract using enumerated keys mapped to canonical descriptions for prompt composition. | P0 | AI |
| FR-003 | Implement non-UI AI draft generation service that composes prompt from context+tone and calls existing synchronous completion generator, returning subject/body templates. | P0 | AI |
| FR-004 | Implement reusable `Draft Email` modal within instructor dashboard UI, callable from multiple entry points with context payload. | P0 | UI |
| FR-005 | Modal opens with default tone `neutral` and initial AI-generated draft; changing tone does not regenerate until `Generate new draft` is clicked. | P0 | UI |
| FR-006 | Subject and body are editable prior to send; regeneration replaces current draft content using selected tone and current context. | P0 | UI |
| FR-007 | Implement placeholder substitution service for curly-brace tokens using whitelist-based variable mapping and deterministic replacement. | P0 | AI/Data |
| FR-008 | On send, realize per-recipient subject/body and enqueue one existing email delivery job per recipient. | P0 | Data |
| FR-009 | Validate send preconditions (non-empty recipients, valid required fields) and prevent send on invalid state. | P0 | UI |
| FR-010 | On generation/send failures, preserve user-editable modal state and show actionable error feedback (no silent partial success). | P0 | UI/AI |

## 7. Acceptance Criteria
- AC-001 (FR-001, FR-004) — Given instructor opens email from supported entry point, when modal initializes, then normalized context is built and modal prepopulates recipients accordingly.
- AC-002 (FR-002, FR-003) — Given situation key and context inputs, when draft generation runs, then prompt includes canonical situation description and returns subject/body templates.
- AC-003 (FR-005) — Given modal opens, when first render completes, then neutral tone is selected and initial draft is generated.
- AC-004 (FR-005, FR-006) — Given tone selection changes, when no regenerate action occurs, then draft remains unchanged; when `Generate new draft` is clicked, then new draft reflects selected tone.
- AC-005 (FR-006) — Given generated draft exists, when instructor edits subject/body, then edits persist until explicit regeneration or send.
- AC-006 (FR-007) — Given placeholders in template and recipient variables available, when realization runs, then known placeholders are resolved and raw placeholder tokens are not sent when data exists.
- AC-007 (FR-008) — Given N recipients at send time, when send executes, then N email jobs are enqueued with individualized realized subject/body.
- AC-008 (FR-009) — Given recipient list empty or fields invalid, when instructor attempts send, then send is blocked and validation feedback is shown.
- AC-009 (FR-010) — Given generation or send failure occurs, when error is returned, then modal remains open with recoverable state and explicit error messaging.

## 8. Non-Functional Requirements
- Performance & Scale: No load or performance testing requirements for this phase.
- Reliability:
  - Send flow is deterministic with explicit success/failure outcomes; no silent partial completion.
- Security & Privacy:
  - Context builder enforces section authorization and excludes unnecessary PII in prompts/logs.
  - Placeholder substitution must not evaluate arbitrary code expressions.
- Compliance:
  - WCAG 2.1 AA modal, chip, and dynamic announcement requirements.
- Observability:
  - AI-focused telemetry required: generation latency, generation success/failure by category, token/cost usage (if available), regeneration rate, send enqueue counts and failures.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - None required for baseline flow unless additional persistence is introduced separately.
- Context Boundaries:
  - Non-UI: `EmailContextBuilder`, `EmailPromptComposer`, `EmailDraftGenerator`, `EmailTemplateRealizer`.
  - UI: reusable `DraftEmailModal` and entry-point adapters.
- APIs / Contracts:
  - `build_email_context(entry_point, section_id, actor_id, selection) -> context`
  - `generate_email_draft(context, tone) -> %{subject_template, body_template}`
  - `realize_template(template, recipient_vars) -> string`
  - `send_email_batch(context, edited_subject_template, edited_body_template, recipients) -> enqueue_result`
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Instructor | Open modal, generate/regenerate draft, send emails | Section-scoped and authorized only |
| Student | None | Not exposed |
| Admin | Allowed in authorized contexts | Same auth and audit constraints |

## 10. Integrations & Platform Considerations
- LTI 1.3:
  - Instructor authorization and section scoping use existing pathways.
- GenAI (if applicable):
  - Uses existing completion service through thin domain facade; prompt composition remains dashboard-domain specific.
  - Must support deterministic fallback messaging on low-signal/failure conditions.
- External services:
  - Email delivery via existing Oban-backed Torus mail job mechanism.
- Caching/Perf:
  - Context builder should avoid redundant DB reads and keep query footprint bounded.
- Multi-tenancy:
  - Context and recipients strictly constrained to section/institution boundaries.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - Draft generation success rate.
  - Median generation latency.
  - Send completion rate and enqueue failure rate.
  - Regenerate usage rate by tone.
- Events:
  - `email_draft.generated`
  - `email_draft.generation_failed`
  - `email_draft.regenerated`
  - `email_send.batch_enqueued`
  - `email_send.batch_failed`

## 13. Risks & Mitigations
- Prompt-context inconsistency across entry points -> enforce normalized context builder and situation enum mapping.
- Placeholder leakage into sent mail -> strict whitelist substitution with unresolved-token checks before enqueue.
- Slow generation harming UX -> loading states, retry paths, and latency monitoring with SLO thresholds.
- Send failures for large batches -> deterministic failure reporting and idempotent enqueue logic.

## 14. Open Questions & Assumptions
- Assumptions:
  - Existing completion and email job infrastructure are available and stable.
  - Entry points can provide enough identifiers for context builder to derive canonical situation.
- Open Questions:
  - Should manual recipient additions be restricted by institution/domain policy in v1?

## 15. Timeline & Milestones (Draft)
- Define context/situation contracts and prompt composer.
- Implement draft generation and placeholder realization services.
- Build reusable modal and entry-point integration adapters.
- Integrate send enqueue path and complete accessibility/AI telemetry QA.

## 16. QA Plan
- Automated:
  - Unit tests for context builder, situation mapping, prompt composer, and placeholder substitution.
  - Component tests for modal states, tone/regenerate behavior, and validation gates.
  - Integration tests for per-recipient realization and job enqueue fan-out.
- Manual:
  - Accessibility validation (keyboard, screen reader, modal focus semantics).
  - Scenario checks across multiple entry points and context types.
- Performance Verification: Not required for this phase.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)

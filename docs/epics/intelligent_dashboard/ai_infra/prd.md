# Intelligent Dashboard AI Recommendation Infrastructure — PRD

## 1. Overview
Feature Name: AI Recommendation Infrastructure

Summary: Build backend recommendation infrastructure contracts for context shaping, generation orchestration, feedback ingestion, and regeneration semantics as a dashboard oracle capability. The feature provides deterministic lifecycle behavior, daily implicit generation rate limits per container, cache coherence on regeneration, and robust failure handling for UI consumers.

Links: `docs/epics/intelligent_dashboard/ai_infra/informal.md`, `docs/epics/intelligent_dashboard/summary_tile/prd.md`, `docs/epics/intelligent_dashboard/feedback_ui/prd.md`, `https://eliterate.atlassian.net/browse/MER-5305`, `lib/oli_web/live/admin/intelligent_dashboard_live.ex`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Recommendation logic lacks formalized backend contracts aligned to dashboard oracle architecture.
  - Implicit recommendation generation needs shared per-container rate limiting across instructors.
  - Feedback and regeneration pathways require deterministic cache invalidation/update semantics to avoid stale recommendations.
  - Failure/no-signal behavior needs explicit non-breaking fallback guarantees.
- Affected users/roles:
  - Instructors consuming recommendations; engineering teams implementing UI consumers.
- Why now:
  - Summary tile and feedback UI depend on stable backend recommendation APIs and runtime guarantees.

## 3. Goals & Non-Goals
- Goals:
  - Implement recommendation generation as oracle-integrated backend capability.
  - Define normalized recommendation input/output contracts.
  - Implement thumbs feedback and regeneration operations through same contract boundary.
  - Enforce per-section-container implicit generation at most once per 24 hours.
  - Provide strong observability for AI lifecycle, latency, outcomes, and failure categories.
- Non-Goals:
  - Building recommendation UI components in this ticket.
  - Implementing AI email modal UX.
  - Final copy/tone experiments outside contract interfaces.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Instructor (consumer via summary tile/feedback controls).
  - Backend services orchestrating recommendation lifecycle.
- Use Cases:
  - Instructor opens dashboard; recommendation is served from cache or generated if stale by rate-limit policy.
  - Instructor submits thumbs feedback and optional additional feedback.
  - Instructor regenerates recommendation and sees updated content without stale cached responses.

## 5. UX / UI Requirements
- Key Screens/States:
  - No direct UI delivery; supports UI states (`thinking`, recommendation content, fallback, failure-safe output).
- Navigation & Entry Points:
  - Entered via summary tile load, feedback controls, and regenerate actions.
- Accessibility:
  - N/A directly; contracts must provide deterministic strings suitable for accessible UI rendering.
- Internationalization:
  - Contract supports UI-localized wrappers; generated content remains model output.
- Screenshots/Mocks:
  - Refer to Jira-linked design notes and prototype reference.

## 6. Functional Requirements
| ID | Description | Priority | Owner |
|---|---|---|---|
| FR-001 | Implement recommendation generation as an instructor dashboard oracle-compatible backend capability. | P0 | AI/Data |
| FR-002 | Define normalized recommendation input contract using scoped dashboard snapshot/projection context and descriptor-driven dataset injection. | P0 | AI |
| FR-003 | Define recommendation output contract including body text and metadata fields required by UI (e.g., generated_at, source_scope, confidence/quality metadata where applicable). | P0 | AI |
| FR-004 | Implement implicit generation rate-limit cache persisted per section+container, allowing auto-regeneration only when prior implicit generation is older than 24 hours. | P0 | Data |
| FR-005 | Support explicit regeneration operation that bypasses implicit rate limit and refreshes recommendation payload for current scope. | P0 | AI/Data |
| FR-006 | Regeneration must invalidate or refresh in-process and revisit cache entries so subsequent navigation does not show stale recommendation content. | P0 | Data |
| FR-007 | Implement feedback ingestion contracts for thumbs sentiment and additional textual feedback through recommendation service boundary. | P0 | AI/Data |
| FR-008 | Provide deterministic no-signal and failure fallback responses safe for UI display (no fabricated urgency). | P0 | AI |
| FR-009 | Enforce secure handling of prompt/context data and prevent raw student PII leakage in logs/telemetry payloads. | P0 | AI/Security |
| FR-010 | Reference existing prototype prompting structure and evaluate compatibility with tool-driven architecture, retaining contract-level pluggable dataset inputs. | P1 | AI |

## 7. Acceptance Criteria
- AC-001 (FR-001, FR-002, FR-003) — Given scoped dashboard context, when recommendation generation is requested, then service returns contract-compliant recommendation output consumable by summary UI.
- AC-002 (FR-004) — Given implicit generation already occurred within prior 24 hours for same section+container, when implicit request arrives, then cached/recent recommendation is returned without new generation.
- AC-003 (FR-004) — Given implicit generation timestamp exceeds 24 hours, when implicit request arrives, then new recommendation is generated and rate-limit timestamp updated.
- AC-004 (FR-005, FR-006) — Given instructor triggers explicit regenerate, when operation succeeds, then new recommendation is returned and relevant in-process/revisit cache entries are refreshed/invalidated.
- AC-005 (FR-007) — Given thumbs or additional feedback submission, when request completes, then feedback is persisted/forwarded through contract-defined pathway.
- AC-006 (FR-008) — Given low-signal or generation failure scenarios, when response is returned, then deterministic fallback payload is provided and UI can render without breaking.
- AC-007 (FR-009) — Given telemetry/logging events, when emitted, then they exclude raw student PII fields and include only sanctioned metadata.
- AC-008 (FR-010) — Given prototype prompt baseline, when architecture is finalized, then chosen prompt composition path remains compatible with contract-level pluggable dataset descriptors.

## 8. Non-Functional Requirements
- Performance & Scale: No load or performance testing requirements for this phase.
- Reliability:
  - Recommendation service availability >= 99.5% for dashboard requests.
  - Failure responses are deterministic and non-breaking for UI.
- Security & Privacy:
  - Prompt/context handling enforces least-data principle and redacts or omits sensitive fields in logs/events.
- Compliance:
  - Operational behavior supports institutional privacy expectations for student data handling.
- Observability:
  - Required AI telemetry: generation outcome, latency, error category, regeneration rate, implicit-rate-limit hit/miss, token/cost usage (when available), feedback submission outcomes.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - Add/extend persistence for recommendation rate-limit state keyed by section+container (and recommendation artifacts/metadata if required by implementation).
- Context Boundaries:
  - Recommendation oracle/service modules in instructor dashboard domain.
  - Cache integration points with data coordinator/cache layers.
  - Feedback ingestion endpoints/services.
- APIs / Contracts:
  - `get_recommendation(scope_context, mode: :implicit | :explicit_regen)`
  - `submit_recommendation_feedback(recommendation_id, sentiment, additional_text \\ nil)`
  - `build_recommendation_prompt(context, datasets, options)`
  - `handle_recommendation_fallback(reason, context)`
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Instructor | Trigger implicit load, explicit regenerate, feedback submission | Section-scoped authorization required |
| Student | None | Not exposed |
| Admin | Operational visibility/support only as authorized | Must follow privacy controls |

## 10. Integrations & Platform Considerations
- LTI 1.3:
  - Uses existing instructor role and section-context authorization.
- GenAI (if applicable):
  - Integrates with existing completion provider stack through recommendation service abstraction.
  - Supports pluggable dataset descriptor injection; tool-driven decomposition is allowed if contract-compatible.
  - Requires rate-limit-aware orchestration and fallback handling.
- External services:
  - Potential Slack/admin feedback routing integration for qualitative feedback pathways (if configured by implementation).
- Caching/Perf:
  - Must integrate with in-process and revisit caches; explicit regeneration refreshes cache entries.
- Multi-tenancy:
  - All recommendation context/rate limits scoped by section and selected container; no cross-tenant leakage.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - Recommendation generation success rate.
  - p50/p95 generation and regeneration latency.
  - Implicit rate-limit hit ratio.
  - Feedback submission success rate.
- Events:
  - `ai_recommendation.requested`
  - `ai_recommendation.completed`
  - `ai_recommendation.failed`
  - `ai_recommendation.regenerated`
  - `ai_recommendation.rate_limit_hit`
  - `ai_recommendation.feedback_submitted`

## 13. Risks & Mitigations
- Stale recommendation after regen -> mandatory cache invalidation/refresh path and integration tests.
- Over-generation cost/latency -> enforce 24h implicit throttle and track rate-limit hit/miss metrics.
- Prompt-quality inconsistency across contexts -> normalized input contract and deterministic fallback messaging.
- PII leakage risk -> strict redaction policy in logging/telemetry and prompt payload audits.

## 14. Open Questions & Assumptions
- Assumptions:
  - Existing admin prototype prompt shape is suitable baseline but may be adapted to tool-driven architecture while preserving contracts.
  - Recommendation IDs and metadata are available to bind feedback/regeneration operations.
- Open Questions:
  - Which confidence/quality metadata fields are required in UI v1 beyond text/timestamps?

## 15. Timeline & Milestones (Draft)
- Define recommendation contracts (input/output/lifecycle).
- Implement rate-limit persistence and implicit generation semantics.
- Implement feedback + regeneration paths with cache coherence.
- Add AI observability, fallback behavior, and contract tests.

## 16. QA Plan
- Automated:
  - Unit tests for prompt/context shaping, fallback generation, and rate-limit policy.
  - Integration tests for implicit vs explicit generation, cache invalidation, and feedback flows.
  - Security tests ensuring telemetry/logs exclude disallowed PII.
- Manual:
  - Validate UI-consumable outputs for normal/no-signal/failure cases.
  - Validate regeneration freshness on repeated dashboard navigation.
- Performance Verification: Not required for this phase.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)

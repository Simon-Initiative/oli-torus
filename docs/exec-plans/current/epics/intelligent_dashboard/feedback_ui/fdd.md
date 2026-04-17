# AI Recommendation Feedback UI - Functional Design Document

## 1. Executive Summary
This feature completes the instructor-facing recommendation interaction loop inside the Intelligent Dashboard summary tile. The design extends the existing recommendation lifecycle and summary-tile interaction flow to support three additional behaviors: post-sentiment UI state transitions, qualitative feedback submission through an accessible modal, and persistence of the exact `original_prompt` payload used for each recommendation generation.

The implementation stays within existing repository boundaries: LiveView and component state remain in the instructor dashboard surface, recommendation persistence and authorization stay in `Oli.InstructorDashboard.Recommendations`, and Slack delivery is mediated through `Oli.Slack`. The design intentionally preserves the existing `recommendation_instance_id` relationship for feedback while adding prompt-persistence fidelity at the recommendation-instance layer rather than denormalizing feedback storage.

## 2. Requirements & Assumptions
- Functional requirements:
  - Render thumbs-up, thumbs-down, and regenerate controls for a visible recommendation.
  - Persist one thumbs sentiment per user and recommendation instance.
  - Replace thumbs controls with an `Additional feedback` action after sentiment submission.
  - Open an accessible modal for qualitative feedback submission, with submit and cancel behavior.
  - Route qualitative feedback to the configured admin Slack integration.
  - Regenerate recommendations for the current dashboard scope while preserving the previous recommendation on failure.
  - Persist both `prompt_snapshot` and `original_prompt` for recommendation generation and regeneration.
- Non-functional requirements:
  - Preserve keyboard and screen-reader accessibility for icon controls, tooltips, and modal flow.
  - Keep authorization and section scoping server-side.
  - Avoid logging raw instructor-entered feedback together with recommendation prompt context.
  - Reuse existing LiveView task orchestration and dashboard cache refresh behavior.
- Assumptions:
  - `MER-5249` and `MER-5305` provide the baseline summary recommendation tile and regeneration contract already present on this branch.
  - The same Slack webhook used elsewhere in the application is acceptable for routing qualitative recommendation feedback to the designated admin channel.
  - `original_prompt` should persist the final request payload actually sent to the LLM, not just the intermediate prompt contract.

## 3. Repository Context Summary
- What we know:
  - `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/summary_tile.ex` already renders recommendation content plus thumbs/regenerate buttons.
  - `lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex` already owns async sentiment and regeneration request orchestration, including stale-event protection and flash handling.
  - `lib/oli/instructor_dashboard/summary_recommendation_adapter/recommendations.ex` already adapts sentiment and regeneration calls to `Oli.InstructorDashboard.Recommendations`.
  - `lib/oli/instructor_dashboard/recommendations.ex` already persists `RecommendationInstance` and `RecommendationFeedback`, authorizes section access, emits recommendation telemetry, and refreshes dashboard caches on regeneration.
  - `lib/oli/instructor_dashboard/recommendations/builder.ex` already produces a sanitized `prompt_snapshot` contract from the dashboard snapshot.
  - `lib/oli/instructor_dashboard/recommendations/prompt.ex` already produces the final model messages from the input contract.
  - `lib/oli/slack.ex` already sends structured webhook payloads to Slack and has focused unit coverage.
  - Existing `Oli.Slack` usage in LTI/institutions flows sends short administrative notifications using `username`, `icon_emoji`, and Slack Block Kit `blocks`, which is the repository-local pattern to follow here.
  - The instructor dashboard already has nearby modal interaction patterns, including the thresholds modal used by the student summary tile, which this feature can follow instead of introducing a new modal architecture.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- `SummaryTile` remains the presentational owner of recommendation controls and recommendation-specific visual state.
- `IntelligentDashboardTab` remains the orchestration layer for user events, modal open/close state, async requests, stale-event protection, and flash/announcement messages.
- `SummaryRecommendationAdapter` expands from a two-method surface to include qualitative feedback submission so the tile continues to depend on a narrow backend contract.
- `Oli.InstructorDashboard.Recommendations` remains the domain boundary for persistence, authorization, prompt construction, and feedback insertion.
- A new recommendation-feedback Slack formatting helper should live under the instructor-dashboard recommendation area rather than inside the LiveView, so delivery formatting stays testable and backend-owned.

### 4.2 State & Data Flow
1. Dashboard projection renders the summary tile with the current recommendation payload and `summary_tile_state`.
2. Instructor clicks thumbs up or down.
3. LiveView validates recommendation identity and current scope, dispatches async sentiment submission through the adapter, and records local tile state to lock further thumbs actions.
4. On success, the tile rerenders with thumbs controls replaced by an `Additional feedback` button. Regenerate remains available unless recommendation state disables it.
5. Instructor clicks `Additional feedback`.
6. LiveView opens a modal tied to the existing dashboard LiveView process, prefilling recommendation identity and current submitted sentiment in assigns.
7. On submit, LiveView validates non-empty text, dispatches qualitative feedback submission through the adapter/backend, persists `RecommendationFeedback` with `feedback_type: :additional_text`, builds a Slack payload from the recommendation instance plus instructor context, and sends it via `Oli.Slack`.
8. On success, modal closes, focus returns to the triggering button, and the instructor receives a success flash/announcement. On failure, modal remains open with an error state.
9. On regenerate, the existing async path remains in place. The backend generates a new recommendation instance, persists both `prompt_snapshot` and `original_prompt`, refreshes caches, and returns the normalized recommendation payload. If regeneration fails, the current recommendation body remains visible and the LiveView emits a non-blocking error flash.

### 4.3 Lifecycle & Ownership
- `prompt_snapshot` is owned by the recommendation builder and remains a sanitized, derived artifact used to describe recommendation context.
- `original_prompt` is owned by the final LLM request assembly step and is persisted on `RecommendationInstance` as a write-once historical record of what was actually sent to the model.
- `RecommendationFeedback` remains a child of `RecommendationInstance` for recommendation identity and per-user uniqueness of sentiment.
- Modal visibility and temporary qualitative feedback form state belong to the instructor dashboard LiveView, not to the Ecto schema layer.
- The modal should follow the same LiveView-owned interaction pattern already used for the student summary tile thresholds modal rather than introducing a separate reusable architecture for this single flow.

### 4.4 Alternatives Considered
- Store `original_prompt` on `RecommendationFeedback`:
  - rejected because prompt identity belongs to recommendation generation, not to feedback submission, and the same recommendation may receive multiple feedback rows.
- Replace the `recommendation_instance_id` relationship with a fully denormalized feedback table:
  - rejected for this phase because the feature already has a stable recommendation-instance model and the product need is delivery of the interaction loop, not analytics-pipeline redesign.
- Keep only `prompt_snapshot` and infer the final prompt later:
  - rejected because `prompt_snapshot` is intentionally sanitized and builder-level; it does not guarantee recovery of the exact provider request once prompt templates evolve.

## 5. Interfaces
- Existing adapter contract:
  - `request_regenerate(context, recommendation_id)`
  - `submit_sentiment(context, recommendation_id, sentiment)`
- New adapter contract:
  - `submit_additional_feedback(context, recommendation_id, feedback_text)`
- Domain contract additions:
  - `Recommendations.submit_feedback/3` continues to handle both thumbs and `additional_text`.
  - Recommendation generation internals persist a new `original_prompt` attribute on `RecommendationInstance`.
- LiveView event additions:
  - open additional feedback modal
  - close/cancel additional feedback modal
  - submit additional feedback modal
- Slack integration:
  - backend helper builds a stable administrative Slack payload and calls `Oli.Slack.send/1`
  - payload shape follows the existing repo pattern:
    - `username`
    - `icon_emoji`
    - `blocks`
  - payload content should stay short and review-oriented, including only the minimum section/scope, sentiment, recommendation text, and additional feedback context needed by admins

## 6. Data Model & Storage
- `instructor_dashboard_recommendation_instances`
  - add `original_prompt`, stored as a `:map`, default `%{}`
  - keep `prompt_snapshot`, `prompt_version`, `message`, and `response_metadata`
  - populate `original_prompt` during both implicit generation and explicit regeneration
  - store `original_prompt` as `%{"messages" => [...]}` using the final message list passed to the provider boundary
- `instructor_dashboard_recommendation_feedback`
  - no schema redesign required
  - continue storing `recommendation_instance_id`, `user_id`, `feedback_type`, and `feedback_text`
- Serialization shape
  - `original_prompt` persists the final prompt input as `%{"messages" => [%{"role" => "...", "content" => "..."}]}`
  - `response_metadata` persists execution metadata not already modeled in first-class columns:
    - `model`
    - `provider`
    - `registered_model_id`
    - `service_config_id`
    - `provider_usage` when returned
    - `fallback_reason` when applicable

## 7. Consistency & Transactions
- Recommendation-instance persistence remains the source of truth for generated recommendation rows.
- Additional text feedback insertion should succeed before Slack delivery is attempted, so the application never reports success to the instructor without durable feedback storage.
- Slack delivery should not run inside the same database transaction as feedback insertion.
- If feedback persistence succeeds and Slack delivery fails, the design should keep the persisted feedback row, log/capture the Slack failure as an operational issue, and still return success to the instructor. Slack delivery is best-effort for this phase, not part of the user-visible transaction contract.
- Sentiment uniqueness remains enforced by the existing unique index and domain upsert path.

## 8. Caching Strategy
- Existing recommendation cache refresh on regeneration remains unchanged.
- Sentiment submission and additional feedback submission do not require dashboard cache invalidation beyond updating the current viewer state returned to the LiveView.
- No new long-lived cache should be introduced for modal state or Slack payloads.

## 9. Performance & Scalability Posture
- Expected traffic is low and instructor-driven; no dedicated performance work is required.
- Persisting `original_prompt` increases row size for `recommendation_instances`, but recommendation generation frequency is already bounded by the existing 24-hour implicit reuse window plus explicit regenerate actions.
- Slack delivery is off the primary page-render path because it occurs after a user action and should remain lightweight webhook I/O.

## 10. Failure Modes & Resilience
- Duplicate thumbs submission:
  - mitigated by existing server-side uniqueness and local LiveView locking.
- Additional feedback validation failure:
  - modal stays open, validation error is rendered inline, no Slack call is attempted.
- Additional feedback persistence failure:
  - modal stays open, error flash/announcement is shown, no success state is applied.
- Slack delivery failure after persistence:
  - backend logs and captures the error; UI still shows success because the feedback was durably stored.
- Regeneration failure or timeout:
  - current recommendation remains visible, tile state unlocks, and error flash is shown.
- Missing or malformed recommendation ID:
  - adapter and LiveView reject the action before persistence.

## 11. Observability
- Preserve existing recommendation lifecycle telemetry for sentiment and regeneration.
- Add a dedicated event for qualitative feedback submission outcome with sanitized metadata only:
  - action: `:additional_feedback_submit`
  - outcome: `:accepted | :error`
  - optional error type, section scope type, and recommendation state
- Do not emit raw `feedback_text`, `prompt_snapshot`, or `original_prompt` in telemetry.
- Slack delivery failures should be logged and captured through existing error-reporting posture.

## 12. Security & Privacy
- Authorization remains section-instructor scoped through `OracleContext` and `Recommendations`.
- `prompt_snapshot` remains sanitized and excludes direct student identity data.
- `original_prompt` may include rendered prompt text derived from sanitized datasets; it must not reintroduce student PII beyond what the builder intentionally excludes.
- Free-text instructor feedback may contain sensitive commentary; it must not be written to telemetry or warning/error logs.
- Slack payload formatting should include only the minimum instructor and section context necessary for admin review.

## 13. Testing Strategy
- ExUnit domain tests:
  - extend recommendation persistence tests to assert `original_prompt` is required/populated as designed.
  - add tests for qualitative feedback persistence and Slack payload orchestration.
  - add tests for recommendation prompt persistence shape at generation time.
- LiveView tests:
  - thumbs submission swaps controls to `Additional feedback`
  - modal open, cancel, and submit flows
  - focus return and accessible labeling expectations
  - regeneration success and failure preserving prior recommendation copy
- Integration boundary tests:
  - adapter tests for `submit_additional_feedback`
  - Slack helper tests using the existing `Oli.Slack` mock pattern

## 14. Backwards Compatibility
- Existing recommendation rows without `original_prompt` must remain readable; the schema default should allow historical rows to normalize cleanly.
- Existing thumbs/regeneration behavior should continue to work while the new modal and prompt persistence are added incrementally.
- No external API contract changes are required outside the summary recommendation adapter used by the dashboard surface.

## 15. Risks & Mitigations
- `original_prompt` storage shape diverges from the actual provider request:
  - mitigate by persisting `%{"messages" => [...]}` at the final request assembly boundary, not by reconstructing it downstream.
- Modal accessibility regressions:
  - mitigate with LiveView tests plus reuse of the existing modal primitives in `OliWeb.Components.Modal` / `OliWeb.Common.Modal`.
- Slack reliability ambiguity after feedback persistence:
  - mitigate by documenting the post-persistence failure posture in implementation and telemetry.
- Recommendation UI state drift across async events:
  - mitigate by keeping all summary-tile state transitions inside `IntelligentDashboardTab`, which already handles stale-event rejection.

## 16. Open Questions & Follow-ups
- None for this phase.

## 17. References
- `docs/exec-plans/current/epics/intelligent_dashboard/feedback_ui/informal.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/feedback_ui/prd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/feedback_ui/requirements.yml`
- `lib/oli/instructor_dashboard/recommendations.ex`
- `lib/oli/instructor_dashboard/recommendations/builder.ex`
- `lib/oli/instructor_dashboard/recommendations/prompt.ex`
- `lib/oli/instructor_dashboard/recommendations/recommendation_instance.ex`
- `lib/oli/instructor_dashboard/summary_recommendation_adapter.ex`
- `lib/oli/instructor_dashboard/summary_recommendation_adapter/recommendations.ex`
- `lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex`
- `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/summary_tile.ex`
- `lib/oli/slack.ex`

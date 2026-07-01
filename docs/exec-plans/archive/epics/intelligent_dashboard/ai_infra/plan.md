# Intelligent Dashboard AI Recommendation Infrastructure - Execution Plan

## Scope and Guardrails
This plan implements `MER-5305` using the requirements in [`prd.md`](./prd.md) and the design in [`fdd.md`](./fdd.md).

In scope:
- Dedicated GenAI feature config for recommendation routing via `:instructor_dashboard_recommendation`
- Recommendation persistence and feedback persistence foundations
- Recommendation generation service/oracle contract
- Implicit once-per-24-hour generation semantics per `section + scope`
- Explicit regeneration with cache refresh semantics
- Deterministic fallback behavior and observability

Out of scope:
- Summary tile UI implementation
- Instructor-facing additional-feedback modal workflow details
- Slack delivery for qualitative feedback
- AI email workflow work from `MER-5257`

## Clarifications and Default Assumptions
- Implicit recommendation generation is access-driven in v1, not background-precomputed.
- The UI should consume the latest persisted recommendation instance for a given `section + scope`.
- Recommendation generation should be built from normalized scoped dashboard inputs and should not introduce parallel ad hoc analytics queries.
- Thumbs sentiment (thumbs up/down) is in scope for the lifecycle contract; additional-text feedback is supported by the persistence shape but the full instructor-facing workflow remains downstream.
- Rapid scope navigation must not regress into unnecessary provider calls for pass-through scopes; this must be validated during implementation.

## Phase 1. Contract and Persistence Foundation
Goal:
- Establish the database, schema, and feature-config foundations so recommendation lifecycle work can be implemented without later data-model churn.

Tasks:
- Add the new GenAI feature enum value `:instructor_dashboard_recommendation` and update any admin/tooling surfaces that enumerate valid features.
- Seed a default global feature config for `:instructor_dashboard_recommendation`.
- Add the recommendation instance schema and migration for `instructor_dashboard_recommendation_instances`.
- Add the recommendation feedback schema and migration for `instructor_dashboard_recommendation_feedback`.
- Encode the intended indexes and uniqueness guarantees, especially latest-by-scope lookup and one thumbs sentiment per recommendation instance per user.
- Keep `recommendation_instance_id` as the canonical link from feedback to scope/section context.

Testing tasks:
- Add DataCase tests for the new schemas, constraints, and feature-config lookup behavior.
- Extend existing GenAI feature-config tests to cover the new enum/default path.
- Verify migrations apply cleanly and schema constraints behave as expected.

Definition of done:
- The repo can store recommendation instances and feedback rows with the intended normalized shape.
- `FeatureConfig.load_for(section_id, :instructor_dashboard_recommendation)` is supported by the data model and defaults.
- Constraint coverage exists for duplicate thumbs sentiment rejection.

Gate:
- Do not start recommendation generation/oracle work until persistence and feature-config lookup are stable and tested.

Parallelization notes:
- Migration/schema work and feature-config enum/tooling updates can be developed in parallel if file ownership stays separated.

## Phase 2. Recommendation Input Contract and Prompt Composition
Goal:
- Define the exact backend-facing input shape for recommendation generation and the prompt composition path that turns scoped dashboard data into an LLM request.

Tasks:
- Identify the minimal scoped oracle/projection inputs required for recommendation generation.
- Implement a recommendation input builder that consumes normalized dashboard context rather than raw student rows.
- Translate the prototype “descriptor + dataset” prompt idea into a production prompt composer with explicit versioning.
- Define the recommendation payload contract returned to downstream consumers, including minimal operational metadata only.
- Make the builder and prompt modules sanitize prompt snapshots so persisted/logged artifacts avoid raw PII.

Testing tasks:
- Unit test the input builder against representative scoped dashboard data.
- Unit test prompt composition, prompt versioning, and no-signal prompt behavior.
- Add sanitization tests to ensure prompt snapshots and telemetry-safe metadata exclude raw student identifiers.

Definition of done:
- Recommendation prompt composition is isolated in non-UI modules.
- The input contract is explicit enough that oracle/service code can call it without prompt-specific branching.
- Prompt snapshots and metadata are safe to persist/log within the agreed limits.

Gate:
- Do not wire LLM execution or oracle reads to production paths until the input contract and fallback contract are explicit and test-covered.

Parallelization notes:
- Prompt-composition implementation can proceed in parallel with observability event-shape drafting, as long as both use the same payload contract.

## Phase 3. Recommendation Service and Oracle Lifecycle
Goal:
- Implement the runtime behavior for implicit generation, regeneration, persisted reuse, and fallback handling.

Tasks:
- Add `Oli.InstructorDashboard.Recommendations` as the lifecycle service boundary.
- Implement `get_recommendation(..., mode: :implicit)` using persisted latest-instance lookup and 24-hour implicit reuse semantics.
- Add persisted in-flight recommendation rows with lease-based expiry so repeated requests for the same scope deduplicate instead of launching duplicate provider calls.
- Implement explicit regeneration that creates a new recommendation instance and makes it the latest visible instance for the current scope.
- Broadcast recommendation lifecycle updates by `section + scope` and subscribe active dashboard LiveViews so completed regenerations reconcile after scope changes, navigation away, or remount.
- Integrate with `Oli.GenAI.Execution.generate/5` via the new feature config.
- Add deterministic no-signal and provider-failure fallback payloads.
- Implement the new recommendation oracle and register it in instructor dashboard bindings/registry.
- Ensure recommendation generation occurs only after the required scoped inputs are available.
- Validate that transient scope changes do not easily produce avoidable provider calls before the final active scope stabilizes.
- If manual validation shows that prerequisite-oracle completion alone is not enough to suppress pass-through generations, add a short recommendation-launch debounce keyed by the latest active request/scope before invoking the provider.

Testing tasks:
- Add DataCase/integration tests for:
  - first implicit generation for a scope
  - implicit reuse within 24 hours
  - in-flight generation deduplication for repeated requests to the same scope
  - stale in-flight generation expiry and recovery to a fresh implicit generation
  - implicit regeneration after window expiry
  - explicit regeneration creating a newer instance
  - latest-instance selection for UI consumers
- Add LiveView coverage for regeneration that completes after the user changes dashboard scope or remounts the dashboard, ensuring the final recommendation is reconciled back into the active UI.
  - deterministic fallback on no-signal and provider failure
- Add oracle registration/contract tests for the new recommendation oracle.

Definition of done:
- Recommendation generation is available through a stable service/oracle contract.
- The service returns the latest persisted recommendation instance for the active scope.
- Implicit and explicit lifecycle behaviors match the story semantics.

Gate:
- Do not merge this phase without verified latest-instance semantics and fallback coverage.

Parallelization notes:
- Oracle registration and service implementation can be split if both agree on the final payload contract.

## Phase 4. Feedback Contract and Cache Coherence
Goal:
- Complete the backend side of recommendation feedback and regeneration freshness guarantees.

Tasks:
- Implement thumbs sentiment submission against recommendation instances.
- Keep the feedback boundary extensible for later additional-text feedback without forcing schema redesign now.
- Extend cache behavior as needed so explicit regeneration does not leave stale recommendation data in in-process or revisit cache paths.
- Update the active LiveView-facing state path to consume refreshed recommendation payloads immediately after regenerate.
- Ensure cache refresh/invalidation logic is scoped narrowly to recommendation identity and current scope.

Testing tasks:
- Add tests for duplicate thumbs sentiment idempotency.
- Add tests proving regenerate does not leave stale recommendation data in cache-backed reads.
- Add tests for cache-refresh failure handling where persistence succeeds but cache mutation fails.

Definition of done:
- Thumbs feedback is persisted and duplicate submission behavior is deterministic.
- Regeneration freshness is preserved across immediate re-read/navigation paths.
- Cache updates are limited to the recommendation oracle identity and current scope.

Gate:
- Do not consider AC-002/AC-004 complete until stale-data-after-regenerate scenarios are covered by automated tests.

Parallelization notes:
- Feedback persistence and cache invalidation work can proceed in parallel, but both must converge on the same recommendation instance identity rules.

## Phase 5. Observability, Privacy, and Final Verification
Goal:
- Ensure the feature is supportable, privacy-safe, and sufficiently validated for downstream UI consumers.

Tasks:
- Add recommendation lifecycle telemetry for request, completion, failure, rate-limit hit/miss, regeneration, feedback submission, and cache-refresh outcomes.
- Ensure telemetry/log payloads remain sanitized and avoid raw student PII.
- Review provider metadata persisted in `response_metadata` and keep only sanctioned fields.
- Reconcile docs if implementation details drift from the current PRD/FDD assumptions.

Testing tasks:
- Add telemetry-focused tests for lifecycle events and sanitized metadata.
- Add targeted privacy tests ensuring logs/telemetry/prompt snapshots do not include disallowed fields.
- Run targeted `mix test` coverage for the touched recommendation, dashboard, and GenAI modules.

Definition of done:
- Observability coverage exists for the main recommendation lifecycle paths.
- Privacy-sensitive data is excluded from telemetry/log payloads and prompt snapshots.
- The work item docs remain aligned with implementation decisions.

Gate:
- No final merge until telemetry and sanitization checks pass and the targeted test suite is green.

Parallelization notes:
- Observability and privacy-hardening tasks can run alongside final regression testing, but both depend on the final payload contract being stable.

## Phase Gate Summary
- Phase 1 gate: persistence model and feature-config routing are stable.
- Phase 2 gate: input contract and prompt composition are explicit and tested.
- Phase 3 gate: lifecycle generation behavior is correct for implicit, explicit, latest-instance, and fallback paths.
- Phase 4 gate: feedback and cache coherence prevent stale recommendation behavior.
- Phase 5 gate: telemetry, privacy, and targeted verification are complete.

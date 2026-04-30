# Intelligent Dashboard AI Recommendation Infrastructure - Functional Design Document

## 1. Executive Summary
This design adds AI recommendation generation to the existing Instructor Intelligent Dashboard data architecture as a first-class oracle-backed capability instead of a LiveView-local workflow. The recommendation path will consume scoped dashboard context, normalized snapshot-derived inputs, and GenAI service configuration through explicit contracts so `MER-5249` and `MER-5250` can integrate without inventing new backend seams later.

The design introduces three durable backend concerns. First, a recommendation service boundary will own prompt composition, provider invocation, deterministic fallback behavior, and recommendation response shaping. Second, persistence will track recommendation instances and instructor feedback in normalized tables keyed by section and scoped container so implicit daily generation and later feedback/regeneration workflows share the same source of truth. Third, dashboard cache coherence will be extended so explicit regeneration replaces stale recommendation entries in both in-process and revisit caches rather than relying on TTL expiry.

## 2. Requirements & Assumptions
- Functional requirements:
  - Implement recommendation generation as an instructor-dashboard oracle-compatible capability.
  - Support implicit recommendation requests with once-per-24-hour generation per `section + container`.
  - Support explicit regeneration that bypasses the implicit rate limit and refreshes dashboard cache state.
  - Persist thumbs sentiment (thumbs up/down) and additional textual feedback through a stable backend contract.
  - Return deterministic no-signal and failure payloads that remain UI-safe.
  - Preserve compatibility with the prototype prompt structure based on pluggable dataset descriptors.
- Non-functional requirements:
  - Use existing GenAI service configuration infrastructure rather than introducing recommendation-specific provider wiring.
  - Avoid raw student PII in logs, telemetry, and persisted prompt context snapshots.
  - Keep recommendation orchestration within dashboard boundaries so tiles and LiveView code remain queryless.
  - Emit telemetry for request lifecycle, latency, rate-limit decisions, feedback submission, and regeneration outcomes.
- Assumptions:
  - Recommendation generation remains section-scoped; project-context support is out of scope for this story.
  - `MER-5249` and `MER-5250` will consume a stable recommendation view model and recommendation instance id rather than raw provider output.
  - The current prototype prompt in `lib/oli_web/live/admin/intelligent_dashboard_live.ex` is a baseline for wording and output constraints, not a production integration shape.
  - Recommendation routing will use a dedicated GenAI feature config named `:instructor_dashboard_recommendation`.
  - Recommendation cache invalidation may require extending existing dashboard cache APIs because the current cache surface is write/lookup oriented.

## 3. Repository Context Summary
- What we know:
  - Shared dashboard runtime already exists in `lib/oli/dashboard/*` with oracle contracts, snapshot assembly, in-process cache, revisit cache, and LiveView orchestration.
  - Instructor-specific oracle registration is owned by `Oli.InstructorDashboard.OracleBindings` and `Oli.InstructorDashboard.OracleRegistry`.
  - Current concrete instructor oracles already provide scoped progress, grades, scope resources, proficiency, and student-support inputs.
  - `Oli.GenAI.FeatureConfig`, `Oli.GenAI`, and `Oli.GenAI.Execution` already provide stable service-config lookup and completion execution paths.
  - Default GenAI feature configs are seeded today for `:student_dialogue`; recommendation will introduce a new dedicated config instead of reusing existing values.
  - The current summary tile UI is still a placeholder, so this design can prioritize backend contracts without preserving an existing recommendation presentation surface.
- Unknowns to confirm:

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- `Oli.InstructorDashboard.Oracles.Recommendation`
  - New oracle implementation keyed as `:oracle_instructor_recommendation`.
  - Loads recommendation payloads for the active `section + scope`.
  - Delegates lifecycle behavior to a recommendation service instead of composing prompts inline.
- `Oli.InstructorDashboard.Recommendations`
  - New domain service boundary for recommendation operations.
  - Owns `get_recommendation/2`, `regenerate_recommendation/2`, and feedback submission functions.
  - Resolves GenAI feature config, prompt composition, deterministic fallbacks, and persistence.
- `Oli.InstructorDashboard.Recommendations.Builder`
  - Builds the sanitized prompt input contract from scoped dashboard data.
  - Adapts prototype “descriptor + dataset” ideas to production inputs sourced from oracle payloads and snapshot-friendly view models.
- `Oli.InstructorDashboard.Recommendations.Prompt`
  - Produces the final system/user messages and output constraints passed to `Oli.GenAI.Execution.generate/5`.
  - Encapsulates default prompt text so prompt changes do not leak into oracle or LiveView code.
- `Oli.InstructorDashboard.Recommendations.CacheRefresh`
  - Encapsulates recommendation-specific cache refresh and invalidation behavior for explicit regeneration.
  - Uses shared cache key construction rather than reimplementing key identity rules.
- `Oli.InstructorDashboard.Recommendations.RecommendationInstance`
  - New persisted schema for the current recommendation artifact and its generation metadata.
- `Oli.InstructorDashboard.Recommendations.RecommendationFeedback`
  - New persisted schema for recommendation feedback tied to a recommendation instance and instructor.
  - The schema should be shaped to support both sentiment (thumbs up/down) feedback and future additional-text feedback without redesign.

### 4.2 State & Data Flow
1. Live dashboard scope resolution continues to happen through existing Intelligent Dashboard runtime.
2. The dashboard dependency profile includes the recommendation oracle as an optional summary capability input.
3. When the recommendation oracle executes in implicit mode:
  - It resolves the active `section_id` and scoped `container_type/container_id`.
  - It asks `Oli.InstructorDashboard.Recommendations.get_recommendation(context, mode: :implicit)`.
  - If a recommendation generation is already in progress for that exact `section + scope` and its lease has not expired, the service returns the persisted in-flight instance instead of starting a duplicate generation.
  - If the latest in-flight instance for that `section + scope` has exceeded its lease window, the service marks it as `:expired` and is allowed to create a fresh generation attempt.
  - The service checks for the latest persisted recommendation instance for that scope.
  - In v1, implicit generation is access-driven rather than calendar-driven: the first eligible dashboard request after the 24-hour window triggers generation, and no background precompute job is introduced for unvisited scopes.
  - If an implicit generation happened within 24 hours, the service returns that persisted instance without calling GenAI.
  - Otherwise it builds sanitized prompt input, invokes GenAI, persists a new recommendation instance, and returns the normalized payload.
4. When explicit regeneration is requested:
  - The service bypasses the implicit daily gate.
  - A new recommendation instance is generated and persisted.
  - Recommendation-specific cache entries are replaced or invalidated so subsequent dashboard renders do not surface stale recommendation content.
5. Feedback submission is handled against a persisted recommendation instance id:
  - Thumbs feedback creates a feedback record and enforces one sentiment (thumbs up/down) decision per user per recommendation instance.
  - The persistence boundary is designed so `MER-5250` can later attach additional-text feedback to the same recommendation instance without redefining identifiers or storage shape.
6. All UI-facing responses return a normalized recommendation contract containing instance id, message text, state, generation metadata, and any UI-safe fallback markers.

### 4.3 Lifecycle & Ownership
- Oracle ownership:
  - The recommendation oracle remains responsible only for scoped oracle execution and contract conformity.
  - It does not own persistence policy details, feature config lookup, or cache refresh mechanics.
- Service ownership:
  - Recommendation lifecycle semantics belong in `Oli.InstructorDashboard.Recommendations`.
  - This includes implicit gating, explicit regeneration, prompt invocation, persistence, and feedback operations.
- Cache ownership:
  - General cache behavior stays in `Oli.Dashboard.Cache`, `InProcessStore`, and `RevisitCache`.
  - Recommendation-specific invalidation rules are implemented as an extension to the shared cache surface, not as ad hoc mutation in LiveView code.
- UI ownership:
  - `MER-5249` and `MER-5250` consume the returned recommendation contract and instance id.
  - No prompt-building, provider invocation, or persistence logic belongs in the UI layer.

### 4.4 Alternatives Considered
- Reuse `:instructor_dashboard` feature config directly for recommendations.
  - Rejected because `MER-5305` explicitly asks for a new top-level recommendation feature config, and `MER-5257` independently asks for a dedicated instructor-email feature config. Reusing `:instructor_dashboard` would blur those capability boundaries before any production consumer exists.
- Store only one mutable “last recommendation per scope” row.
  - Rejected because feedback and regeneration need stable recommendation instance identity and historical association.
- Handle regeneration by writing new persisted data and waiting for cache TTL to expire.
  - Rejected because the ticket explicitly requires stale-data prevention on re-navigation.
- Build recommendation prompts directly from raw student rows.
  - Rejected because this increases PII exposure and bypasses the normalized dashboard data backbone described in the Intelligent Dashboard EDD.

## 5. Interfaces
- Recommendation service contract:
  - `get_recommendation(%OracleContext{}, opts)` where `opts[:mode]` is `:implicit | :explicit_regen`.
  - Returns `{:ok, recommendation_payload}` or `{:error, reason}`.
- Feedback service contracts:
- `submit_sentiment(recommendation_instance_id, user_id, sentiment)` where `sentiment` means thumbs up/down
  - The feedback boundary should be extensible to support a future `submit_additional_feedback(recommendation_instance_id, user_id, feedback_text)` contract without schema redesign.
- Prompt/building contracts:
  - `build_input_contract(%OracleContext{}, keyword())`
  - `build_messages(input_contract, keyword())`
- Oracle payload contract returned to dashboard/UI consumers:
  - `id`
  - `section_id`
  - `container_type`
  - `container_id`
  - `state` where initial values are expected to include `:ready`, `:no_signal`, and `:fallback`
  - in-flight state support adds `:generating` and lease-expiration support adds `:expired`
  - `message`
  - `generated_at`
  - `generation_mode` as `:implicit` or `:explicit_regen`
  - `feedback_summary` with UI-safe flags such as whether the current instructor has already submitted sentiment (thumbs up/down)
  - `metadata` limited to sanctioned operational fields such as `fallback_reason`, provider usage summaries, and `prompt_version`
- Cache refresh contract:
  - Extend shared cache facade with recommendation-safe invalidation helpers keyed by oracle identity and scope, or equivalent targeted overwrite semantics.

## 6. Data Model & Storage
- Add `instructor_dashboard_recommendation_instances`:
  - `id`
  - `section_id`
  - `container_type`
  - `container_id`
  - `generation_mode`
  - `state`
  - `message`
  - `prompt_version`
  - `prompt_snapshot` as sanitized prompt input or prompt text snapshot without raw student identifiers
  - `response_metadata` as sanitized provider metadata
  - `generated_by_user_id` nullable for implicit generation and set for explicit regeneration
  - `inserted_at`, `updated_at`
- Add `instructor_dashboard_recommendation_feedback`:
  - `id`
  - `recommendation_instance_id`
  - `user_id`
  - `feedback_type` as `:thumbs_up | :thumbs_down | :additional_text`
  - `feedback_text` nullable
  - `inserted_at`, `updated_at`
- Index strategy:
  - Recommendation instances indexed by `section_id + container_type + container_id + inserted_at desc`.
  - Feedback indexed by `recommendation_instance_id`.
  - Unique constraint for one thumbs sentiment (thumbs up/down) per `recommendation_instance_id + user_id` across thumbs-only feedback types.
- Storage notes:
  - The latest recommendation instance acts as the persisted rate-limit anchor for implicit requests, avoiding a second rate-limit-only table unless performance evidence later justifies separation.
  - In-flight deduplication uses a persisted `:generating` state keyed by `section + scope`, with `inserted_at` acting as the generation lease start time.
  - Expired in-flight rows transition to `:expired` so a stale abandoned generation does not block future recommendation requests forever.
  - Persisted prompt snapshots must remain sanitized and bounded in size.
  - `instructor_dashboard_recommendation_feedback` should treat `recommendation_instance_id` as the canonical link to section and scope context, avoiding redundant `section_id` or `resource_id` columns unless a concrete reporting need later justifies denormalization.

## 7. Consistency & Transactions
- Recommendation generation write path:
  - For provider-backed generation, persist a `:generating` recommendation instance before invoking the LLM so repeated requests for the same scope can deduplicate against the same in-flight row.
  - When generation completes, update that same row to a terminal state such as `:ready`, `:fallback`, or `:expired`.
  - Recommendation instance persistence and any accompanying feedback-summary initialization should occur in a single transaction when terminal data is finalized.
- LiveView/UI synchronization:
  - The persisted recommendation instance remains the source of truth for generation state and latest visible content.
  - Live dashboard sessions subscribe to section-and-scope recommendation updates via PubSub so a recommendation that finishes while a user navigates away, changes scope, or remounts the LiveView is pushed back into the active UI without requiring a manual refresh.
  - PubSub mirrors persisted state transitions for active sessions; it does not replace database-backed lookup on initial load or revisit.
- Feedback write path:
  - Thumbs submission should be transactional with uniqueness enforcement so duplicate clicks resolve idempotently.
  - Additional text feedback is append-only and should not mutate the original recommendation instance content.
- Regeneration path:
  - Persist the new recommendation instance first, then perform cache refresh/invalidation.
  - If cache refresh fails after persistence succeeds, the service returns success plus emits a cache-refresh failure event; consumers can still recover by cold-loading from persistence.

## 8. Caching Strategy
- Recommendation remains part of the oracle/caching model rather than a persistence-only bypass.
- Implicit requests:
  - V1 uses access-driven implicit generation so the system does not spend provider cost on section/scope combinations that no instructor actually visits.
  - Prefer existing cached oracle result when present and fresh according to normal dashboard cache identity.
  - On cache miss, the oracle service may still avoid GenAI generation by reusing the most recent persisted recommendation instance if it is within the 24-hour implicit window.
- Explicit regeneration:
  - Must actively replace or invalidate `:oracle_instructor_recommendation` cache entries for the active scope in both cache tiers.
  - The shared cache layer likely needs a targeted delete/invalidate API because current cache APIs are lookup/write only.
- Revisit behavior:
  - Revisit cache should store the normalized recommendation oracle payload, not provider-native data.
- Cache keys:
  - Continue to use shared `Oli.Dashboard.Cache.Key` identity semantics keyed by context, scope, oracle key, oracle version, and data version.

## 9. Performance & Scalability Posture
- No special load testing is required for this story, but the design should avoid unnecessary provider calls.
- The primary cost-control mechanism is implicit reuse of the latest persisted recommendation instance for 24 hours per `section + container`.
- Prompt-building should use aggregated/scoped dashboard inputs already available through oracles instead of issuing new wide analytical queries.
- Persisted recommendation lookup must be index-backed and bounded to “latest by scope” reads.
- Explicit regeneration remains instructor-driven and therefore low-frequency compared with passive dashboard loads.
- Rapid scope navigation should not trigger unnecessary LLM requests for transient scope selections. For example, if an instructor starts on `Entire Course` and clicks the right-arrow in the list navigator five times in quick succession, the system should avoid turning the four intermediate pass-through scopes into four unnecessary recommendation-generation calls before the instructor settles on the fifth scope. This matters for three reasons: avoidable provider cost, avoidable consumption of limited request/concurrency capacity, and the risk of delaying the recommendation for the final scope the instructor actually intends to inspect. Recommendation generation is expected to occur only after the required scoped oracle inputs are available, which will likely suppress many pass-through selections naturally. However, this behavior depends on the final implementation details of recommendation prerequisites and runtime orchestration, and must be validated during implementation to ensure transient scope changes do not produce avoidable provider calls or delay the final in-focus recommendation.
- Implementation note after manual validation: relying only on upstream-oracle completion as a natural throttle was not sufficient in all cases. In local testing after clearing dashboard cache state and navigating rapidly across multiple scopes, several intermediate scopes still completed their prerequisite oracle work quickly enough to launch recommendation generation in the background. V1 therefore adds an explicit short debounce before recommendation generation begins so transient pass-through scopes are less likely to produce avoidable provider calls, while still persisting any recommendation that has already completed once the provider cost has been paid.

## 10. Failure Modes & Resilience
- No-signal course state:
  - Return a deterministic beginning-course or no-signal recommendation payload, not an error.
- GenAI provider failure:
  - Return a deterministic fallback payload suitable for display and persist it as a recommendation instance when appropriate so UI behavior is stable.
- Missing feature config:
  - Treat as a controlled backend failure with a deterministic fallback response and telemetry indicating configuration absence.
- Cache invalidation failure after successful regeneration:
  - Emit telemetry and rely on persisted latest recommendation as recovery path; do not roll back the new recommendation instance.
- Duplicate thumbs submission:
  - Resolve idempotently and return the already-recorded sentiment (thumbs up/down) state instead of raising a user-visible failure.

## 11. Observability
- Telemetry events should cover:
  - recommendation request started/completed/failed
  - implicit rate-limit hit vs miss
  - explicit regeneration started/completed/failed
  - feedback submitted and feedback rejected as duplicate
  - cache refresh succeeded/failed after regeneration
- Suggested metadata:
  - `section_id`
  - `container_type`
  - `container_id`
  - `generation_mode`
  - `outcome`
  - `fallback_reason`
  - `error_category`
  - `latency_ms`
  - `service_config_id`
  - token/cost/provider usage when available and already exposed by GenAI plumbing
- Logging:
  - Logs must not include raw prompt bodies, student names, emails, or raw input datasets.
  - Prefer ids, counts, bucket labels, and sanitized outcome metadata.
- AppSignal:
  - Use structured counters/timers consistent with repo observability defaults in `harness.yml`.

UI v1 does not require a confidence or quality score. The contract should expose only minimal operational metadata: `generation_mode` to distinguish implicit loads from explicit regenerations, `fallback_reason` to classify deterministic non-standard outcomes such as no-signal or provider failure, and `prompt_version` to preserve traceability as recommendation prompts evolve over time.

This story establishes a recommendation feedback persistence model and service boundary that can support both sentiment (thumbs up/down) and future additional-text feedback, while limiting in-scope implementation to the infrastructure needed by current recommendation lifecycle contracts. The instructor-facing additional-feedback workflow and any Slack delivery belong to `MER-5250` or to a later integration step built on top of these persisted records.

## 12. Security & Privacy
- Recommendation operations remain instructor-dashboard-only and must honor section-scoped authorization.
- Prompt inputs must be built from aggregated/scoped oracle outputs and sanitized context; raw student rows should not be logged or persisted in prompt snapshots.
- Free-text feedback should be stored as instructor-authored content and excluded from routine logs.
- Recommendation telemetry must use sanctioned metadata only.
- Persisted recommendation artifacts should avoid embedding unnecessary PII so later analytics or support tooling does not broaden exposure.

## 13. Testing Strategy
- ExUnit unit tests:
  - prompt/input contract shaping
  - implicit 24-hour reuse decisions
  - deterministic fallback mapping
  - duplicate thumbs idempotency
- Integration-style DataCase tests:
  - recommendation service end-to-end with persisted instance reuse
  - explicit regeneration creating a new instance and refreshing cache state
  - feedback persistence against recommendation instance ids
- Oracle contract tests:
  - new recommendation oracle registration and dependency profile coverage
  - payload compatibility with snapshot/projection derivation
- GenAI config tests:
  - dedicated feature config lookup through `:instructor_dashboard_recommendation`
  - seed/default config expectations
- Security/privacy tests:
  - telemetry/log sanitization for recommendation events

## 14. Backwards Compatibility
- Existing dashboard infrastructure remains the same for non-recommendation consumers.
- Existing `:student_dialogue` feature config support remains intact; recommendation config is additive under `:instructor_dashboard_recommendation`.
- The admin prototype page remains a reference implementation and is not part of the production contract.
- UI stories can integrate incrementally because the returned recommendation contract is additive and isolated.

## 15. Risks & Mitigations
- Cache API extension may touch shared dashboard infrastructure.
  - Mitigation: keep invalidation narrowly scoped to oracle identity and reuse existing cache key semantics.
- Recommendation prompt shape may drift from the prototype or from future configurable prompt work.
  - Mitigation: isolate prompt composition in dedicated modules with explicit prompt versioning.
- Persisting prompt snapshots may accidentally capture more context than intended.
  - Mitigation: define a sanitized prompt-input schema and test redaction behavior.
- Feedback requirements may expand to external routing such as Slack.
  - Mitigation: keep feedback persistence local and treat external fan-out as a follow-up integration behind the same service boundary.

## 16. Open Questions & Follow-ups
- Follow-up implementation story may be needed if shared dashboard caches require a more general invalidation API than this feature should own directly.

## 17. References
- `docs/exec-plans/current/epics/intelligent_dashboard/ai_infra/prd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/ai_infra/requirements.yml`
- `docs/exec-plans/current/epics/intelligent_dashboard/summary_tile/prd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/feedback_ui/prd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/overview.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/edd.md`
- `lib/oli_web/live/admin/intelligent_dashboard_live.ex`
- `lib/oli/dashboard/*`
- `lib/oli/instructor_dashboard/*`

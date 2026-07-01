# Adaptive Context - Functional Design Document

## 1. Executive Summary
This design adds adaptive-page-specific DOT context by introducing a backend context builder plus a conditional student-dialogue tool that is only exposed for adaptive pages rendered inside Torus navigation. The smallest adequate design is to keep the core context assembly in a non-UI module, reuse the existing `StudentFunctions` function-calling path, and add a thin browser-to-LiveView bridge so the dialogue session always knows the learner's current adaptive activity-attempt GUID. The builder resolves the current activity attempt to the enclosing page attempt, uses adaptive page state plus ordered activity attempts to construct visited and unvisited screen context, and returns markdown for DOT to consume. No new tables, OTP processes, or feature flags are needed.

## 2. Requirements & Assumptions
- Functional requirements:
  - `FR-001` / `AC-001`: expose an adaptive-only DOT tool in supported Torus adaptive delivery contexts.
  - `FR-002` / `AC-003`: accept the current adaptive activity-attempt GUID and resolve it to the learner's page attempt.
  - `FR-003`: use the resolved page attempt as the root of adaptive-context assembly.
  - `FR-004` / `AC-004`: return visited-screen narrative in actual visit order.
  - `FR-005` / `AC-005`: include per-screen content plus learner response state.
  - `FR-006` / `AC-006`: identify the current screen and keep unvisited content outside the visited narrative.
  - `FR-007` / `AC-007` / `AC-010`: prevent unseen-screen leakage and preserve existing DOT answer-safety posture.
  - `FR-008` / `AC-008`: fail safely on missing or malformed attempt data.
  - `FR-009` / `AC-009`: emit telemetry without raw student content.
- Non-functional requirements:
  - Context building must stay request-scoped and avoid obvious N+1 lookups.
  - Security checks must hold to learner, section, and adaptive page boundaries.
  - Existing DOT visibility and chat UX must remain unchanged.
- Assumptions:
  - Adaptive delivery already produces the current screen activity-attempt GUID in browser state and can surface it to LiveView without changing persistence contracts.
  - Adaptive page extrinsic state (`session.visits.*` and `session.visitTimestamps.*`) is authoritative for visited-vs-unvisited screen state within a page attempt.
  - Activity revisions contain enough screen content and titles to build learner-safe markdown without a new materialized summary store.
  - Adaptive pages reference unique screen activities within a given page sequence; if reused activity resources appear multiple times in a sequence, sequence-entry labeling logic will need follow-up refinement.

## 3. Repository Context Summary
- What we know:
  - `OliWeb.Dialogue.WindowLive` creates the student dialogue session and currently passes a static function list from `OliWeb.Dialogue.StudentFunctions`.
  - `Oli.GenAI.Completions.Function.call/3` executes named module functions from a list of function specs, so conditional adaptive behavior should fit the existing function-call path rather than adding a new execution mechanism.
  - `OliWeb.LiveSessionPlugs.InitPage` already identifies adaptive-with-chrome delivery and passes `resourceAttemptGuid` plus `activityGuidMapping` into the adaptive delivery app.
  - The adaptive client tracks current screen attempt state in Redux selectors such as `selectCurrentActivityTreeAttemptState`, and visit state in extrinsic session keys such as `session.visits.*` and `session.visitTimestamps.*`.
  - `Oli.Delivery.Attempts.Core` already exposes the main lookup primitives needed for this feature: `get_activity_attempt_by/1`, `get_resource_attempt_by/1`, `get_section_by_activity_attempt_guid/1`, and adaptive attempt-state helpers.
  - `Oli.Conversation.Triggers` already augments DOT prompts from activity-attempt data, which is a useful precedent for keeping content assembly in backend modules rather than LiveView templates.
- Unknowns to confirm:
  - Whether current adaptive delivery emits enough screen metadata client-side to include a user-friendly sequence label in the runtime update message, or whether the builder should derive labels entirely from server-side page content.
  - Whether revisits should be represented as repeated narrative entries or as a single visited entry with revisit count.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- `Oli.Conversation.AdaptivePageContextBuilder`:
  - New backend module under `lib/oli/conversation/`.
  - Public contract: `build(activity_attempt_guid, section_id, user_id)`.
  - Responsibilities:
    - validate that the activity attempt belongs to the requesting learner and section;
    - resolve activity attempt -> page attempt -> adaptive page revision;
    - extract adaptive sequence metadata from page content;
    - read page extrinsic state for visited/unvisited screen data;
    - collect ordered activity attempts and latest part responses;
    - render markdown for DOT.
- `OliWeb.Dialogue.StudentFunctions`:
  - Replace `functions/0` with a small session-aware builder such as `functions_for_session(session_context)`.
  - Append one adaptive-only function spec when the current page is `:adaptive_with_chrome`.
  - Keep the function implementation thin: validate required arguments, call `AdaptivePageContextBuilder`, and return markdown.
- `OliWeb.Dialogue.WindowLive`:
  - Accept adaptive delivery context in session assigns.
  - Store `current_activity_attempt_guid` in socket assigns.
  - Handle a new client event such as `"adaptive_screen_changed"` and enqueue a hidden system message that updates the dialogue session with the latest current activity-attempt GUID.
  - Keep DOT hidden exactly as today when assistant enablement or page-placement prerequisites are not met.
- Adaptive delivery bridge:
  - Add a small client-side bridge in the adaptive delivery React tree that watches the current activity attempt from Redux and emits a browser event when it changes.
  - Add a Phoenix hook on the dialogue root that listens for that browser event and `pushEvent`s the current attempt GUID into `WindowLive`.

### 4.2 State & Data Flow
1. Adaptive page loads in Torus navigation and mounts `WindowLive`.
2. `WindowLive` builds a dialogue configuration using `StudentFunctions.functions_for_session/1`.
3. Because the page is adaptive-with-chrome, the configuration includes a new function spec:
   - name: `adaptive_page_context`
   - required args: `activity_attempt_guid`, `current_user_id`, `section_id`
   - description includes the guidance from the ticket: current screen, visited screens, unvisited screens, and lesson content retrieval.
4. The adaptive delivery React bridge detects the current screen's `attemptGuid` from Redux and dispatches a browser event.
5. A dialogue hook forwards the GUID to `WindowLive`, which:
   - updates `current_activity_attempt_guid`;
   - injects a non-rendered system message like: `Adaptive runtime update: current activity_attempt_guid=<guid>.`
6. When the model needs adaptive lesson context, it calls `adaptive_page_context`.
7. `StudentFunctions.adaptive_page_context/1` delegates to `AdaptivePageContextBuilder.build/3`.
8. The builder returns markdown containing:
   - current screen summary;
   - visited screens in actual visit order;
   - concise not-yet-visited screen list by label only;
   - learner response state for visited screens only.

### 4.3 Lifecycle & Ownership
- Current-screen attempt ownership lives in the adaptive delivery client and changes as the learner navigates.
- Authoritative learner, section, attempt, and revision ownership lives in the backend.
- Dialogue-session awareness of the current screen is eventually consistent through the browser-event bridge; each change replaces the prior current GUID for future tool use.
- The builder is pure request-scoped work and introduces no new background process or persisted summary artifact.

### 4.4 Alternatives Considered
- Add a new dialogue execution abstraction that passes LiveView socket context into function calls:
  - Rejected because it changes the shared GenAI function-execution contract for one work item.
- Build adaptive context directly in `WindowLive`:
  - Rejected because it mixes delivery lookup, authorization, and markdown rendering into a UI module.
- Use only activity attempts to infer visited and unvisited screens:
  - Rejected because activity attempts can reconstruct visits but not the full unvisited set without consulting adaptive page structure.
- Use only extrinsic `session.visits.*` state:
  - Rejected because it identifies visited screens but does not contain enough learner-answer detail for the markdown narrative.

## 5. Interfaces
- `OliWeb.Dialogue.StudentFunctions.functions_for_session/1`
  - Input: `%{adaptive?: boolean(), section_id: integer(), current_user_id: integer()}`
  - Output: list of existing function specs plus adaptive spec when eligible.
- `OliWeb.Dialogue.StudentFunctions.adaptive_page_context/1`
  - Input:
    - `activity_attempt_guid` string
    - `current_user_id` integer
    - `section_id` integer
  - Output: markdown string
- `Oli.Conversation.AdaptivePageContextBuilder.build/3`
  - Input: `activity_attempt_guid`, `section_id`, `user_id`
  - Output: `{:ok, markdown}` or `{:error, reason}`
- Client bridge event
  - Browser event name: `oli:adaptive-screen-changed`
  - Payload: `%{activityAttemptGuid: string}`
- LiveView event
  - Event name: `"adaptive_screen_changed"`
  - Payload: `%{"activity_attempt_guid" => guid}`

## 6. Data Model & Storage
- No schema or migration changes.
- Inputs reused from existing storage:
  - `activity_attempts` and `part_attempts` for screen-level response state;
  - `resource_attempts` for page-attempt identity;
  - page revision content for adaptive sequence structure;
  - extrinsic adaptive state for `session.visits.*` and `session.visitTimestamps.*`.
- Builder-owned transient data:
  - sequence catalog: `%{sequence_id, sequence_name, activity_resource_id}`
  - visited timeline: ordered list of activity attempts with resolved labels
  - visited set and unvisited set for markdown sections
- No durable cache is introduced.

## 7. Consistency & Transactions
- The builder performs read-only lookups only; no explicit transaction is required.
- Authorization check must happen before markdown assembly:
  - activity attempt -> page attempt -> resource access -> `section_id` and `user_id` match.
- The browser-to-LiveView update is best-effort:
  - if the current GUID update is delayed, DOT may use a slightly older current screen until the next runtime update;
  - no learner state is mutated by this feature, so this is acceptable.
- Tool execution should fail closed:
  - mismatched section/user/adaptive-page context returns a safe error result, not partial data.

## 8. Caching Strategy
- No cross-request or cross-node cache.
- Within one builder invocation, use in-memory maps for:
  - sequence-entry lookup by `activity_resource_id`;
  - latest part-attempt collapse per activity attempt;
  - visited membership tests.
- This is sufficient because tool execution is request-scoped and page-sized.

## 9. Performance & Scalability Posture
- Query posture:
  - one activity-attempt lookup for the current GUID;
  - one page-attempt lookup with revision and resource-access preload;
  - one ordered fetch for activity attempts in the page attempt with revision and part-attempt preload.
- Avoid per-screen revision fetches inside render loops; preload revisions up front.
- Markdown rendering is linear in number of visited attempts plus sequence entries on the page.
- Telemetry should track:
  - tool invocation latency;
  - builder latency;
  - build failures by reason.

## 10. Failure Modes & Resilience
- Invalid or unknown activity attempt GUID:
  - return a safe error string; do not expose internal identifiers.
- Activity attempt belongs to another learner or section:
  - reject the request and emit failure telemetry.
- Page attempt is not adaptive or not rendered in Torus navigation:
  - adaptive function is not exposed; if called anyway, fail closed.
- Missing extrinsic visit state:
  - still build current-screen and visited-screen context from ordered activity attempts; emit degraded-mode telemetry.
- Partial missing part-attempt data:
  - omit response details for that screen and keep the rest of the narrative.

## 11. Observability
- New telemetry events:
  - `[:oli, :genai, :adaptive_context, :tool_exposed]`
  - `[:oli, :genai, :adaptive_context, :tool_called]`
  - `[:oli, :genai, :adaptive_context, :build_succeeded]`
  - `[:oli, :genai, :adaptive_context, :build_failed]`
- Measurements:
  - `duration_ms`
  - visited-screen count
  - unvisited-screen count
- Metadata:
  - `section_id`
  - `resource_attempt_id`
  - `page_revision_id`
  - failure reason enum
- Exclusions:
  - no raw learner answers
  - no rendered screen content
  - no free-form user prompts

## 12. Security & Privacy
- Access control:
  - the adaptive tool is only advertised for the current learner's adaptive page session;
  - builder enforces learner and section match before content assembly.
- Data minimization:
  - unvisited screens are represented by label only, not full content.
  - telemetry never includes raw answers or content fragments.
- Boundary discipline:
  - all database lookups stay inside existing delivery attempt and revision boundaries;
  - no cross-section or cross-tenant search path is introduced.

## 13. Testing Strategy
- ExUnit:
  - builder unit tests for `AC-003`, `AC-004`, `AC-005`, `AC-006`, `AC-007`, `AC-008`, and `AC-009`;
  - access-control tests for mismatched learner/section rejection;
  - markdown formatting tests for current, visited, and unvisited sections.
- LiveView:
  - `WindowLive` tests for `AC-001` and `AC-002`, covering adaptive-only tool exposure and hidden state updates on `"adaptive_screen_changed"`.
- Jest:
  - adaptive delivery bridge test confirming current attempt GUID browser events fire on screen changes and do not fire in review/history-only transitions.
- Integration:
  - targeted delivery test proving a screen change updates the dialogue session before a subsequent user message.
- Manual:
  - verify DOT does not reference unseen screens after branching navigation (`AC-010`);
  - verify DOT is hidden when AI is disabled or adaptive content is outside Torus navigation (`AC-002`).

## 14. Backwards Compatibility
- Existing DOT behavior on non-adaptive pages remains unchanged.
- Existing student functions remain available and unchanged in shape.
- No feature flag is introduced; rollout relies on existing assistant enablement and page-placement gating.
- If the client bridge fails, the fallback impact is stale current-screen context, not broken chat initialization.

## 15. Risks & Mitigations
- Stale current-screen GUID in the dialogue session:
  - mitigate with a lightweight event bridge that updates on every adaptive screen change and initial mount.
- Divergence between adaptive runtime state and builder assumptions:
  - mitigate by deriving visited/unvisited from persisted page state plus attempt data, not from browser-only ephemeral state.
- Overly large markdown payloads on long adaptive lessons:
  - mitigate by formatting concise per-screen summaries and reserving full-screen dumps for visited screens only.
- Revisit representation ambiguity:
  - mitigate by preserving ordered attempt history in the builder and documenting revisit behavior explicitly in tests.

## 16. Open Questions & Follow-ups
- Should revisit output show repeated screen entries or collapse them into one screen with a visit count?
- Do we want an explicit current-screen label in the adaptive client event payload, or should the builder remain fully responsible for name resolution?
- If prompt-token pressure becomes noticeable, should a later slice add truncation rules or screen-summary compaction?

## 17. References
- `docs/exec-plans/current/epics/adaptive_page_improvements/adaptive_context/prd.md`
- `docs/design-docs/genai.md`
- `lib/oli_web/live/dialogue/window_live.ex`
- `lib/oli_web/live/dialogue/student_functions.ex`
- `lib/oli/gen_ai/completions/function.ex`
- `lib/oli_web/live_session_plugs/init_page.ex`
- `lib/oli/delivery/attempts/core.ex`
- `assets/src/apps/delivery/layouts/deck/DeckLayoutView.tsx`
- `assets/src/apps/delivery/store/features/adaptivity/actions/triggerCheck.ts`
- `assets/src/apps/delivery/layouts/deck/components/HistoryNavigation.tsx`

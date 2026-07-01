# Customize Student Support Parameters - Functional Design Document

## 1. Executive Summary
This feature adds section-scoped customization for the Student Support tile parameters in the Instructor Intelligent Dashboard. The design keeps the existing dashboard runtime shape: Elixir owns persistence, validation, authorization, and projection rules; LiveView owns the tile workflow, draft state, and save/reload sequence; a narrow `phx-hook` owns only the client-local SVG drag interaction for the threshold matrix. Saved settings become the single source of truth for a section and are shared by all instructors for that section. The Student Support projector is extended to accept validated parameter settings so donut/list outputs are rederived from persisted thresholds and inactivity days after every successful save. This satisfies `AC-001`, `AC-002`, `AC-003`, `AC-004`, `AC-005`, `AC-006`, and `AC-007` without changing student-facing delivery behavior, introducing per-instructor preferences, or adding a React bridge for this LiveView-owned tile.

## 2. Requirements & Assumptions
- Functional requirements:
  - `FR-001`: the Student Support tile exposes an `Edit parameters` action that opens the customization modal. Covered by `AC-001`.
  - `FR-003`: numeric threshold controls enforce 0-100 bounds and non-overlap rules in real time. Covered by `AC-002`.
  - `FR-005`: saving persists settings at section scope, with defaults used until a section customization exists. Covered by `AC-003` and `AC-004`.
  - `FR-006`: successful save immediately reloads/reprojects Student Support data using the persisted settings. Covered by `AC-005`.
  - `FR-007`: cancel, outside click, and Esc discard unsaved edits. Covered by `AC-006`.
  - `FR-009`: save failure preserves previously active settings and shows actionable error feedback. Covered by `AC-007`.
- Non-functional requirements:
  - WCAG 2.1 AA keyboard and focus behavior for the modal, numeric controls, and draggable matrix.
  - Section-level persistence writes are atomic and safe for repeated save attempts.
  - Minimal AppSignal/telemetry counters for save success, save failure, and reprojection/reload failure.
  - No explicit load/performance benchmark is required for this slice.
- Assumptions:
  - Existing Student Support projection inputs from `ProgressProficiency` and `StudentInfo` remain stable.
  - Inactivity options are fixed to 7, 14, 30, and 90 days for this slice.
  - Comparator logic is fixed in backend validation/projection code and is not editable in the UI.
  - The Figma/ChatGPT prototype interaction guidance is sufficient for planning, but detailed visual token mapping should still use the repo UI workflow before implementation of the matrix editor.
  - Last successful save wins for concurrent instructors unless a future product decision requests conflict warnings.

## 3. Repository Context Summary
- What we know:
  - The Student Support tile is currently a LiveComponent at `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/student_support_tile.ex`.
  - The Engagement section composes `ProgressTile` and `StudentSupportTile` in `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tile_groups/engagement_section.ex`.
  - Dashboard orchestration, scope selection, URL tile params, cache/coordinator integration, and projection assignment live in `lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex`.
  - The Student Support projection entrypoint is `Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport`, and bucket logic is concentrated in `Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport.Projector`.
  - `Projector.build/3` already accepts `:inactivity_days` and `:rules` options, but persisted parameter retrieval and validation do not yet exist.
  - Existing `instructor_dashboard_states` persistence is keyed by `enrollment_id`, making it instructor/enrollment-scoped and unsuitable for this section-shared configuration.
  - Dashboard caches currently store oracle payloads by context, scope, oracle identity, and fixed metadata; Student Support parameter versions are not part of those keys because settings affect projection output, not oracle payload identity.
  - Frontend React components are mounted into Phoenix/LiveView surfaces through existing component/hook patterns in `assets/src/apps/Components.tsx` and `assets/src/hooks/index.ts`.
- Unknowns to confirm:
  - Exact Figma visual treatment for the parameter matrix and whether the final interaction complexity remains small enough for the recommended LiveView hook boundary.
  - Final user-facing validation copy and tooltip copy.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- `Oli.InstructorDashboard.StudentSupportParameters`
  - New domain/service module under `lib/oli/instructor_dashboard/`.
  - Owns defaults, validation, normalization, persistence API, and conversion from persisted settings to projector rule options.
  - Does not know about LiveView DOM events or React component implementation details.
- `Oli.InstructorDashboard.StudentSupportParameterSettings`
  - New Ecto schema for section-scoped saved settings.
  - One row per section, unique on `section_id`.
- `Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport`
  - Resolves the active parameter settings for the snapshot's section context before calling the projector.
  - Passes `inactivity_days` and rules generated from validated settings into `Projector.build/3`.
- `Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport.Projector`
  - Remains the non-UI bucket assignment engine.
  - Accepts rule options and inactivity days; it should expose or receive a typed parameter/rules shape instead of relying on private ad hoc maps.
- `OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTab`
  - Adds save/reload orchestration for `support_parameters_saved` or equivalent LiveView event.
  - On save, calls the service module and replaces the current LiveView Student Support projection from the newly persisted settings without evicting oracle caches.
- `StudentSupportTile`
  - Renders the `Edit parameters` affordance and the modal host.
  - Holds unsaved modal draft state until Save.
  - Receives `active_support_parameters` so threshold labels and inactive tooltip copy match the persisted projection inputs.
- `assets/src/hooks/student_support_parameters_matrix.ts`
  - New narrow LiveView hook mounted on the threshold matrix SVG.
  - Handles pointer/keyboard movement locally during drag so pointermove events do not round-trip to the server.
  - Applies visual constraints and updates the SVG preview while dragging.
  - Emits a single semantic event to LiveView when a movement is committed (`pointerup`, `pointercancel`, or keyboard commit), carrying the normalized field/value.
  - Does not persist data and does not calculate final student bucket assignments.

### 4.2 State & Data Flow
Load flow:
1. Instructor opens `Insights > Dashboard` for a section and scope.
2. Dashboard runtime assembles or hydrates oracle results as it does today.
3. `StudentSupport.derive/2` resolves active section settings:
   - persisted `student_support_parameter_settings` row if present
   - otherwise built-in defaults
4. The projector builds Student Support buckets with those settings.
5. LiveView passes the projection and active settings into `StudentSupportTile`.
6. The tile renders threshold labels, inactivity copy, chart/list state, and `Edit parameters`.

Save flow:
1. Instructor opens the modal from the tile (`AC-001`).
2. Draft values are edited in LiveView-owned modal state; the matrix hook constrains pointer/keyboard movement locally while dragging and commits the final normalized value back to LiveView once movement ends (`AC-002`).
3. Cancel, outside click, or Esc closes the modal and discards the draft without touching LiveView projection state or persisted settings (`AC-006`).
4. Save submits the current LiveView draft settings.
5. LiveView calls `StudentSupportParameters.save_for_section(section, attrs, actor)`.
6. The service validates the payload, upserts the section row in one transaction, and returns the persisted settings.
7. LiveView reuses current oracle results when available and forces the Student Support projection to rederive with the persisted settings.
8. The modal closes only after successful save/reload initiation, and the donut/list rerender from the reprojected payload (`AC-003`, `AC-004`, `AC-005`).
9. On save failure, LiveView keeps the existing projection/settings active and surfaces an error in the modal (`AC-007`).

### 4.3 Lifecycle & Ownership
- Persisted settings are section-owned and shared by all instructors in the section.
- Draft modal state is LiveView-owned and disposable until Save.
- The matrix hook may keep transient pointer/preview state while a drag is active, but commits the final value to LiveView when the interaction ends.
- Projection state is derived from persisted settings plus dashboard oracle payloads.
- `instructor_dashboard_states` remains enrollment-owned layout/scope preference storage and must not be extended for this feature.
- Projection refresh is owned by dashboard orchestration; projector modules should remain pure and cache unaware.

### 4.4 Alternatives Considered
- Extend `instructor_dashboard_states`.
  - Rejected because it is keyed by `enrollment_id`, which would violate the shared section source-of-truth requirement in `AC-004`.
- Add JSON settings directly to `sections`.
  - Rejected for baseline because the settings are feature-specific, have validation lifecycle of their own, and would add churn to the already broad section schema.
- Store only frontend JSON without a backend typed schema.
  - Rejected because classification rules must be validated and enforced consistently by backend projection code.
- Use a React/SVG editor component inside the LiveView tile.
  - Rejected as the baseline because the surrounding Student Support tile is already LiveView-owned and the expected hook contract is small: SVG pointer/keyboard preview locally, final value committed to LiveView. React remains a fallback if UI workflow proves the matrix editor needs substantial local component state beyond this hook boundary.
- Rebuild all dashboard oracles after save.
  - Acceptable as a simple fallback, but the preferred design is to keep oracle payloads and rederive Student Support projection with new settings. Parameter changes affect projection, not the underlying oracle data.

## 5. Interfaces
- Domain/service API:
  - `Oli.InstructorDashboard.StudentSupportParameters.default_settings() :: map()`
  - `Oli.InstructorDashboard.StudentSupportParameters.get_active_settings(section_id) :: settings`
  - `Oli.InstructorDashboard.StudentSupportParameters.save_for_section(section_id, attrs, actor) :: {:ok, settings} | {:error, Ecto.Changeset.t()}`
  - `Oli.InstructorDashboard.StudentSupportParameters.to_projector_opts(settings) :: keyword()`
- Ecto schema:
  - `Oli.InstructorDashboard.StudentSupportParameterSettings`
  - Fields described in section 6.
- Projection interface:
  - `StudentSupport.derive(snapshot, opts) -> {:ok, projection} | {:partial, projection, reason} | {:error, reason}`
  - `Projector.build(progress_rows, student_info_rows, opts) -> projection_map`
  - `opts` include `:inactivity_days` and a normalized rules/settings value.
- LiveView event interface:
  - `"student_support_parameters_opened"` or component-local equivalent opens the modal.
  - `"student_support_parameters_saved"` carries normalized settings from the modal.
  - `"student_support_parameters_cancelled"` closes the modal without persistence.
- Matrix hook commit payload:

```json
{
  "field": "excelling_progress_gte",
  "value": 60
}
```

- LiveView assigns:
  - `:student_support_projection`
  - `:student_support_tile_state`
  - `:student_support_parameters`
  - `:show_student_support_parameters_modal`
  - `:student_support_parameters_error`
- Hook DOM contract:
  - Matrix host element includes `phx-hook="StudentSupportParametersMatrix"`.
  - The hook receives current draft values through `data-*` attributes or hidden form values rendered by LiveView.
  - The SVG region affected by hook-owned local updates is isolated with `phx-update="ignore"` only if needed to prevent LiveView from replacing active drag DOM.
  - The hook sends `support_parameter_drag_committed` or equivalent with `field` and normalized integer `value` only after movement ends.

## 6. Data Model & Storage
- Add table `student_support_parameter_settings`:
  - `id`
  - `section_id` references `sections`, `null: false`, `on_delete: :delete_all`
  - `inactivity_days` integer, `null: false`, default `7`
  - `struggling_progress_low_lt` integer, `null: false`, default `40`
  - `struggling_progress_high_gt` integer, `null: false`, default `80`
  - `struggling_proficiency_lte` integer, `null: false`, default `40`
  - `excelling_progress_gte` integer, `null: false`, default `60`
  - `excelling_proficiency_gte` integer, `null: false`, default `80`
  - `inserted_at`, `updated_at`
- Indexes and constraints:
  - Unique index on `section_id`.
  - Check constraint for `inactivity_days in (7, 14, 30, 90)`.
  - Check constraints for every threshold field between 0 and 100.
  - Check constraint enforcing non-overlap between struggling and excelling proficiency boundaries.
  - Check constraint enforcing non-overlap between struggling and excelling progress boundaries.
- Schema changeset:
  - Casts the fields above.
  - Validates required fields.
  - Validates numeric range and allowed inactivity days.
  - Validates non-overlap with changeset errors matching modal fields.
  - Adds unique and check constraints to surface database failures cleanly.
- Defaults:
  - Defaults live in `StudentSupportParameters.default_settings/0` and match migration defaults.
  - `get_active_settings/1` returns defaults without inserting a row when no customization exists.

## 7. Consistency & Transactions
- Save is a single upsert transaction scoped by `section_id`.
- Repeated Save with the same payload is idempotent and returns the persisted row.
- Last successful save wins for concurrent instructors.
- Persist first, then reproject/reload. The UI must not update the chart/list from unsaved draft state.
- If persistence succeeds but projection reload fails, keep the persisted row, show a reload error, and allow a normal dashboard refresh to converge on the saved settings.
- If persistence fails, do not update tile output or active settings assign.

## 8. Caching Strategy
- Parameter settings affect projection output, not oracle payload identity.
- Current cache behavior validated in code:
  - In-process dashboard cache keys are `:dashboard_oracle` entries and store oracle payloads.
  - Revisit cache keys are `:dashboard_revisit_oracle` entries and store oracle payloads.
  - `IntelligentDashboardTab.persist_revisit_cache/4` writes `bundle.snapshot.oracles`, not `bundle.projections`.
  - Projection maps live in the current LiveView assigns through `:dashboard_bundle_state` and `:dashboard`, not in revisit cache.
- Save behavior:
  - Do not evict oracle caches when thresholds or inactivity days change.
  - Reuse current `dashboard_oracle_results` where available.
  - Rebuild the snapshot/projection for `:student_support` using the newly persisted settings.
  - Replace `dashboard_bundle_state.projections.student_support`, `dashboard_bundle_state.projection_statuses.student_support`, and `dashboard.student_support_projection` after save.
- Reload behavior:
  - On a fresh dashboard load, cached oracle hits remain valid and `StudentSupport.derive/2` must resolve active settings before building the projection.
  - Another instructor opening the same section can safely reuse cached oracle rows because the section-scoped settings are applied during projection derivation.
- Future guardrail:
  - If a later optimization stores projection or dashboard bundle payloads outside LiveView assigns, that cache identity must include a Student Support settings version/fingerprint or be bypassed on parameter save.

## 9. Performance & Scalability Posture
- Save path adds one section-scoped upsert and one projection reload/rederive.
- Projection rederive is bounded by the current scope's student rows and should not require re-querying unchanged oracle data when current results are present.
- No load testing is required by the PRD for this phase.
- Keep matrix hook interactions client-local during pointer movement; only the final committed value, numeric input changes, and Save should cross the LiveView/backend boundary.
- Avoid broad dashboard refetches when a projection-only rederive can satisfy `AC-005`.

## 10. Failure Modes & Resilience
- Invalid payload:
  - Backend changeset returns field errors; modal remains open and existing tile output is unchanged.
- Database conflict or constraint failure:
  - Return a save error, keep existing active settings/projection, and increment save-failure telemetry.
- Projection reload failure after save:
  - Surface reload error, increment reprojection-failure telemetry, and rely on subsequent dashboard reload to use persisted settings.
- Matrix hook mount failure:
  - Keep numeric inputs and Save/Cancel usable as a non-drag fallback; do not affect existing Student Support tile rendering.
- Stale concurrent modal:
  - Last successful save wins; a refreshed dashboard load converges on the persisted section settings.

## 11. Observability
- Emit AppSignal counters or telemetry events for:
  - `support_parameters.saved`
  - `support_parameters.save_failed`
  - `support_parameters.reprojection_failed`
- Include metadata:
  - `section_id`
  - `dashboard_scope`
  - `actor_id`
  - `error_type` or `reason_code` for failures
- Log validation failures at debug level or not at all to avoid noisy logs for normal user correction.
- Log persistence/reprojection failures at warning level with bounded metadata.

## 12. Security & Privacy
- Only authorized instructors/admins for the section may read or save settings.
- Students must not see the modal or be able to invoke save events.
- Settings do not contain student PII, but they affect instructor-visible grouping outputs for enrolled students and must remain section scoped.
- All persistence queries must filter by trusted section id from LiveView assigns/session context, not by client-supplied section id.
- Client payload validation is convenience only; backend validation is authoritative.

## 13. Testing Strategy
- Elixir unit tests:
  - `StudentSupportParameters` defaults, validation, non-overlap, allowed inactivity days, and projector option conversion.
  - `Projector.build/3` classification with custom thresholds and inactivity windows.
- Ecto/context tests:
  - `save_for_section/3` inserts and updates one row per section.
  - Defaults are returned when no row exists.
  - Instructor A save is visible through section-level lookup for Instructor B (`AC-004`).
  - Constraint errors preserve previous settings (`AC-007`).
- Projection tests:
  - `StudentSupport.derive/2` uses persisted settings when present and defaults otherwise (`AC-003`).
  - Save/rederive behavior produces changed bucket counts when thresholds change (`AC-005`).
- LiveView/component tests:
  - `Edit parameters` opens modal with inactivity and group range controls (`AC-001`).
  - Cancel/Esc/outside-dismiss closes without changing persisted settings or tile output (`AC-006`).
  - Save success closes modal and updates rendered chart/list payload (`AC-005`).
  - Save failure keeps modal state and shows error feedback (`AC-007`).
- TypeScript/Jest tests:
  - Hook value-to-position mapping, pointer commit behavior, keyboard movement, drag boundary constraints, and avoidance of per-pointermove server events (`AC-002`).
- Manual/accessibility checks:
  - Focus trap, Esc behavior, outside click behavior, screen-reader labels, visible focus, and keyboard-only operation.

## 14. Backwards Compatibility
- Existing sections without a settings row use the same default 7-day inactivity and default threshold behavior currently encoded in the projector.
- The migration is additive and does not require backfilling rows for every section.
- Code rollback leaves orphaned settings rows harmless if the table remains; a database rollback drops feature-specific settings.
- Existing Student Support URL params for bucket/filter/search/page remain unchanged.
- Existing `instructor_dashboard_states` behavior remains unchanged.

## 15. Risks & Mitigations
- Risk: custom threshold model mismatches product expectations for progress high/low struggling logic.
  - Mitigation: encode comparator names explicitly in field names and confirm against Jira/Figma during UI workflow before implementation.
- Risk: stale LiveView projection appears after save.
  - Mitigation: force projection rederive after persistence and replace the Student Support projection fields in `dashboard_bundle_state` and `dashboard`; if future work caches projections outside LiveView assigns, include a settings fingerprint or bypass that cache on save.
- Risk: the matrix hook grows into a mini app with too much imperative state.
  - Mitigation: keep modal draft state, validation errors, Save/Cancel, and persistence in LiveView; use the hook only for SVG pointer/keyboard preview and final value commits. Reconsider a React component only if UI workflow confirms materially higher interaction complexity.
- Risk: concurrent instructors overwrite each other without noticing.
  - Mitigation: document last-successful-save-wins for this slice and consider optimistic locking only if product requests conflict messaging later.

## 16. Open Questions & Follow-ups
- Confirm exact Figma/control behavior for dragging the matrix boundary and keyboard equivalents before coding the editor.
- Confirm during UI workflow that the LiveView hook boundary is sufficient for the final matrix interaction; escalate to React only if the hook would otherwise own broad modal state.
- Confirm exact validation and error copy with product/design.
- Decide during planning whether projection rederive can reuse `dashboard_oracle_results` directly or should call a narrower dashboard reload helper first.

## 17. References
- `docs/exec-plans/current/epics/intelligent_dashboard/customize_parameters/prd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/customize_parameters/requirements.yml`
- `docs/exec-plans/current/epics/intelligent_dashboard/customize_parameters/informal.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/support_tile/fdd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/data_snapshot/fdd.md`
- `lib/oli/instructor_dashboard/data_snapshot/projections/student_support.ex`
- `lib/oli/instructor_dashboard/data_snapshot/projections/student_support/projector.ex`
- `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/student_support_tile.ex`
- `lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex`
- `lib/oli/instructor_dashboard.ex`
- `lib/oli/instructor_dashboard/instructor_dashboard_state.ex`
- `https://eliterate.atlassian.net/browse/MER-5256`

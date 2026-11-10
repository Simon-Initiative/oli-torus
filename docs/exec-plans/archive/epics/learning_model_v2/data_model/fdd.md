# Learning Model V2 Data Model And Configuration - Functional Design Document

## 1. Executive Summary

This design adds the behavior-neutral persistence contracts required before Torus can calculate or display LKT-AOA proficiency. Projects and Sections receive an explicit semantic `learning_model_version`; resource Revisions receive typed, versioned `learning_model_parameters`; project archives preserve both Project/template model selection and supported Revision parameter envelopes; and one startup-loaded configuration boundary supplies global LKT-AOA coefficients.

The implementation stays within existing Torus ownership boundaries: authoring owns Project selection, delivery owns Section selection, Resources owns Revision persistence, Interop owns archive encoding and decoding, and a new `Oli.LearningModel` namespace owns shared model codecs and configuration. Existing and newly created entities remain `:naive`; this work does not calculate learner state or expose an enablement UI.

The complete field shapes, precedence rules, defaults, and lifecycle decisions remain authoritative in `docs/exec-plans/current/epics/learning_model_v2/data_model/informal.md`. This FDD summarizes those decisions and maps them to concrete repository interfaces and verification points. It covers `FR-001` through `FR-009` and `AC-001` through `AC-030`.

## 2. Requirements & Assumptions

- Functional requirements:
  - Persist non-null semantic selection on Projects and Sections independently of `analytics_version` (`FR-001`, `AC-001`, `AC-002`).
  - Explicitly propagate selection through Project, blueprint/template, Section, clone, and duplicate creation while pinning each created Section (`FR-002`, `AC-003`, `AC-004`, `AC-005`).
  - Preserve `:naive` as the migration, database, schema, and new-Project default for this work item, with no product enablement control (`FR-003`, `AC-006`, `AC-007`).
  - Preserve Project and blueprint/template selection through modern and legacy project archives (`FR-004`, `AC-008` through `AC-012`).
  - Store an optional self-describing LKT-AOA parameter envelope on exact Revisions (`FR-005`, `AC-013`, `AC-014`).
  - Represent one finite `beta_lo` for an LO and one finite `beta_difficulty` per activity part, including missing-versus-zero semantics and stale-part reconciliation (`FR-006`, `AC-015` through `AC-018`).
  - Expose parameters as versioned structs through one custom Ecto type and reject unsupported or mismatched envelopes (`FR-007`, `AC-019`, `AC-020`).
  - Preserve parameter payloads through Revision creation, duplication, publication, and project archive workflows (`FR-008`, `AC-021` through `AC-024`).
  - Load validated global coefficients once at application startup with explicit defaults and environment overrides (`FR-009`, `AC-025` through `AC-030`).
- Non-functional requirements:
  - Adding nullable Revision JSONB and small Project/Section enum columns must not introduce history-dependent reads or alter proficiency behavior.
  - Delivery must resolve parameters from publication-pinned Revisions, never authoring HEAD Revisions.
  - Invalid explicit archive values, parameter envelopes, and environment values fail at their owning boundary with actionable errors; they do not silently downgrade.
  - Export adds no per-template queries and configuration reads are centralized.
  - No learner data, credentials, or secrets are introduced.
- Assumptions:
  - Semantic values are exactly `:naive` and `:lkt_aoa`; external archive values are exactly `"naive"` and `"lkt_aoa"`.
  - LKT-AOA v2 parameter envelopes use `schema_version: 1`, `model: "lkt_aoa"`, and `model_version: 2`.
  - Missing LO or activity-part coefficients resolve to `0.0` in the later calculation layer. Persisted `0.0` remains trained data.
  - A part difficulty belongs to an activity part, not the activity as a whole or an activity-part/LO pair.
  - Global defaults are `gamma: 0.1`, `rho: 1.0`, `recency_decay: 0.9`, and `confidence_saturation: 3.0`.
  - Deployment configuration history is the initial audit mechanism for coefficient changes; historical state is not recomputed after a restart with new values.

## 3. Repository Context Summary

- What we know:
  - `Oli.Authoring.Course.Project` and `Oli.Delivery.Sections.Section` already store `analytics_version` as Ecto enums. Learning-model selection must be a separate field and dispatch contract.
  - `Oli.Authoring.Course.create_project/3` builds Project defaults; `Oli.Authoring.Clone.clone_project/3` has a separate explicit Project attribute map.
  - `Oli.Delivery.create_new_section/4` owns Project-to-Section and blueprint-to-Section entry paths. `Oli.Delivery.Sections.Blueprint.create_blueprint/5`, `build_blueprint_attrs/4`, and `duplicate/3` own template creation and duplication.
  - `Oli.Resources.Revision` documents that newly added fields must also be copied by `Oli.Resources.create_revision_from_previous/2`.
  - Additional Revision bulk-copy boundaries exist in `Oli.Authoring.Editing.AdaptiveDuplication` and `Oli.Publishing.UniqueIds`; project cloning reuses published Revision rows and therefore retains their fields without a new Revision copy.
  - Publication stability is represented by `published_resources`, which maps a publication and resource to an exact Revision. No parameter copy into Publication or Section tables is needed.
  - `Oli.Interop.Export` already has the Project, Product, objective, and activity archive builders. Project ingest and Product ingest use separate processors, while objective and activity processors bulk-insert Revisions.
  - The current Project archive schema permits additive resource properties. Ingest still needs domain validation because `Repo.insert_all/3` does not execute `Revision.changeset/2`.
  - Standard activity part IDs live under `content["authoring"]["parts"]`; adaptive activity helpers in `Oli.Activities.AdaptiveParts` already provide canonical persisted part IDs across authoring parts and `partsLayout`.
  - `config/config.exs` owns application defaults and `config/runtime.exs` owns environment overrides.
- Unknowns to confirm:
  - None are blocking. File line numbers and the latest migration timestamp must be resolved at implementation time.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

`Oli.LearningModel` is the shared domain namespace. It must not own learner-state calculation in this work item.

- `Oli.LearningModel.ModelVersion` owns the supported semantic values and archive encoding/decoding. Project and Product ingest both call the same decoder; no caller creates atoms from archive strings.
- `Oli.LearningModel.Parameters` is the version-neutral envelope struct and public typed boundary.
- `Oli.LearningModel.Parameters.Type` is the custom Ecto type for the Revision JSONB column. It delegates envelope dispatch and typed payload construction.
- `Oli.LearningModel.V2.LearningObjectiveParameters`, `ActivityParameters`, and `PartParameters` own v2 payload fields.
- `Oli.LearningModel.Parameters.Validation` owns finite-number checks, envelope/resource-type agreement, and activity-part membership/reconciliation.
- `Oli.LearningModel.Config` exposes the effective startup-loaded coefficients as a typed struct or documented typed map. Runtime consumers call this module rather than `System.get_env/1` or scattered `Application.get_env/3` calls.

Existing contexts retain workflow ownership:

- Authoring Project creation and cloning explicitly carry `learning_model_version`.
- Delivery blueprint and Section creation explicitly carry the source value.
- Resources casts, validates, and copies `learning_model_parameters`.
- Publishing continues pinning exact Revisions; its bulk Revision-copy helpers preserve the new field.
- Interop serializes semantic model strings and parameter envelopes, then validates them before domain creation or bulk insert.

### 4.2 State & Data Flow

Model-selection creation flow:

1. A Project is created with `:naive` unless a trusted caller explicitly supplies a valid value.
2. Creating a blueprint from a Project copies the Project value in `build_blueprint_attrs/4`.
3. Creating a Section directly from a Project/publication copies the Project value into `section_params`.
4. Creating a Section from a blueprint copies the blueprint value; it must not re-read or derive from the base Project.
5. Clone and duplicate operations copy their immediate source values.
6. Later source updates do not mutate existing Sections.

Revision-parameter write flow:

1. A caller supplies `nil`, a typed parameter struct, or an external map to `Revision.changeset/2`.
2. `Parameters.Type.cast/1` accepts only supported structs/maps and builds the explicit v2 payload type.
3. Revision validation compares `parameter_type` with `resource_type_id`, validates finite coefficient values, and validates activity part IDs against the same candidate Revision content.
4. For an explicitly supplied activity payload, unknown part IDs are validation errors.
5. When an existing payload is inherited while creating a child Revision whose content removes parts, the copy helper reconciles the activity map by dropping only entries whose part IDs no longer exist. Newly added parts remain absent/untrained.
6. `Parameters.Type.dump/1` emits the canonical string-keyed JSON envelope into JSONB; `load/1` reconstructs typed structs or returns a controlled load error for unsupported persisted versions.

Archive flow:

1. Export writes each entity's persisted semantic selection, never a derived default.
2. Export writes canonical `learningModelParameters` on LO and activity resource JSON when the Revision field is present; omission represents no trained payload.
3. Project import decodes missing/null selection as `:naive`; explicit valid strings become atoms; any other explicit value/type fails ingest.
4. Product import decodes missing/null selection using the imported Project value; a valid Product value wins even when different from the Project.
5. Objective and activity import decode `learningModelParameters` through the same parameter codec and validate it against resource type and imported activity content before adding the dumped field to the bulk Revision payload.
6. Legacy resources without the parameter property remain `nil`.

Configuration flow:

1. `config/config.exs` declares all four defaults under `config :oli, :lkt_aoa`.
2. `config/runtime.exs` reads each optional environment variable, requires a complete numeric parse, rejects non-finite/out-of-range values, and raises an error naming the offending variable.
3. Runtime configuration replaces only values whose variables are present and writes the complete validated keyword list to application environment.
4. `Oli.LearningModel.Config.fetch!/0` validates the final application value and returns the typed effective configuration. Later bulk calculations fetch it once per operation.
5. No process, UI, database record, or per-Project override mutates these values while a node is running.

### 4.3 Lifecycle & Ownership

- Project selection is mutable only through trusted domain operations; no normal UI exposes it in this chunk. Templates created after a Project change inherit the value at their own creation time.
- Section and blueprint selection is persisted on the Section row. An enrollable Section remains pinned after creation. Any future change to an active Section requires an explicit migration/backfill workflow rather than source propagation or ordinary editing.
- Revision parameters are immutable in published history. Parameter edits create new Revisions; publication selects the exact Revision visible to a Section.
- A single Revision stores at most one active parameter envelope. Future decoders coexist with v2 instead of rewriting old JSON.
- Application coefficient changes affect transitions performed after deployment restart only.

### 4.4 Alternatives Considered

- Reuse `analytics_version`: rejected because analytics persistence and learning-model behavior have independent lifecycles and meanings.
- Infer Section selection from its current Project/template: rejected because Sections must remain stable after source changes.
- Reuse `Revision.parameters`: rejected because generic activity/objective parameters have no learning-model versioning contract and already serve other concerns.
- Store separate beta columns or one scalar per activity: rejected because activities require one difficulty per part and future model versions require a self-describing payload.
- Expose raw JSON maps: rejected because unsupported versions, resource-type mismatches, and missing-versus-zero semantics would leak into every caller.
- Copy parameter values into publications or learner-state rows: rejected because `PublishedResource` already pins Revisions and global coefficients are application settings.
- Omit parameters from project archive export: rejected because `AC-024` requires configuration-preserving archive workflows and a Project round trip must not discard trained Revision data.
- Silently fall back on malformed environment or archive values: rejected because it hides operational/model changes.

## 5. Interfaces

Schema fields:

```elixir
# Oli.Authoring.Course.Project and Oli.Delivery.Sections.Section
field :learning_model_version,
  Ecto.Enum,
  values: [:naive, :lkt_aoa],
  default: :naive

# Oli.Resources.Revision
field :learning_model_parameters, Oli.LearningModel.Parameters.Type
```

Model-version codec:

```elixir
@spec values() :: [:naive | :lkt_aoa]
@spec encode(:naive | :lkt_aoa) :: "naive" | "lkt_aoa"
@spec decode_archive(term(), :naive | :lkt_aoa) ::
        {:ok, :naive | :lkt_aoa} | {:error, {:invalid_learning_model_version, term()}}
```

`decode_archive/2` treats only `nil` as missing and returns the supplied fallback. It does not accept atom input from external JSON and does not call `String.to_atom/1`.

Canonical parameter structs:

```elixir
%Oli.LearningModel.Parameters{
  schema_version: 1,
  model: :lkt_aoa,
  model_version: 2,
  parameter_type: :learning_objective | :activity,
  payload: %LearningObjectiveParameters{} | %ActivityParameters{}
}

%LearningObjectiveParameters{beta_lo: float()}
%ActivityParameters{parts: %{String.t() => %PartParameters{beta_difficulty: float()}}}
%PartParameters{beta_difficulty: float()}
```

Parameter boundary:

```elixir
@spec cast(term()) :: {:ok, Parameters.t() | nil} | :error
@spec dump(Parameters.t() | nil) :: {:ok, map() | nil} | :error
@spec load(map() | nil) :: {:ok, Parameters.t() | nil} | :error

@spec validate_for_revision(Parameters.t() | nil, resource_type_id(), map()) ::
        :ok | {:error, keyword(String.t())}

@spec reconcile_inherited_parts(Parameters.t() | nil, map()) :: Parameters.t() | nil
```

Configuration boundary:

```elixir
%Oli.LearningModel.Config{
  gamma: 0.1,
  rho: 1.0,
  recency_decay: 0.9,
  confidence_saturation: 3.0
}

@spec fetch!() :: Oli.LearningModel.Config.t()
```

Archive contract:

- `_project.json`: `"learningModelVersion": "naive" | "lkt_aoa"`.
- `_product-<id>.json`: the persisted Product/blueprint `learningModelVersion`.
- LO and activity resource files: optional `"learningModelParameters": <canonical envelope>`.
- Missing/null Project selection falls back to `:naive`; missing/null Product selection falls back to the imported Project value.
- Unsupported explicit model selection or parameter envelope fails ingest with resource/file context.

## 6. Data Model & Storage

Migration changes:

- `projects.learning_model_version`: string-backed enum storage, initially nullable only during migration sequencing, database default `"naive"`, then non-null.
- `sections.learning_model_version`: same storage, backfill, default, and non-null constraint.
- `revisions.learning_model_parameters`: nullable JSONB (`:map` at the migration layer), with no database default.

Migration sequence:

1. Add Project and Section columns with `"naive"` defaults.
2. Explicitly update any null rows to `"naive"`.
3. Enforce non-null and retain the database defaults.
4. Add database check constraints limiting values to `"naive"` and `"lkt_aoa"` so raw SQL cannot persist an unsupported selection.
5. Add the nullable Revision JSONB column without a default; this is a metadata-only shape change and does not rewrite historical Revision payloads.

No index is needed for `learning_model_version` in this chunk because all dispatch starts from an already-loaded Project or Section. No JSONB index is needed because parameters are retrieved with exact Revisions, not searched by coefficient content.

Canonical stored envelopes and detailed examples are defined in `data_model/informal.md`. Database JSON uses string keys and stable external model/parameter-type strings. The Ecto layer exposes atoms only for fixed enumerations and typed structs for payloads.

Every explicit Revision copy map must carry `learning_model_parameters`, including:

- `Oli.Resources.create_revision_from_previous/2`;
- `Oli.Authoring.Editing.AdaptiveDuplication.build_revision_row/5`;
- any package/activity duplication map that selects Revision fields explicitly.

`Oli.Publishing.UniqueIds.add_revisions/1` currently copies the loaded Revision struct by dropping Ecto-only fields, so the new schema field is retained automatically. Add a regression test to protect that implicit behavior. Project cloning copies `published_resources` references and therefore retains the same exact parameterized Revisions; blueprint duplication copies Section selection through the Section map.

## 7. Consistency & Transactions

- The Project/Section migration is transactional. Backfill and constraint enforcement complete before application code depends on non-null values.
- Existing Project, blueprint, Section, and clone workflows retain their current transaction boundaries. `learning_model_version` is included in the entity creation inside those transactions, so no follow-up update can expose a partially propagated entity.
- Revision field validation happens before insert. For `Repo.insert_all/3` archive and duplication paths, callers must invoke the parameter codec/validator before building the row because changesets are bypassed.
- `create_revision_from_previous/2` calculates the inherited/reconciled parameter value before inserting the child Revision. Caller-supplied replacement parameters take precedence and are strictly validated; inherited activity parameters are pruned against the child content.
- Publication does not duplicate parameter JSON. Its existing transaction pins the Revision ID, which atomically selects content and parameters together.
- Import runs within the existing ingest transaction. Any invalid Project/Product selection or resource parameter sets `force_rollback` or returns the processor's normal error form; no partially imported model configuration commits.
- Configuration validation completes before the application starts serving work. A bad explicit override raises instead of producing a mixed cluster with silent defaults. Operators must deploy the same environment values to every node.

## 8. Caching Strategy

No cache is introduced. Model selection is loaded with its Project or Section, parameters are loaded with exact Revisions, and global coefficients are already held in application environment after startup. Adding Cachex would create invalidation responsibilities without removing a required database read.

Later bulk calculation code should call `Oli.LearningModel.Config.fetch!/0` once per batch and pass the resulting immutable value through the calculation boundary rather than repeatedly reading application environment.

## 9. Performance & Scalability Posture

- The Project and Section additions are constant-size scalar fields. Their migration touches existing rows once and does not add query joins.
- The nullable Revision JSONB column has no default and no index, avoiding a historical-table rewrite and unnecessary write amplification.
- Parameter lookup is part of the Revision read already required by publication resolution; this work adds no attempt-history reads.
- Project export uses already-loaded Project and Product Section structs. Adding `learningModelVersion` causes no query or preload per Product.
- Resource parameter export operates on the Revision collection already fetched for the working publication/product. It causes no per-resource lookup.
- Parameter decode cost is linear in the number of configured activity parts for that one Revision. The typed value is decoded once when Ecto loads the Revision.
- No JSONB containment/search queries are designed, so no GIN index is warranted.

## 10. Failure Modes & Resilience

- Existing null selection during migration: backfill to `"naive"` before enforcing non-null.
- Unsupported Project/Section value through Ecto or raw SQL: reject through Ecto.Enum casting and database check constraints.
- Missing/null legacy Project archive value: import as `:naive`.
- Missing/null legacy Product value: inherit the imported Project value.
- Unsupported explicit archive value/type: fail ingest with file/entity context; never select `:naive` silently.
- Missing parameter envelope: load/import as `nil` and use later cold-start behavior.
- Unsupported schema/model version or parameter type: return controlled codec/changeset/ingest errors; never interpret as v2.
- Parameter type mismatched to Revision resource type: add an actionable `learning_model_parameters` changeset or ingest error.
- Non-finite coefficient: reject before JSONB persistence.
- Explicit activity parameter references an unknown part: reject and name the part ID.
- An inherited parameter references a part deleted in the child Revision: remove that entry; retain surviving entries; do not synthesize entries for new parts.
- Environment variable is partially numeric, non-finite, or out of range: abort startup and name the variable without printing unrelated environment values.
- Different coefficient configuration across nodes: deployment error; startup logs make the effective non-secret values visible and deployment tooling remains responsible for uniformity.

## 11. Observability

- Emit one bounded startup log after successful LKT-AOA configuration validation containing the four effective numeric values and whether each came from default or override. These values are not secrets.
- Startup exceptions name only the invalid environment variable and validation reason.
- Preserve existing Interop step/error reporting and AppSignal capture. Archive errors include the file/entity identifier, field name, and stable error category without dumping whole resource JSON.
- Migration verification reports counts of null/unsupported Project and Section values before non-null/check constraints are enforced.
- No learner-level telemetry and no high-cardinality parameter telemetry are added.
- Success is verified primarily through migration checks and tests: complete `:naive` backfill, exact archive round trips, and default/override configuration behavior.

## 12. Security & Privacy

- This work stores no learner identifiers, attempts, responses, or proficiency state.
- Learning-model parameter data is course content metadata and follows existing Project/Revision authorization and publication access controls.
- No new HTTP, LiveView, or public authoring endpoint is introduced. Trusted internal/test code may create `:lkt_aoa` records, but normal users cannot enable the model in this chunk.
- Archive decoding uses fixed string matching and never creates atoms from untrusted input.
- JSON validation is bounded to supported envelopes and existing activity part sets. Error output must not dump full authored content.
- Environment settings contain no secrets; nevertheless, validation code must inspect only the four named variables and must not log the process environment.

## 13. Testing Strategy

- Migration and schema ExUnit tests:
  - Existing Project and Section fixtures become `:naive`; database/Ecto defaults, non-null constraints, check constraints, and enum casting satisfy `AC-001`, `AC-002`, and `AC-007`.
  - New Project creation remains `:naive` and no UI field is introduced for `AC-006`.
- Propagation tests:
  - Project-to-Section, Project-to-blueprint, and blueprint-to-Section copy the source value for `AC-003`.
  - Project clone, blueprint duplicate, and enrollable Section duplicate paths preserve selection for `AC-004`.
  - Changing a source after Section creation leaves the Section value unchanged for `AC-005`.
  - Prefer one `Oli.Scenarios` Project-to-publication-to-blueprint-to-Section workflow if the current directives can assert fields without infrastructure expansion; otherwise use domain integration tests.
- Interop tests:
  - Extend `test/oli/interop/export_test.exs` with direct `_project.json`, Product, LO, and activity JSON assertions for `AC-008`, `AC-009`, `AC-013`, and `AC-024`.
  - Add full export/import round trips for matching and divergent Project/Product values, LKT-AOA parameter envelopes, and explicit zero for `AC-010`, `AC-018`, and `AC-024`.
  - Add legacy missing/null fallback and invalid type/value cases for `AC-011`, `AC-012`, and `AC-020`.
- Parameter unit tests:
  - Ecto type cast/load/dump round trips for LO and activity structs (`AC-019`).
  - Envelope version dispatch, resource-type mismatch, required fields, finite numbers, and unknown part IDs (`AC-015`, `AC-016`, `AC-020`).
  - Missing payload/part versus explicit `0.0`, inherited stale-part pruning, and new untrained parts (`AC-014`, `AC-017`, `AC-018`).
- Revision lifecycle tests:
  - `create_revision_from_previous/2` preserves parameters unless explicitly replaced (`AC-021`).
  - Adaptive duplication, unique-ID Revision recreation, and relevant activity/package duplication preserve typed payloads (`AC-022`).
  - Publish an LO/activity Revision with parameters, create a newer authoring Revision with different parameters, and prove the earlier publication resolves the pinned values (`AC-023`).
- Configuration tests:
  - Pure parser/config tests cover the four defaults and every valid override (`AC-025`, `AC-026`, `AC-027`).
  - Malformed, trailing-junk, non-finite, negative `gamma`/`rho`, invalid decay bounds, and non-positive saturation fail with the relevant environment name (`AC-028`, `AC-029`).
  - Code/path inspection plus a focused test confirms there is no UI, database, Project override, or runtime mutation API (`AC-030`).
- Required gates:
  - Run focused `mix test` targets for Course/Project, Sections/Blueprint/Delivery, Resources/Publishing, Interop, and learning-model configuration.
  - Run `mix format` for changed Elixir, migration, and test files.
  - Review migration plans for table rewrite and lock risk.
  - Apply `.review/elixir.md`, `.review/security.md`, `.review/performance.md`, and `.review/requirements.md` during code review.

## 14. Backwards Compatibility

- Existing Projects and Sections are explicitly backfilled to `:naive`; adding fields alone does not change proficiency behavior.
- Newly created Projects remain `:naive` until a separate rollout changes creation policy after the core and usage work are production-ready.
- Existing archives without model fields or Revision parameters remain importable under deterministic fallbacks.
- Archive additions are optional/additive for older consumers: model selection appears as new top-level properties, and absent parameter envelopes retain current behavior.
- Naive and untrained LKT-AOA Revisions may keep `learning_model_parameters: nil`.
- Existing `Revision.parameters` data is untouched.
- Existing publications continue resolving the exact same Revision IDs and therefore acquire no mutable dependency on authoring HEAD.
- No feature flag is needed because normal users cannot select LKT-AOA and all operational behavior remains naive in this chunk.

## 15. Risks & Mitigations

- A secondary creation path relies on the destination default: inventory every Project/Section/blueprint constructor and add explicit propagation tests; keep `:naive` defaults only as a safety net.
- A bulk Revision path bypasses changeset validation or drops the new field: validate archive payloads before `insert_all/3`, update explicit copy maps, and regression-test struct-based copy paths.
- Activity part extraction differs between standard and adaptive activities: centralize part-ID extraction and reuse `Oli.Activities.AdaptiveParts` for adaptive persisted IDs rather than duplicating JSON traversal.
- Stale parameters survive content edits: distinguish strict caller-supplied payload validation from inherited-payload reconciliation when creating a child Revision.
- Archive round trip preserves selection but loses parameters: add the optional resource-level `learningModelParameters` field to both export and objective/activity ingest and test the complete round trip.
- Database and Ecto enum constraints drift: define values once in `ModelVersion` where practical and test both schema casting and database constraints.
- Configuration parsing accepts trailing junk or infinity: require a complete finite parse and explicit bounds before application startup.
- Global coefficient changes reduce exact historical reproducibility: retain deployment configuration history now and defer a configuration-version audit feature until it is required.

## 16. Open Questions & Follow-ups

- No unresolved question blocks this design.
- A later rollout must change only new-Project creation policy to `:lkt_aoa`; it must not rewrite existing Projects or Sections.
- The authoring or administrative workflow for uploading externally trained parameter envelopes is a separate feature.
- Supporting simultaneous production and shadow parameter sets on one Revision is deferred.
- Exact per-transition reproducibility across global configuration changes would require a separate configuration-version audit design.
- Learner state, evidence, Snapshot Worker integration, Metrics dispatch, page/container proficiency, and authoring Insights remain in the `core_impl` and `usage` work items.

## 17. Stable Downstream Interfaces

The later `core_impl` and `usage` work items consume the following contracts without
reinterpreting persistence details:

- **Model dispatch:** use the already-loaded `Section.learning_model_version` field and
  dispatch explicitly on `:naive` or `:lkt_aoa`. Do not infer the model from
  `analytics_version`, the source Project, a template, or parameter presence. A Section's
  persisted value is the delivery-time authority.
- **Published parameters:** resolve content through the existing delivery/publication
  resolver and read `Revision.learning_model_parameters` from that exact pinned Revision.
  The Ecto field returns `nil` or an `Oli.LearningModel.Parameters` struct whose payload is
  a versioned LO/activity struct; consumers must not decode the underlying JSONB directly
  or substitute the latest authoring Revision.
- **Cold start:** a missing LO envelope or missing activity-part entry contributes a beta
  value of `0.0`. An explicitly stored `0.0` remains trained data and is not equivalent to
  absence for persistence, export, or lifecycle decisions.
- **Global coefficients:** call `Oli.LearningModel.Config.fetch!/0` once at the start of a
  bulk proficiency operation and pass the returned immutable `%Oli.LearningModel.Config{}`
  through every transition in that batch. Do not read environment variables in calculation
  code, repeatedly fetch application configuration per contribution, or copy coefficients
  into learner-state rows.

These interfaces deliberately provide no `learning_state`, evidence, Snapshot Worker,
Metrics, page/container aggregation, or authoring Insights behavior. Those responsibilities
remain owned by the later work items.

## 18. References

- `docs/exec-plans/current/epics/learning_model_v2/data_model/prd.md`
- `docs/exec-plans/current/epics/learning_model_v2/data_model/requirements.yml`
- `docs/exec-plans/current/epics/learning_model_v2/data_model/informal.md`
- `docs/exec-plans/current/epics/learning_model_v2/informal.md`
- `ARCHITECTURE.md`
- `docs/BACKEND.md`
- `docs/OPERATIONS.md`
- `docs/TESTING.md`
- `docs/design-docs/high-level.md`
- `docs/design-docs/publication-model.md`
- `lib/oli/authoring/course/project.ex`
- `lib/oli/authoring/course.ex`
- `lib/oli/authoring/clone.ex`
- `lib/oli/delivery.ex`
- `lib/oli/delivery/sections/section.ex`
- `lib/oli/delivery/sections/blueprint.ex`
- `lib/oli/resources/revision.ex`
- `lib/oli/resources.ex`
- `lib/oli/authoring/editing/adaptive_duplication.ex`
- `lib/oli/publishing/unique_ids.ex`
- `lib/oli/interop/export.ex`
- `lib/oli/interop/ingest/processor/project.ex`
- `lib/oli/interop/ingest/processor/products.ex`
- `lib/oli/interop/ingest/processor/objectives.ex`
- `lib/oli/interop/ingest/processor/activities.ex`
- `config/config.exs`
- `config/runtime.exs`

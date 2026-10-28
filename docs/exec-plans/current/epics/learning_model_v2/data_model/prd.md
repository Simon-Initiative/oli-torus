# Learning Model V2 Data Model And Configuration - Product Requirements Document

## 1. Overview
Establish the backward-compatible persistence and configuration foundation required for Torus to support both the existing naive proficiency model and LKT-AOA. Projects and Sections gain an explicit semantic model selection, resource Revisions gain versioned learning-model parameter storage, project archives preserve model selection, and global LKT-AOA coefficients become validated startup configuration.

This work intentionally does not calculate proficiency or expose LKT-AOA to normal users. It prepares stable data contracts that the later core implementation and usage work items can consume.

## 2. Background & Problem Statement
Torus currently has one implicit proficiency behavior. LKT-AOA introduces a second model with different runtime calculations and learned parameters for learning objectives and activity parts. Without explicit model selection and versioned parameter storage, delivery code cannot choose behavior reliably, published Sections cannot remain stable, and course duplication or import/export can silently lose model meaning.

The persistence change must not alter existing course behavior while the remaining LKT-AOA implementation is incomplete. Existing and newly created Projects therefore remain naive in this work item, even though a later rollout will make LKT-AOA the default for newly created Projects.

## 3. Goals & Non-Goals
### Goals
- Persist semantic learning-model selection on Projects and Sections using `:naive` and `:lkt_aoa`.
- Preserve model selection through Project, template, Section, duplication, and archive workflows.
- Keep Sections pinned to the model selected at their creation boundary.
- Store self-describing, versioned learning-model parameters on exact resource Revisions.
- Represent one LO coefficient and one difficulty coefficient per activity part through typed Elixir boundaries.
- Provide validated environment-backed application settings for global LKT-AOA coefficients.
- Preserve current proficiency behavior for all existing and newly created Projects and Sections in this chunk.

### Non-Goals
- Do not calculate or persist learner proficiency, confidence, evidence, or `learning_state`.
- Do not integrate with the Snapshot Worker or change Metrics reads and displays.
- Do not build internal model training, retraining, or parameter-upload UI.
- Do not change Authoring Insights.
- Do not make LKT-AOA the automatic default for newly created Projects yet.
- Do not support production and shadow learning models simultaneously on one Revision.

## 4. Users & Use Cases
- Learning engineers: attach externally trained, versioned LO and activity-part parameters to unpublished Revisions for later publication.
- Authors: duplicate, publish, export, and import course content without losing its selected learning model or Revision parameters.
- Instructors and students: continue receiving stable Section behavior determined at Section creation, unaffected by later source changes.
- System administrators and operators: configure global LKT-AOA coefficients through deployment environment variables and receive immediate startup failures for invalid values.
- Developers: consume typed parameter structures and explicit model selection without interpreting arbitrary JSON maps or inferring behavior from analytics settings.

## 5. UX / UI Requirements
N/A

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Backward compatibility: adding the new fields must not change proficiency behavior for existing or newly created Projects and Sections.
- Reliability: model selection must be non-null and explicit; invalid archive values, unsupported parameter versions, and invalid startup configuration must fail with controlled, actionable errors.
- Publication stability: delivery consumers must resolve parameters from the Revisions pinned to the Section's publications, never mutable authoring head Revisions.
- Maintainability: learning-model JSON must load through versioned structs and one custom Ecto type; environment access must be centralized behind one typed configuration module.
- Performance: export must use already-loaded Project and template values without additional per-template queries, and parameter persistence must not introduce history-dependent reads.
- Security and privacy: parameter and configuration errors must not expose secrets or learner data; no learner data is added by this work item.

## 9. Data, Interfaces & Dependencies
- Add non-null `learning_model_version` Ecto.Enum fields to `Oli.Authoring.Course.Project` and `Oli.Delivery.Sections.Section`, with values `:naive` and `:lkt_aoa` and initial default `:naive`.
- Add dedicated JSONB `learning_model_parameters` storage to `Oli.Resources.Revision`.
- The parameter envelope identifies `schema_version`, `model`, `model_version`, and `parameter_type` and contains either an LO `beta_lo` or activity `parts` keyed by string part IDs with `beta_difficulty` values.
- Add versioned parameter structs and a custom Ecto type under an `Oli.LearningModel` boundary.
- Extend `_project.json` and every `_product-<id>.json` with camel-case `learningModelVersion` strings.
- Update `Oli.Interop.Export`, project and product ingest processors, and blueprint attribute construction to preserve archive values.
- Add startup configuration under `config :oli, :lkt_aoa` with defaults `gamma: 0.1`, `rho: 1.0`, `recency_decay: 0.9`, and `confidence_saturation: 3.0`, plus `LKT_AOA_GAMMA`, `LKT_AOA_RHO`, `LKT_AOA_RECENCY_DECAY`, and `LKT_AOA_CONFIDENCE_SATURATION` overrides loaded from `config/runtime.exs`.
- Depends on existing resource/Revision publication, Project/template duplication, Section creation, and interop archive workflows.
- Later `core_impl` and `usage` work items depend on the contracts established here.

## 10. Repository & Platform Considerations
- Backend domain behavior belongs under `lib/oli/`; transport and UI layers must not own model selection or parameter validation.
- Respect the resource/Revision and publication model: parameter changes create Revisions, while published content remains immutable.
- Migrations must backfill before enforcing non-null semantics and must be safe for existing production data.
- Add focused ExUnit coverage for schemas, changesets, typed parameter serialization, creation propagation, duplication, publication, and interop round trips.
- Use `Oli.Scenarios` for a realistic Project-to-publication-to-template-to-Section propagation workflow if current scenario directives support the necessary assertions; otherwise cover domain paths with focused ExUnit integration tests.
- Required implementation gates include targeted `mix test`, `mix format`, and migration review.
- Code review must include `.review/security.md`, `.review/performance.md`, `.review/elixir.md`, and `.review/requirements.md`.
- Jira is the execution system of record, but no Jira issue key is currently linked to this work item.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

Existing Projects and Sections are backfilled to `:naive`, and both database and schema defaults remain `:naive`. Newly created Projects also remain `:naive` in this chunk. Normal product interfaces must not expose an LKT-AOA enablement control until the core calculation and usage chunks are ready.

A later rollout will deliberately change only the creation policy for new Projects to `:lkt_aoa`; it must not rewrite existing Projects or Sections. Ordinary editing must not change a Section's pinned model after learner activity begins.

Legacy project archives without model fields remain importable through documented naive and Project-to-template fallback rules.

## 12. Telemetry & Success Metrics
- Migration success: every existing Project and Section has a non-null `:naive` value after deployment.
- Compatibility success: existing creation, duplication, publication, and legacy archive tests remain green without behavior changes.
- Preservation success: LKT-AOA Project and template export/import round trips retain their exact model selections.
- Configuration success: absent variables load the specified defaults, while malformed or out-of-range explicit values fail startup and identify the offending environment variable.
- Operational monitoring should use existing application startup logs, import error reporting, and AppSignal error capture; no new high-cardinality production telemetry is required.

## 13. Risks & Mitigations
- Model selection is lost on a secondary creation path: inventory and test Project, template, Section, clone, duplicate, and import workflows; never rely on destination defaults for propagation.
- Legacy archives become invalid: treat missing or null model values as documented fallbacks while rejecting explicit unknown values.
- Published Sections read authoring-head parameters: require Section/publication resolution and tests that distinguish pinned and newer Revisions.
- Arbitrary JSON handling causes version drift: enforce one custom Ecto type with explicit version and resource-type dispatch.
- Activity edits leave stale part parameters: validate part IDs against the same Revision and remove parameters for deleted parts.
- Invalid environment settings silently alter predictions: validate at startup and fail rather than falling back when a variable is present but invalid.
- Future default rollout accidentally changes existing data: keep this migration and creation default naive and implement the future switch as a separate change.

## 14. Open Questions & Assumptions
### Open Questions
- None.

### Assumptions
- `gamma` initially defaults to `0.1`, and `rho` initially defaults to `1.0`; both must be finite and greater than or equal to `0.0`.
- `recency_decay` initially defaults to `0.9` and must remain in `(0.0, 1.0]`.
- `confidence_saturation` initially defaults to `3.0` and must be finite and greater than `0.0`.
- Missing LO and activity-part beta parameters use a runtime cold-start value of `0.0`; an explicitly stored zero remains a trained value.
- An activity part has one difficulty coefficient shared by every LO it targets.
- Project archives represent templates as Product records and may legitimately contain a template model value different from the Project value.
- Section model selection remains immutable through ordinary editing after learner activity begins.
- Deployment configuration history is the operational audit trail for global LKT-AOA settings until an explicit configuration-version audit feature is required.

## 15. QA Plan
- Automated validation:
  - Test migration backfill, database defaults, non-null constraints, and Ecto enum casting.
  - Test every creation and duplication propagation rule, including Project-to-template-to-Section inheritance and pinning.
  - Test project and Product JSON export fields, modern round trips, legacy fallbacks, divergent template values, and invalid archive values.
  - Test LO and activity parameter load/dump round trips, envelope dispatch, finite-number validation, resource-type validation, part validation, missing values, explicit zero, and unsupported versions.
  - Test Revision creation, duplication, publication, and Section-pinned resolution of parameter payloads.
  - Test startup configuration defaults, environment overrides, restart-loaded behavior, and invalid-value startup failures.
  - Run targeted `mix test` suites and `mix format`.
- Manual validation:
  - Inspect generated migrations for safe backfill and non-null sequencing.
  - Inspect an exported archive to confirm semantic strings appear in `_project.json` and every Product file.
  - Start the application once with defaults and once with representative overrides; verify effective configuration and actionable invalid-value failure output.
  - Confirm no normal authoring or delivery UI exposes LKT-AOA selection in this chunk.

## 16. Definition of Done
- [x] PRD sections complete
- [x] requirements.yml captured and valid
- [x] validation passes

# Learning Model: Data Model and Configuration

This work item establishes how Torus selects a learning model and stores its published parameters. It is the first of three implementation chunks derived from `docs/exec-plans/current/epics/learning_model_v2/informal.md`.

The intended outcome is a backward-compatible persistence foundation. This chunk does not calculate LKT-AOA state, process learner attempts, or change any displayed proficiency.

## Scope

This chunk includes:

- Persisting the selected learning model on projects and sections.
- Propagating that selection through project, template, and section creation.
- Persisting versioned learning-model parameters on resource revisions.
- Typed Elixir representations and validation for those parameters.
- Revision, publication, duplication, and cloning behavior.

This chunk excludes:

- `learning_state` and prior-evidence tables.
- Snapshot Worker integration.
- Proficiency calculations and Metrics dispatch.
- Author-facing model training or an internal retraining pipeline.
- Authoring Insights changes.

## Persisting the selected model

Both `Oli.Authoring.Course.Project` and `Oli.Delivery.Sections.Section` will have a `learning_model_version` field:

```elixir
field :learning_model_version,
  Ecto.Enum,
  values: [:naive, :lkt_aoa],
  default: :naive
```

The values describe behavior rather than release sequence:

- `:naive` is the existing first-attempt proficiency heuristic.
- `:lkt_aoa` is Logistic Knowledge Tracing with All Opportunities Averaged.

`learning_model_version` is independent of the existing `analytics_version` fields. Analytics storage/version selection must never be used to infer the learning model.

### Migration behavior

The migration adds `learning_model_version` to both `projects` and `sections`. Every existing project and section must become `:naive`. The database and Ecto schema defaults are also `:naive`.

The columns should be non-null after existing records have been populated. A missing model version would make runtime dispatch ambiguous and should not be treated as an implicit LKT-AOA selection.

### New-project default and staged rollout

The intended steady-state product behavior is that Projects created after LKT-AOA is fully deployed and enabled automatically begin with `learning_model_version: :lkt_aoa`. Their subsequently created templates and Sections then inherit `:lkt_aoa` through the normal propagation rules.

That future default switch is intentionally outside this data-model work. For this work item, newly created Projects must continue to receive `:naive`, just like migrated Projects. This keeps the persistence change behavior-neutral while the core calculation and usage chunks are incomplete.

Do not change `Oli.Authoring.Course.create_project/3`, its default attribute construction, the Project schema default, or the database default to select `:lkt_aoa` in this chunk. A later, deliberate rollout change will update the new-Project creation policy after the complete LKT-AOA path is production-ready. That later change must not rewrite existing Projects; it changes only the default assigned when a new Project is created.

### Propagation rules

Creation paths copy the source value explicitly:

| Creation path | Resulting value |
| --- | --- |
| Project → section | Copy the project's value |
| Project → template | Copy the project's value |
| Template → section | Copy the template's value |
| Project duplication | Copy the source project's value |
| Template or section duplication | Copy the source value unless the workflow explicitly overrides it |

Destination defaults are a safety net, not the propagation mechanism. Any code that builds a project, template, or section from another entity must include `learning_model_version` in its copied attributes.

Once created, a Section is pinned to its copied value. Changing its source project or template later must not implicitly change the Section.

Changing a Section after learner activity exists requires a dedicated migration/backfill workflow. A `:naive` section does not have guaranteed LKT-AOA state, and changing an active `:lkt_aoa` section to `:naive` would also change the meaning of historical dashboard values. Ordinary section editing should therefore treat this field as immutable after learner activity begins.

### Rollout safety

Adding the enum does not itself make LKT-AOA usable. Until the core and usage chunks are deployed, normal authoring and delivery interfaces should not expose a control that enables `:lkt_aoa`. Tests and administrative setup may set it explicitly.

The future switch making `:lkt_aoa` the automatic choice for newly created Projects belongs to that later rollout. It is not part of this chunk's migration or acceptance criteria.

## Project and template import/export

The Torus project archive must preserve `learning_model_version` across a complete export/import round trip. This applies independently to the Project and to every exported template (a template is represented in this pipeline by a blueprint Section and serialized as a `Product`). Importing an archive must reproduce the exported values; relying on the database default would silently change an `:lkt_aoa` project or template to `:naive`.

### Archive representation

Use the semantic enum strings in the existing JSON records:

- `_project.json` includes `"learningModelVersion": "naive"` or `"learningModelVersion": "lkt_aoa"`.
- Each `_product-<id>.json` includes the same `learningModelVersion` property for that template/blueprint.

The JSON property follows the camel-case convention already used by fields such as `welcomeTitle` and `certificateEnabled`. The serialized value is the stable enum value, not an ordinal, database integer, display label, or release number.

### Export changes

Update the project archive construction in `lib/oli/interop/export.ex`:

- `create_project_file/1` must add `learningModelVersion: project.learning_model_version` to `_project.json`.
- `create_product_file/2` must add `learningModelVersion: product.learning_model_version` to every exported Product record.

JSON encoding must produce `"naive"` and `"lkt_aoa"`. Add focused assertions to `test/oli/interop/export_test.exs` for both the project manifest and product JSON rather than relying only on a later database round-trip test. The existing product query already returns Section structs, so this field should not require another query or preload.

### Import changes

Update both ingest processors:

- In `lib/oli/interop/ingest/processor/project.ex`, read `project_details["learningModelVersion"]`, validate it, and pass the resulting value as `learning_model_version` in the attributes supplied to `Oli.Authoring.Course.create_project/3`.
- In `lib/oli/interop/ingest/processor/products.ex`, read `product["learningModelVersion"]` and include the validated value as `"learning_model_version"` in `new_product_attrs` before calling `Oli.Delivery.Sections.Blueprint.create_blueprint/5`.
- In `lib/oli/delivery/sections/blueprint.ex`, extend `build_blueprint_attrs/4` to copy `attrs["learning_model_version"]` into the new Section. This function currently constructs a whitelist of Section attributes, so passing the value from `Processor.Products` alone is insufficient.

Parsing should live behind one shared function so project and product ingestion cannot acquire different accepted values or fallback behavior. That function accepts only the external strings `"naive"` and `"lkt_aoa"` and returns their Ecto enum atoms. An explicitly supplied but unknown value is an ingest error; it must not silently select `:naive`.

### Backward compatibility and precedence

Older archives do not contain `learningModelVersion` and must remain importable:

- A missing project value resolves to `:naive`.
- A missing product value inherits the newly imported Project's `learning_model_version`. This preserves the Project → template creation rule and also handles an archive produced during a transitional period in which the project field exists but product fields do not.
- A valid value present on a Product takes precedence and is preserved exactly. This is necessary for a faithful round trip if an existing template has a value different from its Project.
- An explicit JSON `null` should be treated like a missing value for compatibility. Any other unknown type or value is invalid.

Do not derive a Product's model from the source Project during export. Export the value persisted on the blueprint Section; import fallback to the Project is only for legacy archives that omitted the Product property.

### Required coverage

The interop test suite must prove:

- Export writes the project and template values into their respective JSON files.
- Exporting and re-importing an `:lkt_aoa` project preserves `:lkt_aoa` on the imported Project.
- The same round trip preserves the value on every imported template/blueprint.
- A Product value different from the Project value is preserved rather than overwritten during import.
- A legacy archive with neither property imports both the Project and its templates as `:naive`.
- A legacy Product without the property inherits an explicitly exported Project value.
- Unsupported explicit values fail ingestion with a useful validation error.

## Revision parameter storage

Learning-model parameters live on resource revisions so they participate in Torus authoring and publication semantics:

- Parameter changes create unpublished revisions.
- Published sections continue using their resolved published revisions.
- Publication provides an audit boundary for parameter changes.
- Course and activity duplication carry parameters with their revisions.

Revision will have a dedicated JSONB field:

```text
learning_model_parameters
```

The existing generic `Revision.parameters` map is not reused. Learning-model parameters need an independent contract and evolution path.

The field is not named after beta coefficients because later models may require different parameter families.

The field may be absent on naive-model revisions and on LKT-AOA revisions that have not yet received trained parameters. Selecting `:lkt_aoa` on a project or section does not imply that every objective and activity part already has a learned coefficient; missing values use the documented cold-start behavior at runtime.

## Parameter envelope

Stored JSON is self-describing and separates the algorithm version from the serialization format version.

An LO revision uses:

```json
{
  "schema_version": 1,
  "model": "lkt_aoa",
  "model_version": 2,
  "parameter_type": "learning_objective",
  "payload": {
    "beta_lo": -0.42
  }
}
```

An activity revision stores one difficulty parameter per activity part:

```json
{
  "schema_version": 1,
  "model": "lkt_aoa",
  "model_version": 2,
  "parameter_type": "activity",
  "payload": {
    "parts": {
      "part-1": {
        "beta_difficulty": -0.18
      },
      "part-2": {
        "beta_difficulty": 0.37
      }
    }
  }
}
```

`model_version` identifies the learning algorithm. `schema_version` identifies the JSON representation and may change without changing the underlying algorithm.

Activity part IDs are strings and refer to parts in that same activity revision. Difficulty is per part, not per activity and not per part/LO pair. If a part targets multiple LOs, every applicable prediction uses the same part difficulty.

Each part maps to an object instead of directly to a float. This allows a later parameter schema to add fields such as discrimination or guessing without replacing the top-level storage design.

## Typed Elixir boundary

Application code should not interpret the JSONB value as an arbitrary map. A custom Ecto type will load and dump explicit versioned structs, conceptually:

```text
Oli.LearningModel.Parameters
Oli.LearningModel.Parameters.Type

Oli.LearningModel.V2.LearningObjectiveParameters
Oli.LearningModel.V2.ActivityParameters
Oli.LearningModel.V2.PartParameters

Oli.LearningModel.V3.LearningObjectiveParameters
Oli.LearningModel.V3.ActivityParameters
```

The custom type dispatches using `model`, `model_version`, and `parameter_type`. Unsupported versions return a controlled error; they must never be silently interpreted as v2.

The type and revision changeset must validate:

- Supported model and schema versions.
- Agreement between `parameter_type` and the Revision resource type.
- Required learning-objective or activity payload fields.
- Finite numeric values.
- Activity part keys that exist in the same revision.
- Removal of stale part parameters when parts are deleted.

Missing and zero are distinct:

- A missing learning-objective value or part entry means no trained parameter is available.
- Runtime LKT-AOA use `0.0` as its cold-start fallback.
- An explicitly stored `0.0` is a legitimate learned value and must not be labeled untrained.

Newly added activity parts begin without trained parameters. Deleted parts must not remain in the active parameter payload.

## Copying and publication requirements

`learning_model_parameters` must be included anywhere Revision fields are copied, particularly:

- `Oli.Resources.create_revision_from_previous/2`.
- Activity duplication and adaptive duplication.
- Project/package duplication.
- Publication and published-resource resolution.
- Import/export paths that are expected to preserve learning-model configuration.

The parameter payload belongs to the exact Revision. Consumers must use the revision resolved for the section/publication rather than the latest authoring revision.

## Future model versions

The one JSONB column remains stable when v3 or v4 structures are introduced. New decoders and structs coexist with v2 structures so historical revisions retain their original meaning.

Parameter upgrades create new revisions; published parameter JSON is never rewritten in place.

The initial contract stores one active learning-model parameter set per Revision. Running production and shadow models simultaneously is outside this chunk. If required later, the envelope or a related structure must support multiple named sets explicitly.

## Application configuration

The coefficients that apply globally to LKT-AOA are application settings, not Project, Section, Revision, or learner-state data:

- Opportunity-count weight (`gamma`), initially `0.1`.
- Recency weight (`rho`), initially `1.0`.
- Recency decay factor (`recency_decay`), initially `0.9`.
- Confidence saturation constant (`confidence_saturation`, represented as `k` in the formula), initially `3.0`.

Configure them together under one application environment entry, conceptually:

```elixir
config :oli, :lkt_aoa,
  gamma: 0.1,
  rho: 1.0,
  recency_decay: 0.9,
  confidence_saturation: 3.0
```

Each setting has an environment-variable override:

| Application key | Environment variable |
| --- | --- |
| `gamma` | `LKT_AOA_GAMMA` |
| `rho` | `LKT_AOA_RHO` |
| `recency_decay` | `LKT_AOA_RECENCY_DECAY` |
| `confidence_saturation` | `LKT_AOA_CONFIDENCE_SATURATION` |

Load these overrides in `config/runtime.exs`, so an operator can change them through deployment environment configuration without rebuilding the release. Values are read and validated when the application starts. Changing an environment variable has no effect on an already running node and requires a restart; there is no UI, database editor, per-Project override, or other mechanism for changing these settings dynamically at runtime.

Every setting must have an application-owned default when its environment variable is absent. The initial defaults are `gamma: 0.1`, `rho: 1.0`, `recency_decay: 0.9`, and `confidence_saturation: 3.0`.

These are intentionally conservative cold-start values. `gamma: 0.1` gives opportunity count a modest positive effect, `rho: 1.0` applies the recency logit without amplification or attenuation, and `confidence_saturation: 3.0` produces useful early confidence growth without saturating after only one or two unique activity parts. They remain deployment-configurable so fitted values can replace them later without a code change.

Defaulting applies only when a variable is absent. A present but malformed or out-of-range value must fail application startup with an error that names the environment variable. It must not silently fall back. Parsing and validation should enforce:

- All four values are finite numbers.
- `gamma` and `rho` are greater than or equal to `0.0`.
- `recency_decay` is greater than `0.0` and no greater than `1.0`.
- `confidence_saturation` is greater than `0.0`.

Expose the parsed values through one typed learning-model configuration module rather than scattering `Application.get_env/3` calls or environment reads through calculation code. A bulk proficiency operation resolves the configuration once and applies the same values to every transition in that batch. These global values must not be copied into each `learning_state` row.

An environment change affects new transitions after the restarted deployment; it does not recompute historical learner state or prior AOA values. Deployment configuration history is therefore the operational audit trail for these global settings. If Torus later requires exact per-transition reproducibility across configuration changes, that should introduce an explicit configuration-version audit mechanism rather than duplicating the coefficients across learner-state rows.

The authoring mechanism for uploading externally trained per-LO and per-part beta parameters remains a separate workflow decision. This chunk provides their Revision persistence and validation boundary; it does not need to build an internal training pipeline.

## Verification boundary

This chunk is complete when:

- Existing projects and sections migrate to `:naive`.
- Every supported creation/duplication path preserves the model selection.
- Project → template → section propagation is covered by tests.
- Project export/import preserves the Project and every template's model selection, including legacy-archive fallback behavior.
- Versioned learning-objective and activity parameter payloads round-trip through Ecto.
- Invalid payloads and mismatched resource types are rejected.
- Revision creation, duplication, and publication preserve parameter payloads.
- LKT-AOA application settings have validated defaults and environment overrides that are loaded at application startup.
- No existing section's proficiency behavior changes merely because these fields exist.

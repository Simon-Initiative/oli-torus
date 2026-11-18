# Adaptive activity JSON Schema

All 17 activity manifests under `assets/src/components/activities` now have explicit model validation and a strict export schema. Adaptive is selected by its exact manifest ID:

```elixir
Oli.Validation.validate_activity_schema("oli_adaptive", model)
# :ok | {:error, errors}
```

The model schema is `priv/schemas/v0-1-0/adaptive.schema.json`. The existing `adaptive-activity.schema.json` now composes that model with the generic Activity envelope, requires exact `subType: "oli_adaptive"`, and rejects unknown envelope fields.

Validation remains opt-in. No save, ingest, rendering, or legacy domain validation calls were added. JSV remains encapsulated in `Oli.Utils.JSONValidation`; graphs are cached per schema registry revision and reused during subsequent validation.

## Sources and authored profiles

Adaptive has more than one client authoring path. Sources include:

- `assets/src/components/activities/adaptive/schema.ts` and `utils.ts`: generic activity factory, optional nested `content`, root `custom` and `partsLayout`, generic parts, and factory `outcomes`.
- `assets/src/components/activities/types.ts`: generic parts, content, responses, and `PartComponentDefinition`.
- `assets/src/apps/authoring/store/activities/templates/activity.ts` and `actions/saveActivity.ts`: advanced screen templates, identifier-only authoring parts, rules, flowchart data, and evaluation-variable names.
- `assets/src/apps/delivery/store/features/activities/slice.ts`, `assets/src/apps/authoring/types.ts`, and `assets/src/adaptivity/capi.ts`: rule, condition, and action fields.
- `assets/src/apps/authoring/components/Flowchart/paths/path-types.ts`, path factories, and rule generators: flowchart variants and actual generated rules.

The root requires `authoring`. It supports optional root `custom`, root `partsLayout`, and the optional nested `content` containing `custom` and/or `partsLayout`, plus shared model metadata. These layouts can coexist, matching the client interface and delivery fallback. The schema does not choose between them or migrate either representation.

Authoring requires `parts`. Generic factory models also require `transformations` and `previewText`; advanced screen models with a `rules` array may omit those fields, as the actual screen template does. Supported additional authoring fields are `flowchart` and string-array `variablesRequiredForEvaluation`. Unknown authoring fields are rejected.

## Parts and shared rich content

Authoring parts dispatch structurally between:

- Generic parts containing `responses`, using the existing shared constraints for ID, responses, hints, explanations, scoring, and other common fields.
- Advanced screen part identifiers requiring string `id`, `type`, `owner`, and boolean `inherited`, with optional `gradingApproach` and numeric `outOf`.

Both variants are closed. A generic part may additionally contain the factory's `outcomes`: closed ID/rule-array/action-array wrappers, with the factory's `StateUpdateActionDesc` and object `update` payload. Outcome rule entries and update internals remain opaque; no rule evaluation is performed.

Generic hints, explanations, and response feedback reference the same shared rich-content definitions as Basic Pages. No rich-content schema is copied. Structured response match configurations reuse the shared wrapper, with the entire `matchConfig.math` object remaining an opaque leaf.

## Component payloads

Layout entries are closed objects requiring string `id`, string `type`, and object `custom`. The client defines `custom` as `Record<string, any>` or an index-signature component model. Its contents are intentionally opaque, including component-specific rich text, scripts, configuration, and mathematical expressions. Screen-level `custom` is also an open object record.

Component type remains a string, matching `PartComponentDefinition`/`AnyPartComponent`, rather than the stale list of Janus names in the older history schema. Registration/existence checks are domain concerns. Individual Janus component configuration schemas are not expanded into this activity schema.

## Rules, conditions, actions, and flowcharts

Rules are closed typed objects with required `id`, `name`, `disabled`, `default`, `correct`, `conditions`, and `event`. Optional `priority`, `additionalScore`, and `forceProgress` are typed. Although the delivery interface declares priority, actual authoring rule factories omit it, so the schema permits omission.

Condition groups contain `all` and/or `any` arrays and optional string `id`. Nested conditions dispatch between groups and fact comparisons. Comparisons require string `fact`, string `operator`, and an opaque JSON `value`, with supported optional ID, type number, path, priority, and parameter record. This checks condition structure without interpreting expression values or restricting operators to the current runtime registry.

Events require a type string and params containing an actions array. Action type dispatch validates the four client variants: `navigation`, `mutateState`, `feedback`, and `activationPoint`. Their parameter objects are closed and typed. State-mutation values remain opaque. Feedback actions contain a screen payload with object `custom` and a layout array; component custom values stay opaque there too.

Flowchart wrappers require `screenType`, `paths`, and `templateApplied`. Each path validates its common fields and the required/allowed fields for its declared path type. Screen type remains a string because the source derives its alias from a mutable `string[]`. No destinations, component references, priorities, or progression semantics are resolved.

## Legacy history schema

`priv/schemas/v0-1-0/adaptive-activity-content.schema.json` remains unchanged. Existing revision-history code uses that older content schema, whose permissive legacy contract differs from the new opt-in model validator. Keeping it separate prevents this work from tightening a history validation boundary.

## Deferred domain checks

Validation does not execute scripts/actions, evaluate rules/expressions, check component registrations, resolve owners/IDs/destinations/facts, require unique IDs, enforce progression or scoring semantics, or enforce readiness/cardinality of arrays. It does not validate every Janus custom payload. Typed outer wrappers and explicitly opaque values are the intended boundary.

## Verification

`assets/test/activity_schemas/adaptive_schema_test.ts` validates actual generic and advanced templates, generated rule/feedback helpers, and flowchart path factories using AJV. Serialized fixtures in `test/support/fixtures/adaptive_models.json` are checked against those factories.

`test/oli/utils/adaptive_schema_test.exs` validates the same fixtures using cached JSV graphs. It covers shared Basic Page elements in generic rich-content slots, both part variants, rule/action/path dispatch, strict fields, opaque values nested 1,000 levels deep, exact export dispatch, concurrent reuse, and the separate legacy history schema.

The manifest-completeness checks in `test/oli/utils/remaining_activity_schemas_test.exs` and `assets/test/activity_schemas/remaining_activities_schema_test.ts` now include Adaptive and cover all 17 activities.

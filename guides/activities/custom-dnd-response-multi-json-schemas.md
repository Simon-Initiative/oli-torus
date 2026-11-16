# Custom DND and Response Multi JSON Schemas

These schemas validate the authored models declared in `assets/src/components/activities/custom_dnd/schema.ts` and `assets/src/components/activities/response_multi/schema.ts`, including inherited activity/part fields and actual factory/editor output.

| Activity | Explicit type slug | Model schema | Export schema |
| --- | --- | --- | --- |
| Custom DND | `oli_custom_dnd` | `custom-dnd.schema.json` | `custom-dnd-activity.schema.json` |
| Response Multi | `oli_response_multi` | `response-multi.schema.json` | `response-multi-activity.schema.json` |

All schemas are in `priv/schemas/v0-1-0/`. Export envelopes require the exact subtype and reject unknown fields.

```elixir
Oli.Validation.validate_activity_schema("oli_custom_dnd", model)
Oli.Validation.validate_activity_schema("oli_response_multi", model)
# :ok | {:error, errors}
```

The API remains opt-in. Existing saves, ingest, and legacy validation boundaries are unchanged. `Oli.Utils.JSONValidation` encapsulates JSV and caches each built graph per schema registry revision for repeated validation.

## Shared components

Both activities reuse the same Basic Page rich-content definitions through `activity-components.schema.json`. Stem, hints, response feedback, and optional explanations share those references. Response Multi choices also use the shared choice component. No rich-content definitions are copied; the existing rich-node extension policy is unchanged.

Parts reuse `part-with-match-config`. Response rules remain strings; supplied match-config wrappers are strictly typed, and the entire `matchConfig.math` object is opaque. Its expression internals and embedded `$ref` data are not interpreted. Responses require a legacy rule, a structured match configuration, or both; all supplied fields must be structurally valid.

## Custom DND

Required root fields are `stem`, `height`, `width`, `layoutStyles`, `targetArea`, `initiators`, and `authoring`. Dimensions, CSS, target-area HTML, and initiator HTML are strings, matching the client model. The schema does not parse or render those strings.

The closed authoring object requires `parts`, `transformations`, and string `previewText`. Generic part fields and inherited activity metadata use existing shared definitions. Unknown fields, including unrelated input/choice/scoring fields and an authoring version, are rejected.

## Response Multi

Required root fields are `stem`, `choices`, `inputs`, `submitPerPart`, `multInputsPerPart`, and `authoring`. The two submission/grouping flags are booleans; optional `customScoring`, `scoringStrategy`, and inherited metadata are supported.

The client imports `MultiInput` directly from the Multi Input activity. Accordingly, the schema references the existing Multi Input property schemas, including its tagged input contract, rather than copying those definitions. This preserves all five input types (`dropdown`, `text`, `numeric`, `math`, `math_expression`), size values, per-input item settings, and the documented compatibility allowance for string-array `choiceIds` retained on fill-in inputs after dropdown transitions. Dropdowns require `choiceIds` and reject `itemConfig`.

Authoring requires `parts`, `targeted`, `transformations`, and `previewText`. Its optional contributed `responses` have a different shape from Multi Input: each is a closed object requiring string `user_name` and `text`. The schema deliberately defines that shape separately. Grouped inputs, part `targets`, response `matchStyle`, and compound rule strings use the inherited types.

Response Multi's current editor represents its `math_expression` input choice with legacy math rules. The schema supports those actual outputs as well as structured match configurations and optional item settings allowed by its imported interfaces. It does not add expression evaluation or change the editor's math behavior.

See `guides/activities/multi-input-json-schema.md` for the shared input contract and `guides/activities/upload-short-answer-json-schemas.md` for the opaque math boundary.

## Deferred domain checks

Validation does not parse/sanitize HTML or CSS, check dimensions, resolve drop targets/initiators, evaluate or parse rules/expressions, resolve input/choice/part IDs, enforce unique IDs, or check targeted association integrity. It does not enforce grouping consistency, submission/scoring semantics, or array readiness/cardinality. Empty arrays remain structurally valid editing states. Existing rendering, evaluation, and authoring behavior is unchanged.

## Verification

`assets/test/activity_schemas/custom_dnd_response_multi_schema_test.ts` validates real factories, Custom DND edits and part actions, all Response Multi input transitions, and input grouping with AJV. It compares serialized output with `test/support/fixtures/custom_dnd_response_multi_models.json`.

`test/oli/utils/custom_dnd_response_multi_schema_test.exs` validates the same fixtures with the cached backend API and JSV. Tests cover all shared Basic Page factory examples in rich-content slots, strict wrappers, required/typed fields, exact export dispatch, inherited metadata, concurrent validation, deferred domain integrity, and opaque math payloads nested 1,000 levels deep.

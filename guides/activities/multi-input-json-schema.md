# Multi Input JSON Schema

The authored Multi Input model is validated by `priv/schemas/v0-1-0/multi-input.schema.json`. The strict export envelope is `priv/schemas/v0-1-0/multi-input-activity.schema.json`, with the exact subtype `oli_multi_input`.

```elixir
Oli.Validation.validate_activity_schema("oli_multi_input", model)
# :ok | {:error, errors}
```

This API is opt-in. Existing save, ingest, and legacy validation boundaries are unchanged. `Oli.Utils.JSONValidation` encapsulates JSV; the schema graph is built once per schema registry revision and reused for subsequent validations.

## Source and reuse

The source of truth is `assets/src/components/activities/multi_input/schema.ts`, its inherited interfaces in `assets/src/components/activities/types.ts`, and the factory, actions, and legacy math conversion used by the editor.

Stem, choices, hints, response feedback, and explanations reference `activity-components.schema.json`, which references the same rich-content schema as Basic Pages. No rich-content definitions are copied. Inline `input_ref` nodes use that existing content dispatcher. Shared rich-node extension handling is unchanged; activity model, input, authoring, part, response, and export wrappers reject unknown fields.

Multipart responses reuse `part-with-match-config` and `response-with-match-config`. The entire `response.matchConfig.math` value is an opaque object leaf, exactly as in Short Answer. Its expression internals, nested JSON, future fields, and ordinary `$ref` data are not inspected. The enclosing version/type wrapper remains strict. Responses may use a legacy `rule`, a structured `matchConfig`, or both; any supplied field must be structurally valid.

Per-input `itemConfig` references the existing shared math settings in `short-answer-config.schema.json`. These authoring settings are typed separately from the opaque math expression payload. See `guides/activities/upload-short-answer-json-schemas.md` for that boundary.

## Supported structure

Required root fields are `stem`, `choices`, `inputs`, `submitPerPart`, and `authoring`. Optional inherited metadata, `customScoring`, and `scoringStrategy` are supported.

Each input requires string `id` and `partId`, and an `inputType` of `dropdown`, `text`, `numeric`, `math`, or `math_expression`. Optional `size` is `small`, `medium`, `large`, or `100pct`.

Dropdowns require a string-array `choiceIds` and do not accept `itemConfig`. Fill-in inputs accept optional `itemConfig`. Existing `setInputType`, `setQuestionType`, and legacy conversion paths retain previous dropdown `choiceIds` when switching to a fill-in input; the schema intentionally accepts that known string-array field on fill-in inputs for compatibility. Delivery-only `options` are not part of the authored model and are rejected.

Authoring requires `parts`, `targeted`, `transformations`, and `previewText`. Unlike single-response activities, there is no single-part limit. Optional authoring `responses` contain closed objects with required `users` (string array), `text`, `type`, `part_id` (strings), and `count` (number).

## Deferred domain checks

Validation does not evaluate rules or expressions, resolve input references, require matching input/part/choice IDs, check targeted associations against existing responses, enforce unique IDs, or enforce readiness/cardinality of arrays. Empty arrays remain structurally valid editing states. Scoring semantics, numeric bounds, and submission policy are also outside this schema.

## Verification

`assets/test/activity_schemas/multi_input_schema_test.ts` validates real factories, input/question-type action transitions, legacy math conversion, strict wrappers, and opaque math using AJV. `test/support/fixtures/multi_input_models.json` captures serialized factory/action output and is checked against those factories by the client tests.

`test/oli/utils/multi_input_schema_test.exs` validates the same fixtures through the cached backend API using JSV. It exercises every shared Basic Page factory example in all five content locations, strict fields, multipart and export dispatch, item settings, concurrent reuse, and an opaque math payload nested 1,000 levels deep.

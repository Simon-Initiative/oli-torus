# Image Coding JSON Schema

The authored Image Coding model is validated by `priv/schemas/v0-1-0/image-coding.schema.json`. The strict export envelope is `priv/schemas/v0-1-0/image-coding-activity.schema.json`, with the exact subtype `oli_image_coding`.

```elixir
Oli.Validation.validate_activity_schema("oli_image_coding", model)
# :ok | {:error, errors}
```

This API is opt-in. Existing save, ingest, and legacy validation boundaries are unchanged. `Oli.Utils.JSONValidation` encapsulates JSV; the schema graph is built once per schema registry revision and reused on subsequent validations.

## Source and shared components

The source of truth is `assets/src/components/activities/image_coding/schema.ts`, its inherited interfaces in `assets/src/components/activities/types.ts`, and the factory/editor actions.

Stem, root-level feedback, hints, optional explanations, and generic response feedback reuse `activity-components.schema.json`. Its rich-content references use the same definitions and dispatcher as Basic Pages, without copying element definitions. The existing rich-node extension policy is unchanged; authored wrappers reject unknown fields.

Image Coding creates an empty `authoring.parts[0].responses` array. The shared `part-with-match-config` component accepts this factory state and supports the inherited generic `Part`/`Response` fields. If a response provides a structured `matchConfig`, its wrapper remains strict and the whole `matchConfig.math` object remains an opaque leaf, as in Short Answer and Multi Input.

## Authored structure

Required root fields:

- `stem`: shared rich-content object.
- `isExample`: boolean.
- `starterCode`, `solutionCode`, `regex`: strings.
- `resourceURLs`: string array.
- `tolerance`: number.
- `feedback`: array of shared feedback content objects. The factory supplies incorrect/correct feedback in score order.
- `authoring`: closed object requiring `parts` and string `previewText`.

Inherited model metadata uses the existing shared definitions. There is no authoring `version`, `transformations`, or `targeted` field in the client interface; those fields are rejected. Output, canvas state, and other delivery data are not authored model fields.

## Existing tolerance mismatch

The tolerance input in `assets/src/components/activities/image_coding/ImageCodingAuthoring.tsx` passes `e.target.value` directly to `ICActions.editTolerance`, despite both the action and model declaring a number. The schema follows the declared numeric type and rejects the string emitted by that handler. This mismatch is covered by a regression test and should be addressed before enforcing validation on saves from that UI. No production UI behavior or coercion was changed here.

## Deferred domain checks

Validation does not compile or execute code, compile/test the regex, fetch resources, impose URL formats or schemes, check resource uniqueness, constrain tolerance bounds, enforce feedback count/order, or require a single part. It does not evaluate generic response rules, enforce unique IDs, or check target integrity. Empty arrays remain structurally valid editing states; the delivery evaluator's readiness requirements are separate domain concerns.

## Verification

`assets/test/activity_schemas/image_coding_schema_test.ts` validates actual factory output and code, stem, tolerance, regex, resource, feedback, and hint actions using AJV. Serialized factory/action output is compared with `test/support/fixtures/image_coding_models.json`.

`test/oli/utils/image_coding_schema_test.exs` validates those same fixtures with the cached backend API using JSV. It covers all shared Basic Page factory examples in every rich-content slot, legacy content envelopes, strict wrappers, required and typed fields, empty default responses, inherited metadata, concurrent reuse, export dispatch, and an opaque math payload nested 1,000 levels deep.

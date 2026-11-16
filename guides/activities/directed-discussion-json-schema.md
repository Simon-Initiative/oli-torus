# Directed Discussion JSON Schema

The authored Directed Discussion model is validated by `priv/schemas/v0-1-0/directed-discussion.schema.json`. The strict export envelope is `priv/schemas/v0-1-0/directed-discussion-activity.schema.json`, with the exact subtype `oli_directed_discussion`.

```elixir
Oli.Validation.validate_activity_schema("oli_directed_discussion", model)
# :ok | {:error, errors}
```

This API is opt-in. Existing save, ingest, and legacy validation boundaries are unchanged. `Oli.Utils.JSONValidation` encapsulates JSV; the graph is built once per schema registry revision and reused for subsequent validation.

## Source and shared components

The source of truth is `assets/src/components/activities/directed-discussion/schema.ts`, its inherited interfaces in `assets/src/components/activities/types.ts`, and the factory/actions used by the editor.

Stem, hints, response feedback, and explanations use the shared content components in `activity-components.schema.json`. These reference the same rich-content schema and dispatcher used by Basic Pages, without copying content-element definitions. The existing rich-node extension policy is unchanged; authored wrappers reject unknown fields.

Generic parts use the shared `part-with-match-config` definition, preserving the inherited client `Part` and `Response` structure. If a response supplies a `matchConfig`, its wrapper is strict and its entire `math` object is an opaque leaf, as in Short Answer and Multi Input. No expression JSON internals are inspected. Responses require a legacy `rule`, a structured `matchConfig`, or both, and any supplied field must be structurally valid.

## Authored structure

Required root fields:

- `stem`: shared rich-content object.
- `participation`: a closed object requiring numeric `minPosts`, `maxPosts`, `minReplies`, `maxReplies`, and `maxWordLength`.
- `maxWords`: number, retained separately because it is declared in the client interface and emitted by the factory.
- `authoring`: a closed object requiring literal `version: 1`, `parts`, and `transformations`.

Inherited model metadata is supported through the existing shared definitions. Generic part fields, hints, feedback, optional explanations, and transformations use their existing contracts.

Directed Discussion does not declare `previewText`, `targeted`, or contributed `responses` in its authoring block, so those fields are rejected. The connected stem editor calls the generic preview-text update action, but that action does not create a missing preview-text field; the actual serialized result is covered by client/backend fixtures. Discussion posts, replies, search results, and participation progress belong to runtime delivery data and are not accepted as authored model fields.

## Deferred domain checks

The schema checks numeric types, without imposing integer/nonnegative limits, min/max relationships, or the semantics of a zero maximum. It does not reconcile `maxWords` with `participation.maxWordLength`, evaluate rules or expressions, enforce unique part IDs or target integrity, or enforce readiness/cardinality of part, response, and hint arrays. Existing editor normalization of participation settings is unchanged.

## Verification

`assets/test/activity_schemas/directed_discussion_schema_test.ts` validates real factory output, participation and stem actions, strict wrappers, and export dispatch using AJV. It compares actual serialized output with `test/support/fixtures/directed_discussion_models.json`.

`test/oli/utils/directed_discussion_schema_test.exs` validates the same fixtures using the cached backend API and JSV. Tests cover every shared Basic Page factory example in all four content locations, legacy content envelopes, malformed content, required numeric fields, authoring versions, strict wrappers, inherited metadata, concurrent reuse, and opaque math nested 1,000 levels deep.

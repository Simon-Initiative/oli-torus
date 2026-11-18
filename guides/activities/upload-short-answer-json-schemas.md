# File Upload and Short Answer JSON schemas

Strict Draft 7 schemas cover the authored models and Activity export envelopes.
They reuse the generic validation facade, cached schema graphs, metadata, parts,
responses, and Basic Page rich content established for the other activities.
There are no new automatic save, ingest, delivery, or MCP validation boundaries.

## Dispatch and source contracts

| Activity slug | Model schema | Export schema |
| --- | --- | --- |
| `oli_file_upload` | `file-upload.schema.json` | `file-upload-activity.schema.json` |
| `oli_short_answer` | `short-answer.schema.json` | `short-answer-activity.schema.json` |

All schemas live in `priv/schemas/v0-1-0/`. File Upload follows
`assets/src/components/activities/file_upload/schema.ts` and its factory/actions.
Short Answer follows `assets/src/components/activities/short_answer/schema.ts`,
its factories/actions and save conversion, and
`assets/src/data/activities/model/match.ts` for item/match configuration envelopes.

```elixir
Oli.Validation.validate_activity_schema("oli_file_upload", model)
Oli.Validation.validate_activity_schema("oli_short_answer", model)
# :ok | {:error, [{message, json_pointer_path}, ...]}

root = Oli.Utils.SchemaResolver.resolve("short-answer-activity.schema.json")
Oli.Utils.JSONValidation.validate(root, exported_activity)
```

The explicit slug selects the model validator. Export schemas require the exact
`subType`; submitted `activityType` metadata cannot redirect dispatch. Unknown
fields on models, authoring, components, configurations, and exports are rejected,
with the opaque math object exception described below. Shared Basic Page element
extension compatibility remains unchanged.

## File Upload

The model requires a stem, `fileSpec`, and single-part authoring. `fileSpec`
requires string `accept` and numeric `maxCount`; numeric `maxSizeInBytes` is
optional. An empty accept string is the factory's "Any" state. The default
manual-grading model, hints, explanation, and dynamic transformations are supported.

Numeric settings deliberately follow the client `FileSpec` type without imposing
integer, positivity, allowed-extension, MIME, byte-limit, or grading policies.
Those are separate domain/security enforcement concerns. The existing
`FileSpecConfiguration` text-input handler can forward a string for `maxCount`;
that value does not satisfy the declared numeric contract. This change neither
coerces it nor changes UI behavior; address that handler separately before
adding enforcement to its save path.

## Short Answer

The schema covers all declared input types: `text`, `numeric`, `textarea`, `math`,
`math_expression`, and `vlabvalue`. Optional `submitAndCompare`, item configuration,
and contributed response examples (`users` string array and `text`) are typed.
The stem, hints, response feedback, and explanation share the same modern/legacy
rich-text definitions as Basic Pages and the other supported activities.

`short-answer-config.schema.json` validates the version-1 item-config wrapper,
its known subtype enum, and optional question settings: numeric options, variable
names/domains and bounds, unit policy, and sampling fields. These are structural
settings checks, not expression evaluation, interval consistency, valid-unit
lookup, or numeric-range/domain-policy checks.

## Math expression boundary: an opaque leaf

The expression specification is stored at:

```text
model.authoring.parts[].responses[].matchConfig.math
```

That entire object is a leaf. Its schema is only `type: object` plus a description.
It has no declared properties, child schemas, references, or recursive AST checks.
Unknown/future math keys and arbitrary nested expression representations remain
valid there; even `$ref` inside the submitted payload is ordinary data. The schema
never parses, normalizes, evaluates, or traverses the expression representation.

The containing match envelope remains strict:

- `version` must be `1`.
- `type: "math_expression"` requires the opaque `math` object.
- `type: "always"` has no `math` field.
- Misspelled/unknown wrapper fields are rejected.

Item settings are outside the opaque expression object and remain structurally
validated. This distinction keeps expression internals owned by the math subsystem
without making the activity/configuration envelope permissive.

## Shared response variants and runtime reuse

`activity-components.schema.json` adds `response-match-config`,
`response-with-match-config`, and `part-with-match-config` for these models.
The extended response requires ID, numeric score, and feedback plus a legacy
string `rule`, a structured `matchConfig`, or both. A supplied invalid field is
rejected even when the alternative is present. This supports the factory's empty
fallback rule and structured responses that omit `rule`, as documented by the
client response type and supported by the backend parser.

The variants reuse property schemas from the existing closed response/part
components instead of extending closed objects through `allOf` or copying their
rich-content definitions. Empty response arrays remain structurally valid for
manual/editing states; publish readiness is deferred. The existing MCQ, Ordering,
CATA, and Likert component contracts are unchanged.

Named validators cache complete built graphs by registry revision. Both new
activities reuse compiled rich-content references; there is no runtime schema
read, generation, or graph reconstruction per submitted field. The math leaf
adds no recursive expression-validation cost.

## Verification and rollout limits

- `assets/test/activity_schemas/upload_short_answer_schema_test.ts` checks real
  serialized factories, all input/question-type actions, import helpers, legacy
  math/numeric save conversion, file configuration actions, strict fields, export
  dispatch, settings, and the opaque math boundary using AJV.
- `test/support/fixtures/upload_short_answer_models.json` shares deterministic
  File Upload, Short Answer, and algebraic-expression factory models with server tests.
- `test/oli/utils/upload_short_answer_schema_test.exs` checks those models with
  JSV, all Basic Page examples in each content slot, malformed content, strict
  wrappers/configurations, rule/match alternatives, legacy Short Answer exports,
  and deeply nested arbitrary math JSON that must remain opaque.

Existing activity and shared-content regressions remain part of verification.
Fixture/client compatibility is not a production corpus guarantee. Domain checks,
file-upload enforcement, rule/expression correctness, and automatic validation
rollout remain separate work.

Multi Input uses the same match-config and math-settings components. See `guides/activities/multi-input-json-schema.md`.

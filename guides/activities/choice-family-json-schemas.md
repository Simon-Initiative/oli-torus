# Ordering, Check All That Apply, and Likert JSON schemas

These authored activity models and their Activity export envelopes have strict
Draft 7 schemas. They use the same generic validation facade, cached graph builds,
activity components, and shared Basic Page rich-text definitions as MCQ. No new
save, ingest, delivery, or MCP validation boundary is enabled.

File Upload and Short Answer companion support is documented in
`guides/activities/upload-short-answer-json-schemas.md`.

## Explicit dispatch

| Activity slug | Authored model schema | Export schema |
| --- | --- | --- |
| `oli_ordering` | `ordering.schema.json` | `ordering-activity.schema.json` |
| `oli_check_all_that_apply` | `check-all-that-apply.schema.json` | `check-all-that-apply-activity.schema.json` |
| `oli_likert` | `likert.schema.json` | `likert-activity.schema.json` |

Schemas live in `priv/schemas/v0-1-0/` and are registered with `SchemaResolver`.

```elixir
Oli.Validation.validate_activity_schema("oli_ordering", model)
Oli.Validation.validate_activity_schema("oli_check_all_that_apply", model)
Oli.Validation.validate_activity_schema("oli_likert", model)
# :ok | {:error, [{message, json_pointer_path}, ...]}

root = Oli.Utils.SchemaResolver.resolve("likert-activity.schema.json")
Oli.Utils.JSONValidation.validate(root, exported_activity)
```

The slug argument selects the model schema; each export schema requires its exact
`subType`. Model metadata such as `activityType` cannot change dispatch. V2 Ordering
and CATA have very similar structural shapes: JSON shape alone cannot establish
which activity was intended, so callers must supply the correct type explicitly.
Unknown slugs return an error; schemas are not guessed from `choices` or rules.

## Client source of truth

| Surface | Client sources |
| --- | --- |
| Ordering | `assets/src/components/activities/ordering/schema.ts` and its companion versioned transformations, factories, and authoring actions |
| CATA | `assets/src/components/activities/check_all_that_apply/schema.ts` and its companion versioned transformations, factories, and authoring actions |
| Likert | `assets/src/components/activities/likert/schema.ts`, `assets/src/components/activities/likert/utils.ts`, and `assets/src/components/activities/likert/actions.ts` |
| Shared fields | `assets/src/components/activities/types.ts` and the serialized output of its factories |

The schemas describe serialized authored JSON, including supported editing states.
They do not require every question to be ready for publication. The JavaScript
contract tests exercise actual factories, creation-data helpers, V1 migrations,
and Likert authoring actions before JSON serialization and schema validation.

## Ordering and CATA versions

Both activities require a stem, at least one choice, one authored part, and
`authoring.correct` as a `[choiceIds, responseId]` tuple. Targeted mappings are
arrays of the same shared tuple component. Parts, responses, feedback, hints,
explanations, transformations, and triggers reference the existing activity
components rather than repeating their structure or content definitions.

| Variant | Root `type` | Authoring requirements |
| --- | --- | --- |
| Ordering V1 simple | `SimpleOrdering` | `correct`; no `version` or `targeted` |
| Ordering V1 targeted | `TargetedOrdering` | `correct`, `targeted`; no `version` |
| CATA V1 simple | `SimpleCATA` | `correct`, `incorrect`; no `version` or `targeted` |
| CATA V1 targeted | `TargetedCATA` | `correct`, `incorrect`, `targeted`; no `version` |
| Ordering/CATA V2 | Absent | `version: 2`, `correct`, `targeted`; CATA must not retain `incorrect` |

All variants also require `parts`, `transformations`, and `previewText`. A supplied
authoring version selects V2; unversioned models must carry a recognized V1 tag.
Mixed layouts (such as a V1 tag with `version: 2`) are rejected. The schemas do
not migrate models; the tests separately verify the actual client migrations.

Ordering V2 additionally supports `choiceColors?: Array<[string, string]>`.
Tuple shape and string types are checked; colour validity, reference membership,
and correspondence to choices remain domain concerns.

Association choice-ID arrays deliberately permit repeated or nonexistent IDs.
The TypeScript type is `string[]`, and existing CATA import construction can
produce duplicates. This work checks tuple structure and value types without
adding uniqueness, rule, answer, or reference-integrity checks.

## Likert

Likert has a stem, scale choices, item content, `orderDescending`, `activityTitle`,
and unversioned authoring with `targeted`, `parts`, `transformations`, and
`previewText`. It supports multiple parts and items. An empty title and optional
item grouping are valid editing states. Item/part correspondence is not checked.

Likert choices extend the shared choice fields; items extend the shared content
wrapper. Every item, stem, choice, hint, response feedback, and explanation uses
the same recursive rich-text schema as Basic Pages and MCQ. Modern arrays and
legacy `{model: [...], selection: ...}` rich-text envelopes are supported.

The serialized `tsmonad.Maybe` forms are explicit, closed tagged objects:

| Field | Nothing | Just |
| --- | --- | --- |
| Choice `value` | `{"type": 0}` | `{"type": 1, "value": number}` |
| Item `group` | `{"type": 0}` | `{"type": 1, "value": string}` |

Choice value is optional (the client documents custom values as optional).
Grouping is optional: `makeLikertItem` currently assigns the `Maybe.nothing`
function, which JSON serialization omits. Also, `LikertActions.addItem` uses the
plain content factory, so newly added items omit both grouping and `required`.
The schema therefore types those fields when present without rejecting the
client's own serialized action output. `frequency` is optional in serialized
choices despite being declared on the class. No client helper behavior is changed.

## Strictness, metadata, and runtime reuse

Unknown fields are rejected on each activity model, authoring object, choice,
item, part, response, hint/feedback/explanation wrapper, transformation, variable,
trigger, Maybe object, legacy editor-selection wrapper, and Activity envelope.
The shared Basic Page element extension policy remains unchanged.

The common `model-metadata` component models inherited `ActivityModelSchema`
fields once for all supported activity types. `resourceId`, language, bibliography,
and identifier metadata are typed. The parent interface explicitly types root
`content` and `activityType` as `any`; these named fields remain opaque JSON
metadata. They are distinct from the rich-content slots and do not select a
schema. Misspelled metadata field names are still rejected. Existing MCQ
compatibility for string/integer `activity_id` is preserved.

Named validators cache their complete schema graphs by registry revision. Shared
references are built once within each graph and reused during validation. There
is no schema generation, file read, network reference resolution, or graph build
per submitted content node or per warm validation. The existing balanced content
dispatcher and its build-time generator are unchanged by these new activity types.
JSV remains encapsulated in `Oli.Utils.JSONValidation`.

## Verification and scope limits

- `assets/test/activity_schemas/choice_family_schema_test.ts` validates real client
  factories, import helpers, tagged V1 forms, actual V1-to-V2 migrations, Likert
  multipart actions, Maybe serialization, strict fields, and export dispatch using AJV.
- `test/support/fixtures/choice_family_models.json` captures deterministic,
  serialized factory models shared with server tests.
- `test/oli/utils/choice_family_schema_test.exs` validates the same models with JSV,
  all shared Basic Page examples in all rich-content slots, malformed nested data,
  strict fields, version dispatch, tuple shapes, multipart/Maybe structures,
  inherited metadata, historical CATA export compatibility, and cache reuse.
- Existing MCQ, Basic Page, activity, ingestion, rendering, and history regression
  tests continue to cover the shared infrastructure.

Cross-reference integrity, ID uniqueness, answer correctness, scoring consistency,
rule/variable expression evaluation, and publish readiness remain deferred.
Compatibility with the checked-in CATA export and client factories/migrations is
not a production corpus guarantee. No domain logic or automatic enforcement is
introduced by this work.

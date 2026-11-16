# Remaining activity JSON Schemas

All 17 activity manifests under `assets/src/components/activities` now have an explicit model validator and strict Activity export schema. The `common` directory is shared implementation, not an activity. Adaptive is covered separately in `guides/activities/adaptive-json-schema.md`.

This final group adds:

| Activity directory | Exact manifest/API slug | Model schema | Export schema |
| --- | --- | --- | --- |
| `image_hotspot` | `oli_image_hotspot` | `image-hotspot.schema.json` | `image-hotspot-activity.schema.json` |
| `oli_embedded` | `oli_embedded` | `oli-embedded.schema.json` | `oli-embedded-activity.schema.json` |
| `lti_external_tool` | `lti_external_tool` | `lti-external-tool.schema.json` | `lti-external-tool-activity.schema.json` |
| `logic_lab` | `oli_logic_lab` | `logic-lab.schema.json` | `logic-lab-activity.schema.json` |
| `vlab` | `oli_vlab` | `vlab.schema.json` | `vlab-activity.schema.json` |

Schema files are in `priv/schemas/v0-1-0/`. Use the exact manifest ID, including the absence of an `oli_` prefix for LTI:

```elixir
Oli.Validation.validate_activity_schema("lti_external_tool", model)
# :ok | {:error, errors}
```

The API remains opt-in; save, ingest, and legacy validation boundaries are unchanged. JSV stays encapsulated in `Oli.Utils.JSONValidation`. Graphs are built once per registry revision and reused during subsequent validation.

## Shared contracts and strict fields

All five schemas use the shared `part-with-match-config` component. Stems where declared, hints, feedback, and explanations reference `activity-components.schema.json`, whose rich text uses the same Basic Page definitions and dispatcher. Hotspot and Virtual Lab choices reuse the same content constraints. No rich-content definitions are copied.

Activity, authoring, part, response, content, and export wrappers reject unknown fields. The shared rich-node extension policy remains unchanged. Generic responses may contain a legacy rule, structured match configuration, or both. Match-config wrappers stay strict; the entire `matchConfig.math` object is opaque, including nested JSON and ordinary `$ref` data. No expression representation is added to these schemas.

## Activity details

### Image Hotspot

The source is `assets/src/components/activities/image_hotspot/schema.ts` and its factory/actions. Required root fields are `stem`, `choices`, `multiple`, and `authoring`; `imageURL`, numeric `height`, and numeric `width` are optional. `imageURL: undefined` is omitted by the serialized default factory; JSON `null` is rejected.

Hotspots extend shared choice fields with required numeric-array `coords` and optional string `title`. Coordinate count, shape validity, bounds, and positive dimensions are deferred domain checks. Authoring requires `parts`, `transformations`, `previewText`, `targeted`, and `correct`. The single-selection factory's `[[], ""]` unset correct association is accepted without weakening the association component used by other activities. No relationship between `multiple`, choices, and response rules is enforced.

### OLI Embedded

The source is `assets/src/components/activities/oli_embedded/schema.ts`. Required root fields are `base`, `src`, `modelXml`, `resourceBase`, `resourceURLs`, `stem`, `title`, and `authoring`. Authoring requires `parts` and `previewText`.

Optional `suppressReviewInteraction` is boolean. `resourceVerification` is a record with arbitrary resource names and values restricted to `verified` or `missing`. Optional `bundleStatus` is a closed object requiring string `code` and `message`. XML and resource addresses are strings; the schema does not parse XML, verify bundles, check paths, fetch assets, or enforce resource policy.

### LTI External Tool

The source is `assets/src/components/activities/lti_external_tool/schema.ts` and the registered callback in `authoring-entry.ts`. Required root fields are boolean `openInNewTab` and `authoring`; numeric `height` and `deepLink` are optional. Authoring requires `parts` and permits optional string `previewText`, because the real creation callback emits it even though the narrower TypeScript authoring interface omits it.

A deep link is a closed object requiring `type: "ltiResourceLink"`, with optional string `url`, `title`, `text`, and object `custom`. The latter is explicitly a `Record<string, unknown>`; arbitrary JSON values inside that record remain opaque. This is separate from strict handling of the surrounding deep-link fields. Launch authorization, registration, URL policy, and remote tool behavior remain domain concerns.

### Logic Lab

The source is `assets/src/components/activities/logic_lab/LogicLabModelSchema.tsx` and its registered creation callback. Required root fields are `activity`, `feedback`, and `authoring`; optional `context` is a closed object requiring string `title`. Authoring requires `version: 1`, `parts`, `transformations`, and `previewText`, with optional string XML `source`.

`activity` is either a string ID (including the factory's empty string) or a closed `LabActivity` object requiring `id`, `title`, `version`, `keywords`, and `spec`, with typed optional metadata. `spec` requires one of the six declared activity types and an objectives array. Objectives have closed category/requirement/mode fields. Optional `maximumScore` is numeric and `preview` is string/null.

The client deliberately declares `[key: string]: unknown` in `ActivitySpecification`. Therefore `spec` allows extension keys with opaque values while checking known fields. Outer activity objects and objectives remain closed. This supports remote activity-specific payloads without inventing schemas for them. Rules, XML, remote availability, objectives, and scoring semantics are not evaluated.

### Virtual Lab

The source is `assets/src/components/activities/vlab/schema.tsx`, its factory, and `actions.ts`. Required root fields are `stem`, `choices`, `inputs`, `assignmentSource`, `assignmentPath`, `assignment`, `configuration`, `reactions`, `solutions`, `species`, `spectra`, and `authoring`. Assignment/configuration fields are strings; the schema does not parse their XML. Authoring requires `parts`, `targeted`, `transformations`, and `previewText`.

Inputs require string `id`, `partId`, and a declared/supported input type. Dropdowns require string-array `choiceIds`; `vlabvalue` requires string `species` and `parameter`. The input schema also accepts legacy `math`, supported by `VlabInputType`, `VlabActions.setInputType`, and its responses despite omission from the narrower `FillInTheBlank` union. Existing transitions retain `choiceIds`, `species`, and `parameter`; those known fields remain optional and typed on other variants. Multi Input's `size` and `itemConfig` are not declared for Virtual Lab and are rejected.

`parameter` follows the actual input interface's string type, rather than limiting values to the separate current UI parameter choices. Input-reference integrity, species existence, parameter semantics, and array readiness are deferred.

## Verification

`assets/test/activity_schemas/remaining_activities_schema_test.ts` runs AJV against actual factories, real LTI/Logic Lab registered creation callbacks (isolating browser component registration), and editor outputs. It checks all Virtual Lab transitions and verifies that every activity manifest has exactly one export schema. The serialized outputs are checked against `test/support/fixtures/remaining_activity_models.json`.

`test/oli/utils/remaining_activity_schemas_test.exs` validates the same fixtures using the cached backend API and JSV. It checks manifest-to-dispatch coverage, exact export subtypes, strict fields, all shared Basic Page factory examples in supported rich-content slots, typed records, open extension boundaries, opaque math nested 1,000 levels deep, and deferred domain checks. Existing activity-schema tests remain part of the regression suite.

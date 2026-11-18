# Adaptive Page JSON contract

Adaptive Pages store lesson settings and deck sequences, not inline adaptive activity models. Each sequence entry references a separately versioned activity. This contract follows the current Adaptive Page authoring, server save conversion, delivery loading, and navigation implementation.

## Schema entry points

| Schema under `priv/schemas/v0-1-0/` | Purpose |
| --- | --- |
| `page-content-adaptive.schema.json` | Adaptive Page content and authoring wire payloads |
| `adaptive-page-components.schema.json` | Shared deck, sequence-reference, sequence-custom, and lesson-custom definitions |
| `page-content.schema.json` | Explicit dispatch between Adaptive and Basic Page content |
| `adaptive-page.schema.json` | Closed Adaptive Page export using the generic Page envelope |
| `page.schema.json` | Existing generic Page export using the content dispatcher |

```elixir
root = Oli.Utils.SchemaResolver.resolve("page-content-adaptive.schema.json")
Oli.Utils.JSONValidation.validate(root, content)
# :ok | {:error, [{message, json_pointer}]}
```

JSV remains encapsulated in `Oli.Utils.JSONValidation`. Graphs are built once per schema registry revision and reused for subsequent validation. No validation calls were added to save or delivery flows. Existing ingest/history callers of the page schemas now receive the corrected structural checks.

## Findings from the implementation audit

The former Adaptive Page schema checked only flags, an untyped `model` array, and a few top-level types. It accepted arbitrary groups, children, sequence metadata, and lesson settings. The generic page-content `oneOf` also allowed malformed Adaptive content with a Basic Page version to fall through to the Basic schema.

The authoring path is `assets/src/apps/authoring/store/page/slice.ts`, `actions/initializeFromContext.ts`, and `actions/savePage.ts`. It saves deck groups selected from the group store, strips runtime `resourceId` fields recursively, serializes custom CSS/script/stylesheets, and computes lesson score settings. Current lesson settings are mapped by `assets/src/apps/authoring/components/PropertyEditor/schemas/lesson.ts`; score settings are also updated by `components/Modal/ScoringOverview.tsx`.

Server `lib/oli/authoring/editing/page_editor.ex` preserves numeric `activity_id` resource references on authoring load and save. Adaptive initialization derives internal `resourceId` and revision-slug metadata from those IDs. Saving emits `activity_id` and strips internal `resourceId` and reference-level `activitySlug`; no server slug/ID conversion is performed. The group store normalizes legacy IDs for runtime use.

Delivery uses `assets/src/apps/delivery/store/features/page/slice.ts`, `page/actions/loadInitialPageState.ts`, `groups/slice.ts`, `groups/actions/sequence.ts`, `groups/actions/navUtils.ts`, `groups/selectors/deck.ts`, and `layouts/deck/DeckLayoutView.tsx`. It reads lesson settings, restores sequence references, traverses layer lineage, and navigates banks. The sequence editor represents hierarchy using `layerRef` in a flat deck array; nested deck groups are not the persisted hierarchy representation.

## Page content and dispatch

Required fields are literal `advancedAuthoring: true`, literal `advancedDelivery: true`, and array `model`. Optional fields are boolean `displayApplicationChrome`, string-array `additionalStylesheets`, string `customCss`, string `customScript`, object `custom`, and legacy `version: "0.1.0"`. The content wrapper rejects unknown fields. `responsiveLayout` belongs under `custom`, not at the content root. Authoring/delivery runtime state, attempt state, activities, grading context, and learner identity are not persisted page-content fields.

Generic `page-content.schema.json` validates flag types, then selects Adaptive content when either flag is true. Both required flags must subsequently pass the Adaptive contract. Otherwise it uses Basic Page validation. A supplied Basic version cannot bypass Adaptive validation, and nonboolean flag values are rejected. Basic Page element definitions remain unchanged.

`adaptive-page.schema.json` composes the existing Page envelope and its dispatcher. It asserts Adaptive content and closes the export envelope, without validating the full content graph twice. Generic `page.schema.json` retains its existing extension policy. Its export properties now match `lib/oli/interop/export.ex`: objectives accept the current flat ID array as well as the legacy attached-object shape. Typed exported metadata includes `aiEnabled`, revision purpose/relations, collaboration settings, introductory content/media, scoring/explanation strategy, attempts, duration, progress, retake mode, and assessment mode. Nullable revision metadata is accepted. The page revision purpose values are distinct from Basic Page content-purpose values; they are `foundation`, `application`, and `deliberate_practice`.

The export audit found that the older Page schema required object objectives and omitted these exporter fields. A regression test now creates a real project/publication/page, runs the actual course exporter, unzips its output in memory, and validates the resulting Adaptive Page JSON. Collaboration/explanation wrappers follow their Ecto embedded schemas without adding numeric bounds or domain policy. Introductory content remains an object payload, matching the revision map field.

## Deck groups and sequence references

Every `model` entry is a closed deck group requiring `type: "group"`, `layout: "deck"`, and array `children`. Its optional ID is integer/string, covering current numeric authoring IDs and legacy/export string IDs. Empty model/group arrays remain valid authoring states. The schema imposes no group count.

Deck children are closed `activity-reference` objects with at least one typed target:

- `activity_id`: integer/string persisted or exported resource reference.
- `activitySlug`: legacy string revision-slug reference accepted by the schema for compatibility; current authoring saves use numeric `activity_id`.
- `activityId`: integer/string legacy alias recognized by the group loader.

Optional reference `id` is integer/string. `resourceId` is runtime-only and is rejected; the real save action removes it. Supplied aliases must each have the correct type, but agreement between aliases and target existence are domain checks.

Current references include closed `custom` metadata requiring string `sequenceId` and `sequenceName`. Optional `layerRef` is string/null, and `isLayer`/`isBank` are booleans. `bankShowCount` is numeric and `bankEndTarget` is a string. When `isBank` is true, both bank settings are required, matching the SequenceBank type and editor factory. Their values and destinations are not evaluated. Known fields retained after type changes remain accepted.

ID-only references without `custom` remain supported as an explicit legacy/Seeder profile. If metadata is supplied, it must be complete; an empty/malformed metadata object is rejected. This compatibility allowance does not guarantee that an old snapshot has enough sequence metadata for every current navigation feature.

Legacy `activity-reference.schema.json` and `activity-sequence.schema.json` remain unchanged because they also participate in Basic Page content validation. Adaptive Pages use the dedicated sequence contract, avoiding a change to the Basic Page compatibility policy.

## Lesson settings and opaque extensions

The client persists lesson `custom` as `any` and preserves historical/imported settings. Accordingly, the object remains extensible. Active known fields are typed; unknown legacy or integration keys and their nested values stay opaque.

Typed numeric settings are `defaultScreenWidth`, `defaultScreenHeight`, `totalScore`, and `maxScore`. Typed boolean settings cover responsive layout, current/legacy history flags, refresh warning, dark mode, background scaling, fixed/max scoring flags, authoring guides, and stage-only insights preview. String settings include content mode, theme ID, skin, finish message/image, and background image URL. Content mode remains a string; the schema does not evaluate mode availability.

`variables` is an array of closed objects with optional string `name` and `expression`. Empty objects/strings remain valid editing states because the lesson property editor does not require these fields and delivery skips incomplete entries. Expressions are not parsed or executed.

`everApps` follows `Everapp` in `assets/src/apps/delivery/layouts/deck/components/EverappRenderer.tsx`: each closed object requires string `id`, `name`, `url`, `iconUrl`, and boolean `isVisible`. URLs are not fetched or constrained by policy.

Custom CSS/scripts, variable expressions, and opaque extension values are not executed or inspected for expression internals. Individual Adaptive activity schemas remain separate, described in `guides/activities/adaptive-json-schema.md`.

## Deferred domain checks and compatibility limits

The schemas do not check referenced activity existence, duplicate IDs, parent cycles, bank membership/count bounds, bank end-target resolution, initial navigable screens, group readiness, score totals, variable dependencies, or script/CSS/URL semantics. Those concerns remain with existing authoring and delivery logic.

Malformed structures previously accepted by the permissive Adaptive schema now fail existing page-schema validation in ingest/history. No migration or automatic rewriting is performed. Unknown page/group/reference wrappers are rejected; legacy lesson custom extensions and metadata-less references are preserved deliberately.

## Verification

`assets/test/activity_schemas/adaptive_page_schema_test.ts` invokes the real page save thunk and deck/group reducers with persistence mocked at the network boundary. It captures serialized save output, verifies runtime-ID removal, validates a persisted reference variant, and runs that content through actual delivery reducers and sequence helpers. It uses real lesson property transformations and checks flowchart/responsive settings, banks/layers, strict export composition, and malformed Adaptive dispatch.

`test/support/fixtures/adaptive_page_models.json` contains those serialized outputs and is checked against the client implementation. `test/oli/utils/adaptive_page_schema_test.exs` validates the same fixtures through cached JSV validators. Tests cover required/typed fields, structural dispatch, strict wrappers, reference forms, explicit legacy support, active setting types, opaque custom extensions, variable/EverApp contracts, concurrent reuse, and export validation.

`test/oli/utils/adaptive_page_export_schema_test.exs` covers the actual exporter envelope and metadata using real database factories and an in-memory archive.

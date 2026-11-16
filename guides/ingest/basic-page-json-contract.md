# Basic Page JSON contract

Basic Page content uses Draft 7 JSON Schema in `priv/schemas/v0-1-0/`.
The contract describes persisted content, supported editor drafts, and intentional
legacy representations. Activity models and adaptive page content are outside
this reconciliation; their schemas are unchanged.

## Sources and decisions

Use these sources together when updating a schema:

- `assets/src/data/content/resource.ts`: page containers and insertion rules.
- `assets/src/data/content/model/elements/factories.ts`: actual new element shapes,
  including incomplete editing states and Slate placeholder children.
- `assets/src/data/content/model/elements/types.ts`: field names and intended types.
- `assets/src/data/content/model/schema.ts` and editor normalizers: editor nesting.
- `lib/oli/rendering/content.ex`, `lib/oli/rendering/content/html.ex`, and
  `lib/oli/rendering/elements.ex`: persisted shapes supported by delivery.

TypeScript interfaces alone are insufficient: several require fields the factories
omit and renderers handle as optional. The JSON contract preserves those usable
editing states rather than requiring complete media or interaction configuration.
It does not promise that every valid draft has a visible or fully configured
rendering, nor that every historical shape survives editor normalization unchanged.

## Coverage

| Surface | Contract |
| --- | --- |
| Envelope | `version: "0.1.0"`, `model` array; optional bibliography references and a page trigger. Existing `ContentMigrator` handles missing-version envelopes before audit validation. |
| Content block | Typed children; optional string/integer legacy ID, `editor` (`slate`/`markdown`), and `textDirection` (`ltr`/`rtl`). |
| Containers | Groups, surveys, Alternatives/options, reports, page breaks, and top-level Learning Objectives. Existing activity placements remain permitted without changing their schemas. |
| Reports | Require ID, `activityId`, and children; children are activity-reference placements. Report configuration does not validate an activity model or referenced resource existence. |
| Text | String text leaves; known formatting marks must be booleans. Text leaves cannot carry an element `type` and bypass typed validation. |
| Paragraphs/headings | Paragraphs support text, inline elements, and block-image shapes already supported by the editor. Headings contain text leaves. |
| Lists | Paragraph/media/nested list/semantic content in list items; legacy direct text in lists and list items remains accepted for normalization. Description-list items use `dt`/`dd`; titles may be paragraphs or inline content, and are optional in the renderer. |
| Tables | Rows contain cells; cells contain paragraph, media, math/formula, and legacy text content. Row/cell nesting is checked. Spans retain existing number compatibility; rectangularity remains an editor normalization concern. |
| Media | Optional source on image/audio/YouTube/iframe drafts. Video source entries require string URL and content type; caption tracks require language code, label, and source. Placeholder children are checked when present. |
| Captions | Legacy strings and recursively checked rich-text arrays. |
| Code/math | V1 code lines and V2 code strings; legacy math lines; block/inline formulas. V1 cannot conceal a malformed V2 `code` field. |
| Semantic content | Callouts, figures, definitions, conjugations, dialogs, and their structured sub-elements. Optional pronunciation and missing dialog arrays remain supported; malformed supplied fields are rejected. |
| Links/interactions | Hyperlinks, citations, page links, popups, command buttons including toggle states, ECL, and content triggers. Command target/message can be absent while editing; supplied values are typed. |
| Triggers | Page, group, and content placements each constrain `trigger_type` to the relevant context and require a string prompt. |

Rich-content element IDs remain optional, and historical integer IDs remain valid.
Empty arrays and intentionally blank strings remain valid drafts. Insertion-only business policies (such as purpose-group placement) remain editor
concerns; these schemas describe persisted structural shapes. Unknown extension
properties remain allowed except where existing schemas already forbid them (such
as Learning Objectives). Missing required structure, unknown element types, and
incorrect types for known fields are rejected. The shared rich-text schema retains
existing input-reference support; this work does not change activity validation.

Typed dispatch chooses an element schema before inspecting its descendants. This
avoids repeatedly traversing the same invalid subtree through unrelated union
branches. The registry includes the audience and report schemas for both server
validation and Monaco diagnostics. Registered schema files are compile dependencies;
the registry revision also invalidates cached validators when referenced schemas
change. JSV remains behind `Oli.Utils.JSONValidation`.

## Maintaining the balanced dispatcher

`Oli.Schemas.ContentDispatcher` and `mix oli.generate_content_dispatcher` generate
only `$defs/typed-element`. All concrete element definitions and context/placement
enums remain the authored source. The generated JSON is checked in for both
server and browser consumers; generation is never part of runtime validation.

When adding or changing an element:

1. Define its string `type` constant and field constraints in `$defs`. Declare
   `"x-torus-dispatch": true` for an element that can occur in a rich-text array,
   or `false` for structured-only sub-elements such as pronunciation or dialog lines.
   These are build-time annotations ignored by standard JSON Schema validation.
2. Update the appropriate context enum(s) to define where that kind is allowed.
   Context membership is intentional policy, not inferred from a factory.
3. For multiple representations of one kind, provide exactly one unconditional
   fallback and annotate conditional variants with `x-torus-dispatch-when`.
   V2 code uses `{"required": ["code"]}`; V1 is the fallback. Conditional variants
   are evaluated in definition-name order. Authors must make their precedence
   intentional; the generator does not prove arbitrary conditions disjoint.
4. Regenerate and verify:

   ```bash
   mix oli.generate_content_dispatcher
   mix oli.generate_content_dispatcher --check
   ```

5. Add valid and malformed examples to the existing server/browser contract tests.

Generation derives the allowed type list and balanced branches from those
annotations. It fails on missing classifications, missing/ambiguous fallbacks,
and context enums naming unknown standalone types. It leaves element definitions
and context policy unchanged and writes stable, readable JSON. `--check` compares
decoded content and never writes; ordinary ExUnit tests run the same consistency
check, so stale checked-in output fails the existing test pipeline without a new
CI configuration. No generator step is needed by deployment/runtime consumers.

## Regression coverage

- `assets/test/data/content/basic_page_schema_test.ts` validates actual factory
  output with the existing AJV dependency and compares it with the shared examples.
- `test/support/fixtures/basic_page_elements.json` captures those factory shapes.
- `test/oli/utils/basic_page_schema_test.exs` validates the same examples through
  JSV's generic adapter, plus complete media, nesting, malformed fields, containers,
  legacy forms, and the repository's historical JSON corpus.
- `test/mix/tasks/oli.audit_basic_pages_test.exs` checks the read-only audit,
  bounded diagnostics, input selection, and optional CI failure behavior.

When changing factories intentionally, update the shared examples and both sides
of the contract tests. Add malformed counterparts for newly validated fields.

## Compatibility audit and rollout

Run a read-only audit on exported pages or a configured database:

```bash
mix oli.audit_basic_pages 'path/to/export/*.json'
mix oli.audit_basic_pages --database --max-errors 20
mix oli.audit_basic_pages 'path/to/export/*.json' --fail-on-invalid
```

Database mode streams all page revisions, including historical/deleted revisions,
inside a read-only transaction. It starts only the database dependencies, not
the application or its background jobs. Adaptive pages are skipped. Counts and a bounded
set of identifiers/JSON Pointer paths are printed; submitted content and error
messages are omitted. Existing legacy envelope migration runs in memory only.
File read/decode errors abort the command rather than silently producing a clean
audit. No files, published content, or database records are rewritten.

The local development audit on 2026-11-15 found two Basic Page revisions, both
valid after the existing legacy-envelope migration. The checked-in JSON corpus
contained 18 Basic Pages: 15 pass and three retain expected rejections:

- `test/oli/rendering/page/example_malformed_page.json`: deliberate malformed data.
- `test/oli/rendering/page/missing_language.json`: deliberate malformed code data.
- `test/oli/rendering/page/example_page.json`: numeric activity-reference IDs violate
  the unchanged activity-reference schema. That separate activity-placement issue
  is outside this reconciliation.

These samples are not a production compatibility guarantee. No automatic content
migration is warranted by the local results. Before wider enforcement, run the
audit against production exports or a production read-only database and classify
all failures. Preserve supported legacy shapes; repair genuinely malformed draft
content through authoring, and use explicit versioned content migrations for any
intentional representation changes. Do not silently rewrite published content.

## Enforcement decision

This change reconciles schemas at the existing validation boundaries. It does not
add validation to ordinary authoring saves, enable ingest validation by default,
or change history upload handling. Wider enforcement remains a separate change
requiring production-corpus evidence and a decision about draft validity versus
publish readiness. The history upload list/object mismatch identified during the
original audit is also separate from this schema change.

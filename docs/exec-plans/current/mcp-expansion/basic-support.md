# Current TorusDoc support for basic page content

Investigated **2026-11-12**, repository revision **9541634b2035a138435a86cd7383df481ec33cdd**.

This inventory compares Torus's native basic-page content model with the **current executable TorusDoc YAML → page parser → Markdown parser → JSON converter**. It covers formatting, structured content, and page-level elements. Activity references and bank-selection placements are included; activity models, question types, evaluation, hints, and feedback internals are outside this investigation.

**Finding:** TorusDoc supports a subset of basic-page content. Ordinary prose, common Markdown formatting, headings, lists, code and simple tables are implemented. Most media, semantic blocks, Alternatives, learning-objective displays and page breaks are absent. Examples work through purpose groups. Some implemented conversions lose native structure or settings, so “the parser accepts it” does not establish full native support.

## Reading the tables

- **Yes**: the current page import path implements this basic capability. This does not imply lossless serialization, all native attributes, or successful persistence/delivery validation.
- **Partial**: a subset is implemented, or important native structure/settings are missing.
- **No**: no functioning page-import mapping was found. A helper clause alone, unsupported HTML, or a claim in a README does not count as end-to-end support.

The native inventory is the union of `FormattedText` marks, `AllModelElements`/structured-content schema, and `ResourceContent`. It includes supporting child types and legacy representations, labeled below. Availability in a particular editor can depend on editor mode, feature flags and context; inclusion here means represented by the native model, not necessarily exposed on every toolbar.

Terminology: the repository calls the wrapper **`StructuredContent`**, with `type: content` and rich elements under `children`. The three requested categories below are (1) StructuredContent inline, (2) StructuredContent block, and (3) other page elements outside that wrapper. Text marks are included in inline; supporting cell/list/semantic child types are included in block.

## 1. StructuredContent inline

Native sources: [text.ts](../../../../assets/src/data/content/model/text.ts), [elements/types.ts](../../../../assets/src/data/content/model/elements/types.ts), [schema.ts](../../../../assets/src/data/content/model/schema.ts). TorusDoc source: [inline_parser.ex](../../../../lib/oli/torus_doc/markdown/inline_parser.ex), called by [markdown_parser.ex](../../../../lib/oli/torus_doc/markdown/markdown_parser.ex).

| Native capability | Native representation | TorusDoc support? | Current syntax / qualification |
|---|---|---|---|
| Plain text | `text` leaf | **Yes** | Text in `prose.body_md`. Adjacent text with matching recognized marks is merged. |
| Bold | `strong` mark | **Yes** | `**bold**` → `strong: true`. |
| Italic | `em` mark | **Yes** | `*italic*` → `em: true`. |
| Inline code | `code` mark | **Yes** | Backticks → `code: true`. |
| Strikethrough | `strikethrough` mark | **Yes** | GFM `~~text~~` → `strikethrough: true`. |
| Underline | `underline` mark | **No** | No mark-producing import clause. `<u>` is not a reliable formatting escape hatch. |
| Superscript | `sup` mark | **No — page path** | `InlineParser.transform/1` handles an AST `sup` element, but normal Markdown input does not generate it in the exercised cases. Raw `<sup>` remains literal text inside a paragraph or disappears as an unsupported block. |
| Subscript | `sub` mark | **No — page path** | Same limitation as superscript; helper handling of a constructed AST is not usable page-import syntax. |
| Double subscript | `doublesub` mark | **No** | No importer mapping. |
| Highlight | `mark` mark | **No** | No importer mapping; raw `<mark>` was preserved as literal text in the exercised inline case. |
| Deleted-text mark, distinct from strikethrough | `del` mark | **No** | Markdown's `del` AST produces `strikethrough`, not the native `del` mark. |
| Variable typography | `var` mark | **No** | No importer mapping. |
| Term text mark | `term` mark | **No** | `:term[...]` produces a `callout_inline` element, not this mark. |
| Foreign-language text mark | `foreign` mark | **No** | No importer mapping. Distinct from the `foreign` element below. |
| Deemphasis | `deemphasis` mark | **No** | No importer mapping. |
| Combined text marks | Multiple native mark keys on one leaf | **Partial** | Bold/italic/code combinations can be represented by supported Markdown nesting; unsupported marks remain unavailable. Mark application operates on text leaves, not arbitrary nested inline-element descendants. |
| Hard line break within text | Newline in text | **Yes** | Earmark `br` becomes `text: "\n"`; ordinary soft breaks use Earmark behavior (`breaks: false`). |
| External hyperlink | `a` with `href` | **Partial** | `[label](https://...)` emits `a`, `href`, children. No explicit import of `target`, `anchor`, or `linkType`. |
| Torus page hyperlink | `a`, `linkType: page`, routing/anchor metadata | **No — typed link** | A URL string can be emitted, but no typed Torus page-link resolution or metadata mapping. Distinct from block `page_link`. |
| Media-library hyperlink | `a`, `linkType: media_library` | **No — typed link** | No media-library identity/type mapping; ordinary href support is insufficient. |
| Inline image | `img_inline` | **Partial** | `![alt](src)` emits inline image with src/alt. Helper can copy width/height from AST attributes, but ordinary image Markdown offers no native dimension/ID/void-child contract. Does not emit block `img`. |
| Inline formula, LaTeX | `formula_inline`, `subtype: latex` | **Partial** | `\(x + y\)` is preprocessed to a formula node. No general native ID/children/`legacyBlockRendered` field preservation. |
| Inline formula, MathML | `formula_inline`, `subtype: mathml` | **No** | Only LaTeX emitted. |
| Inline callout | `callout_inline` | **Partial** | `:term[word]{id="term-id"}` emits callout with text and optional ID. Arbitrary native rich children/settings are not mapped. |
| Foreign-language span | `foreign`, optional `lang` | **No** | No element mapping. |
| Citation / bibliography reference | `cite`, `bibref` | **No** | No citation directive or bibliography-reference wiring. |
| Popup / popover | `popup`, trigger/content/audio | **No** | No element mapping. |
| Command button | `command_button`, message/target/style/toggle states | **No** | No element mapping. |
| Input reference | `input_ref` | **No** | Native structured inline type; no page import mapping. No activity internals investigated. |

All **14 native text marks** are explicitly accounted for above. `strong`/`em` are the native mark keys; “bold” and “italic” are their user-facing names.

## 2. StructuredContent block

Native sources: [elements/types.ts](../../../../assets/src/data/content/model/elements/types.ts), [schema.ts](../../../../assets/src/data/content/model/schema.ts). TorusDoc sources: [markdown_parser.ex](../../../../lib/oli/torus_doc/markdown/markdown_parser.ex), [block_parser.ex](../../../../lib/oli/torus_doc/markdown/block_parser.ex), [table_parser.ex](../../../../lib/oli/torus_doc/markdown/table_parser.ex).

| Native capability | Native representation | TorusDoc support? | Current syntax / qualification |
|---|---|---|---|
| Paragraph | `p` | **Yes** | Ordinary Markdown paragraph. Native element IDs are not preserved/generated throughout the rich subtree. |
| Headings, levels 1–6 | `h1`, `h2`, `h3`, `h4`, `h5`, `h6` | **Yes** | `#` through `######`. |
| Unordered list | `ul` | **Partial** | Markdown bullets supported. Native list style (`none`, `disc`, `circle`, `square`) is not imported. |
| Ordered list | `ol` | **Partial** | Markdown numbering supported. Roman/alphabetic/other native styles are not imported; source numbering/start settings are not preserved. |
| List item and nested lists | `li` plus `ul`/`ol` descendants | **Partial** | Basic and nested Markdown supported, but converter places nested lists as siblings of the preceding `li`. Simple `li` content is text/inline nodes rather than the paragraph/block children described by native types. Not structure-preserving. |
| Description list | `dl` | **No** | No description-list parser/converter. |
| Description-list term | `dt` child | **No** | No mapping. |
| Description-list definition | `dd` child | **No** | No mapping. |
| Blockquote | `blockquote` | **Yes — basic** | `>` with paragraphs is implemented. More permissive nested Markdown should not be assumed to satisfy native paragraph-only child typing. |
| Code block, current representation | `code` with `code`, `language` | **Partial** | Fenced code emits source and language (`text` default). Captions and native IDs/void children are not mapped. |
| Legacy code block/lines | `code` with `code_line` children | **No — legacy shape** | Import emits current string form instead; it cannot preserve legacy line-node identity/marks. |
| Legacy math block | `math` with `math_line` children | **No** | Not the form emitted by `$$`. |
| Legacy math line | `math_line` child | **No** | No mapping. |
| Display formula, LaTeX | `formula`, `subtype: latex` | **Partial** | `$$` on separate lines emits formula/src via special code-block language. Native attributes/IDs are not generally preserved. |
| Display formula, MathML | `formula`, `subtype: mathml` | **No** | No import mapping. |
| Table | `table` | **Partial** | GFM pipe tables implemented; no table caption, border or alternating-row style mapping. |
| Table row | `tr` child | **Yes — basic** | Generated for header/body rows. |
| Table header cell | `th` child | **Partial** | Generated for headers. Basic text/inline contents; not full native cell block/media content. |
| Table data cell | `td` child | **Partial** | Generated for body cells. Simple pipe cells emit bare text leaves, while native cell typing/schema expects structured children. |
| Table alignment and merged cells | Cell `align`, `rowspan`, `colspan` | **No — usable page syntax** | Table helper contains attribute readers, but the exercised centered GFM table emitted no `align`. No supported page syntax established for cell spans; arbitrary HTML tables are not a native passthrough. |
| Conjugation table cell | `tc`, audio/pronoun fields | **No** | No mapping. |
| Block image | `img`, caption/dimensions/alt | **No** | Ordinary image Markdown emits `img_inline`, even when alone in a paragraph. |
| YouTube | `youtube`, timing/caption/dimensions | **No** | No executable media directive handler in this path. Pasting a URL is not a YouTube node. |
| Audio | `audio`, src/alt/caption | **No** | No executable mapping. |
| Video | `video`, source list/poster/caption tracks/dimensions | **No** | No executable mapping. |
| Embedded webpage / iframe | `iframe`, URL/media-library source and accessible title | **No** | No executable mapping. |
| Figure | `figure`, rich title and children | **No** | No mapping. |
| Block callout | `callout` | **No** | `:term` inline callout is a different element. Purpose groups are also a different representation. |
| Definition | `definition`, term/meanings/translations/pronunciation | **No** | No semantic definition mapping. |
| Definition meaning | `meaning` supporting child | **No** | No mapping. |
| Translation | `translation` supporting child | **No** | No mapping. |
| Pronunciation | `pronunciation` supporting child, audio | **No** | No mapping. |
| Dialog | `dialog`, speakers/lines | **No** | No mapping. |
| Dialog line | `dialog_line` supporting child | **No** | No mapping. |
| Conjugation | `conjugation`, verb/pronunciation/table | **No** | No mapping. |
| ECL REPL | `ecl`, code | **No** | A code fence is not an executable ECL element. Native optional content capability. |
| Content trigger | `trigger`, prompt/type configuration | **No** | Native optional/feature-dependent capability; no mapping. |
| Page-navigation block | `page_link`, `idref`, `purpose` | **No** | Ordinary Markdown hyperlink is a different model. |
| Captions for images/media/code/tables | Native legacy string or rich caption | **No** | No general caption mapping. Markdown image alt text does not create a caption. |

A horizontal rule (`---`) is **not** a native structured-content element in this model. The Markdown converter explicitly drops `hr`. It does not create the native page-level `break` below.

## 3. Other: outside StructuredContent

The native page `model` is a sequence of `ResourceContent` elements. Native source: [resource.ts](../../../../assets/src/data/content/resource.ts#L39), including nesting rules in `canInsert`/`allowedContentItems`. TorusDoc sources: [page_parser.ex](../../../../lib/oli/torus_doc/page_parser.ex), [page_converter.ex](../../../../lib/oli/torus_doc/page_converter.ex). Renderer corroboration: [elements.ex](../../../../lib/oli/rendering/elements.ex).

| Native capability | Native representation | TorusDoc support? | Current syntax / qualification |
|---|---|---|---|
| Structured-content wrapper | `content` with rich `children` | **Partial** | YAML `type: prose`, `body_md` becomes `content`, ID and children. No native `editor` or `textDirection` import. |
| Activity placement/reference | `activity-reference` | **Partial** | YAML `activity_reference` accepts integer `activity_id` or string `virtual_id`; converter emits reference fields, including `_virtual_id` for deferred resolution. This does not validate/persist/resolve the referenced activity. No activity model analysis performed. |
| Activity-reference alias | Same native placement | **Partial** | `type: activity` with an activity identifier can use reference branch. Inline activity definitions also exist, but their content support is outside this inventory. |
| Activity-bank selection placement | `selection` with count/logic/points | **Partial** | YAML `type: bank-selection`, `count`, `points`, `clauses`. Converter builds `conditions.operator: all`; cannot express arbitrary nested `all`/`any` logic. Positive points becomes `pointsPerActivity`; zero omitted. Operator mappings do not exactly match the native Bank operator vocabulary, so accepted clauses are not proof of valid delivery selection. |
| Group/container | `group` | **Partial** | YAML `type: group`, `blocks`, `purpose`, `layout`, `audience`, `pagination_mode`. No group trigger. Parser rejects nested groups/surveys even though native insertion rules allow some nested arrangements. |
| Example | `group`, `purpose: example` | **Yes — basic group** | `type: group`, `purpose: example`. Not a separate rich-content element. Subject to group limitations. |
| Checkpoint | `group`, `purpose: checkpoint` | **Yes — basic group** | Same group syntax. |
| Did I get this? | `group`, `purpose: didigetthis` | **Yes — basic group** | Same group syntax. |
| Lab | `group`, `purpose: labactivity` | **Yes — basic group** | Same group syntax. |
| Learn by doing | `group`, `purpose: learnbydoing` | **Yes — basic group** | Same group syntax. |
| Learn more | `group`, `purpose: learnmore` | **Yes — basic group** | Same group syntax. |
| Many students wonder | `group`, `purpose: manystudentswonder` | **Yes — basic group** | Same group syntax. |
| Prior Knowledge Check | `group`, `purpose: priorknowledgecheck` | **No** | Native `PurposeTypes` includes it; TorusDoc purpose allowlist rejects it. Confirmed by probe. |
| Quiz | `group`, `purpose: quiz` | **Yes — basic group** | Same group syntax. This is group labeling, not activity authoring support. |
| Simulation | `group`, `purpose: simulation` | **Yes — basic group** | Same group syntax. |
| Walkthrough | `group`, `purpose: walkthrough` | **Yes — basic group** | Same group syntax. |
| Group with no purpose | `group`, `purpose: none` | **Yes — basic group** | Default purpose. TorusDoc additionally accepts `myresponse`, which is absent from current native `PurposeTypes` UI list. |
| Group layout | `vertical` / `deck` | **Yes** | Parser validates these two layouts. |
| Group reveal/pagination | `normal`, `manualReveal`, `automatedReveal` | **Partial** | Snake-case YAML field copied to `paginationMode`, but no enum validation in parser. |
| Group audience | `always`, `instructor`, `feedback`, `never` | **Partial** | Value passed through; no native enum validation in parser. |
| Survey container | `survey`, title/children | **Yes — basic container** | YAML `type: survey`, title and blocks; prose/references/bank selection accepted. No activity internals assessed. |
| Native container nesting | `ResourceGroup` children | **Partial** | Survey parser accepts only prose/activity/reference/selection; group parser likewise and explicitly rejects group/survey. Converter has recursive cases that the parser prevents reaching. Native hierarchy rules differ. |
| Activity-results report placement | `report`, activityId/reportType/title/children | **No** | No page parser block case. This is an authored page element, distinct from administrative reporting. |
| Alternatives placement | `alternatives`, alternatives_id/children | **No** | No page parser block case; rejected. |
| Individual alternative branch | `alternative`, value/children | **No** | No parser/converter mapping; native branch child, not an independently insertable root item. |
| Learning Objectives display | `learning_objectives`, introduction/summary mode/config | **No** | No display-element mapping, sub-objective option or revisit/practice page settings. Distinct from objective attachment metadata. |
| Page break | `break` | **No** | No YAML page-block mapping; Markdown horizontal rule does not substitute. |

### Page metadata and cross-cutting fidelity

These settings are not additional rich-content elements, but matter when deciding whether a native basic page is representable.

| Capability | TorusDoc support? | Observed behavior |
|---|---|---|
| Page title, ID, graded flag | **Yes — import fields** | `type: page`, `title`, `id`, `graded`; converter emits import wrapper `type: Page`, `isGraded`, content version `0.1.0`. Not a complete persisted revision envelope. |
| Top-level prose/group/survey/reference/selection IDs | **Yes** | Supplied block IDs retained; missing block/page IDs generated. |
| IDs on all native rich-content descendants | **No — general preservation** | Markdown constructors generally omit descendant IDs; `:term` optionally accepts an ID. |
| Page objective attachments | **No** | Converter unconditionally emits `objectives.attached: []`. Objective display is separately unsupported above. |
| Page tags | **No** | Converter unconditionally emits `tags: []`. |
| Page bibliography | **No** | No `bibrefs` preservation/wiring; citation nodes unsupported. |
| Page/group triggers | **No** | No mapping of native page trigger or group trigger metadata. |
| Arbitrary metadata/extension fields | **No — preservation** | Parser captures extra page keys into `metadata`, but converter does not serialize that metadata into its output. |
| Raw native JSON block escape hatch | **No** | No supported generic block for passing through arbitrary native elements. Unknown YAML block types error. |
| Arbitrary HTML / media directives | **No** | No general HTML→native or directive→native conversion. Unknown block AST elements can disappear; unknown inline AST elements can flatten. Some inline HTML remains literal text. |
| Native JSON → TorusDoc export / lossless round trip | **No implementation found** | Current modules provide import; no reverse page serializer found. “Yes” rows above do not establish round-trip fidelity. |

## 4. Important implementation discrepancies

1. **The Markdown README overstates executable capabilities.** [markdown/README.md](../../../../lib/oli/torus_doc/markdown/README.md) describes `:::youtube`, audio/video/iframe directives and a `DirectiveParser`. No such module exists in the current `lib/oli/torus_doc` inventory, and the actual Markdown pipeline calls only inline, block-math and table parsers. Do not mark those media types supported from this document.
2. **Superscript/subscript helper branches are not a usable page feature.** Direct AST transformation supports them; the actual Markdown parser probe produced literal HTML or an empty output instead of marks.
3. **Table helper features do not guarantee input support.** Helper code reads alignment/spans, but a centered GFM table probe emitted no alignment. Simple cell contents also differ from native structured-child typing.
4. **Nested groups have unreachable converter support.** Recursive converter clauses exist, but the page parser explicitly rejects groups inside groups and surveys inside groups. Native allowed nesting is more permissive in some cases.
5. **Bank logic is only a partial bridge.** Native [bank.ts](../../../../assets/src/data/content/bank.ts) supports recursive clauses (`all`/`any`) and named native operators. TorusDoc emits a flat conjunction and translates `equals` to `equal`, `not_equals` to `notEqual`, `includes` to `contains`; native enum names include `equals`, `does_not_equal`, `does_not_contain`. This is a vocabulary discrepancy requiring validation, not evidence that every selection will fail. No selection realization or activity internals were investigated.
6. **Survey extras exceed the typed native container.** TorusDoc can emit anonymous/randomize/paging/showProgress/introText fields beyond the `SurveyContent` interface. `intro_md` is copied to introText rather than converted as rich Markdown. This inventory does not assert those fields have delivery behavior.
7. **No general losslessness guarantee exists.** Fields and IDs can be omitted/reset; unknown Markdown blocks can be silently discarded. Do not use the current import pipeline as a safe read-modify-write serializer for arbitrary existing pages.

## 5. Verification performed

The investigation used native types/schema, the page parser/converter, executable Markdown implementation, renderer dispatch and existing tests. No activity-specific parser/converter investigation, production mutation or dependency installation was performed.

**Isolated ExUnit check:** loaded the four Markdown source modules from the working tree into a disposable Elixir VM using existing compiled dependencies, started ExUnit and required `test/oli/torus_doc/markdown/markdown_parser_test.exs`: **26 tests, 0 failures**. This bypassed application/database startup. It verifies the existing Markdown tests, not native schema conformance or persistence.

Representative invocation, from repository root:

```sh
elixir -pa '_build/dev/lib/*/ebin' -e '
Code.compiler_options(ignore_module_conflict: true)
for p <- ~w(inline_parser block_parser table_parser markdown_parser),
  do: Code.require_file("lib/oli/torus_doc/markdown/#{p}.ex")
ExUnit.start()
Code.require_file("test/oli/torus_doc/markdown/markdown_parser_test.exs")
'
```

`ignore_module_conflict` allows loading current source over already compiled versions in this disposable VM; it does not alter repository/compiler configuration. Existing `_build/dev` dependencies are required. Additional direct calls to `MarkdownParser.parse/1` and `PageParser.parse_page/1` produced these observations:

| Probe | Observed result |
|---|---|
| `**bold** *italic* ~~strike~~` | Correct strong/em/strikethrough text marks. |
| `:term[word]{id="x"}` and `Text :term[word]` | `callout_inline`, with optional ID. |
| `![alt](image.png)` | Paragraph containing `img_inline`, src and alt; not `img`. |
| Simple GFM pipe table | `table/tr/th/td`; cells contain bare text leaves. |
| Center-aligned GFM pipe table | Table generated, `align` absent. |
| Nested bullet list | Nested `ul` sibling following the parent `li`. |
| `Text <sup>2</sup> <sub>2</sub> <u>under</u>` | Literal HTML in a text leaf, no formatting marks. |
| `<sup>2</sup> <sub>2</sub> <u>under</u>` at block start | `{:ok, []}`. |
| `Text <mark>highlight</mark>` | Literal HTML in text. |
| `<div>lost</div>` | `{:ok, []}`. |
| `---` | `{:ok, []}`. |
| Group with `purpose: example` | Accepted, default vertical layout. |
| Group with `purpose: priorknowledgecheck` | Rejected by purpose allowlist. |
| Group containing another group | Rejected: “Groups cannot contain other groups.” |
| `bank-selection` with empty clauses | Accepted as bank_selection intermediate representation. No realization assertion. |
| `alternatives` YAML block | Rejected as unknown block type. |

The full application suite, HTML rendering of all cases, native JSON schema validation of generated nodes, and persisted end-to-end page import were not run. The tables distinguish source-proven handlers from runtime findings; neither README claims nor permissive parsing were treated as complete support.

## 6. Source index and completeness check

All paths below are repository-relative. Links resolve from this report.

- Native page wrappers/types, purposes and nesting: [assets/src/data/content/resource.ts](../../../../assets/src/data/content/resource.ts).
- All 14 native marks: [assets/src/data/content/model/text.ts](../../../../assets/src/data/content/model/text.ts).
- All named inline/block/child element types and properties: [assets/src/data/content/model/elements/types.ts](../../../../assets/src/data/content/model/elements/types.ts).
- Native structured element schema/placement: [assets/src/data/content/model/schema.ts](../../../../assets/src/data/content/model/schema.ts).
- Native bank logic: [assets/src/data/content/bank.ts](../../../../assets/src/data/content/bank.ts).
- Actual YAML entry/parser/converter: [lib/oli/torus_doc.ex](../../../../lib/oli/torus_doc.ex), [page_parser.ex](../../../../lib/oli/torus_doc/page_parser.ex), [page_converter.ex](../../../../lib/oli/torus_doc/page_converter.ex).
- Actual Markdown path: [markdown_parser.ex](../../../../lib/oli/torus_doc/markdown/markdown_parser.ex), [inline_parser.ex](../../../../lib/oli/torus_doc/markdown/inline_parser.ex), [block_parser.ex](../../../../lib/oli/torus_doc/markdown/block_parser.ex), [table_parser.ex](../../../../lib/oli/torus_doc/markdown/table_parser.ex).
- Native page/rendering dispatch: [lib/oli/rendering/elements.ex](../../../../lib/oli/rendering/elements.ex), [content/html.ex](../../../../lib/oli/rendering/content/html.ex).
- Executed tests: [test/oli/torus_doc/markdown/markdown_parser_test.exs](../../../../test/oli/torus_doc/markdown/markdown_parser_test.exs). Additional page-fixture references: [page_converter_test.exs](../../../../test/oli/torus_doc/page_converter_test.exs), [page_parser_test.exs](../../../../test/oli/torus_doc/page_parser_test.exs).

Completeness boundary: every native mark, every literal element type declared in `elements/types.ts`, and all ten members of the `ResourceContent` union are covered in the tables (heading levels grouped; current/legacy code distinguished). Native properties that change content fidelity—captions, media details, list/table styles, link types, group behavior, IDs, direction and metadata—are accounted for in their rows or the cross-cutting table. This is current basic-page capability coverage, not an inventory of activity content or a proposed TorusDoc expansion.

# Full TorusDoc support for basic pages

This document explores extending TorusDoc to represent the full native basic-page model inventoried in [basic-support.md](basic-support.md). It describes proposed syntax and implementation requirements, not currently executable functionality or an approved implementation plan.

## Inline StructuredContent Support

**Every capability in the inline table is representable using familiar Markdown plus a small, consistent extension grammar.** The larger challenge is preserving Torus's exact structure, attributes, and references, rather than finding sufficient syntax.

The proposed approach uses ordinary Markdown where it maps cleanly, attributed text spans for additional marks, and named inline directives for structured elements. Complex payloads, such as popup content, use YAML definitions referenced from inline text.

This section covers only StructuredContent inline capabilities. It does not establish full support for block elements, other page elements, or activity internals.

### Familiar Markdown constructions

| Capability | Proposed syntax |
|---|---|
| Plain text | Ordinary text |
| Bold | `**bold**` |
| Italic | `*italic*` |
| Inline code | Backtick-delimited text |
| Strikethrough | `~~removed~~` |
| Hard line break | Markdown backslash followed by a newline |
| External hyperlink | `[label](https://example.org)` |
| Inline image | `![description](image.png)` |
| Inline LaTeX formula | `\(x + y\)` |

Strikethrough is an established [GFM extension](https://github.github.com/gfm/#strikethrough-extension-). The formula syntax already has a TorusDoc implementation.

Attribute suffixes would extend links and images without replacing their familiar notation:

```markdown
[Website](https://example.org){target="_blank" id="link-1"}

![Cell diagram](cell.png){width="240" height="160" id="image-1"}
```

TorusDoc would need to implement and precisely specify this attribute syntax, including attribute value types. Image dimensions in the native model can be numbers or strings; the examples above do not settle how that distinction is encoded.

### Attributed spans for all text marks

[Pandoc's bracketed spans](https://pandoc.org/MANUAL.html#extension-bracketed_spans) provide a useful precedent:

```markdown
[text]{.underline}
```

TorusDoc could adopt that construction with an explicit mapping to native marks:

| Native mark | Proposed syntax |
|---|---|
| `underline` | `[text]{.underline}` |
| `sup` | `[text]{.sup}` |
| `sub` | `[text]{.sub}` |
| `doublesub` | `[text]{.doublesub}` |
| `mark` | `[text]{.mark}` |
| `del` | `[text]{.del}` |
| `var` | `[text]{.var}` |
| `term` | `[text]{.term}` |
| `foreign` | `[text]{.foreign}` |
| `deemphasis` | `[text]{.deemphasis}` |

These cover the ten marks beyond bold, italic, code, and strikethrough. All 14 native mark names should be allowed in the explicit span form, even when a Markdown shorthand exists. This gives the exporter an unambiguous representation for difficult combinations:

```markdown
[text]{.strong .em .underline}
[a*b`c]{.code .strong}
```

These examples illustrate the intended representation. The grammar must define escaping and whether a code-marked span body is literal or recursively parsed; the second example cannot be treated as a finalized parsing rule.

[Pandoc also supports](https://pandoc.org/MANUAL.html#superscripts-and-subscripts) `^superscript^` and `~subscript~`. Those could be optional conveniences. Starting with attributed spans covers every mark uniformly and avoids additional delimiter interactions.

The following distinctions must remain explicit:

- `[word]{.term}` means the native text mark. Existing `:term[word]` produces a `callout_inline` element. Preserve or explicitly version that existing behavior rather than silently reinterpreting it.
- `[bonjour]{.foreign}` means the native text mark. A foreign-language element additionally carries language and child structure.
- `[text]{.del}` means the native deleted-text mark. `~~text~~` continues to mean the separate `strikethrough` mark.

Combined marks require deliberate semantics across nested elements: apply marks to eligible text leaves while respecting each element's child contract, rather than assuming every descendant can accept arbitrary formatting.

### Named directives for structured inline elements

Existing `:term[...]` syntax resembles the [CommonMark generic-directive proposal](https://talk.commonmark.org/t/generic-directives-plugins-syntax/444). That proposal is a useful extension convention, but is not part of standard CommonMark. The constructions here are a TorusDoc dialect, not a claim of universal Markdown compatibility.

| Capability | Proposed syntax | Required mapping |
|---|---|---|
| Typed Torus page link | `[Next page](page-reference){linkType="page" anchor="summary"}` | Resolve and preserve native page-link metadata |
| Typed media-library link | `[Download](media-reference){linkType="media_library"}` | Resolve and preserve media identity |
| LaTeX formula with attributes | `:formula[x + y]{subtype="latex" id="f1" legacyBlockRendered="false"}` | Treat formula body as literal source |
| MathML formula | `:formula[]{ref="math1"}` | Load exact MathML source and attributes from a definition |
| Inline callout | `:callout[**Important** word]{id="c1"}` | Parse supported rich children into `callout_inline` |
| Foreign-language span | `:foreign[Bonjour]{lang="fr" id="fr1"}` | Emit a `foreign` element |
| Citation / bibliography reference | `:cite[Source]{bibref="42" id="cite1"}` | Emit `cite` with a native numeric `bibref`, connected to the page bibliography |
| Popup / popover | `:popup[More information]{ref="popup1"}` | Load trigger, rich content, and optional audio |
| Command button | `:command[Play]{ref="play1"}` | Load message, target, style, and toggle states |
| Input reference | `:input[answer]{id="input1"}` | Preserve the native node and contextual meaning |

Explicit `linkType` avoids inferring semantics from an arbitrary URL. Symbolic page/media references require a documented resolver; native values must also remain expressible. `ref` is proposed interchange syntax and need not become a field on the emitted native node.

MathML, popup, and command payloads can be large or nested. Referenced definitions keep prose readable while retaining the full payload. An illustrative TorusDoc YAML fragment is:

```yaml
inline_defs:
  popup1:
    trigger: click
    content_md: |
      A **longer explanation**, with multiple paragraphs.

      Additional information.
    audioSrc: explanation.mp3
    audioType: audio/mpeg

  play1:
    target: video-1
    style: button
    message: play
    toggleStates:
      - title: Play
        message: play
      - title: Pause
        message: pause

  math1:
    subtype: mathml
    src: '<math><mi>x</mi></math>'
    legacyBlockRendered: false
```

The location, scope, reuse semantics, and schema of `inline_defs` remain design decisions. The popup content must ultimately support its complete native rich-text payload; the `content_md` example alone does not establish that coverage. A typed native payload alternative may be needed for content outside the supported Markdown profile.

If every payload must instead be embedded directly in a single Markdown string, full representation is still feasible. Popup content and toggle-state arrays would require quoted structured payloads or another nested grammar. Referenced YAML definitions are easier to author and inspect.

### Requirements for full fidelity

Covering the table's element names is achievable with this syntax. Full support additionally requires the following:

1. **Preserve native attributes and IDs.** Retain supplied IDs, dimension number/string types, formula subtype/source/flags, link metadata, audio fields, and toggle arrays. Generate IDs only for new nodes that need them. Define omission/default behavior deliberately.
2. **Use a nesting-aware parser.** Current regular-expression preprocessing cannot reliably handle nested brackets, escaped delimiters, rich directive children, or directives inside code. Extending that regex approach would be fragile. Define delimiter precedence, literal contexts, escaping, and attribute typing as a grammar.
3. **Handle every mark exactly.** Preserve all 14 marks and their combinations. Current adjacent-text merging compares only seven marks; merging must account for the complete mark set before adding the remaining marks.
4. **Honor native child contracts.** Generate required void children and enforce permitted children for each element. A general directive grammar must not imply arbitrary nesting is valid. Reconcile differences between TypeScript definitions, schema rules, editor normalization, and renderers.
5. **Validate references and behavior.** Citations need bibliography entries; typed links need resolution; command targets and input references need contextual validation. Syntax alone does not establish working behavior. Some referenced objects may live outside the inline scope explored here.
6. **Implement a reverse serializer.** Native JSON → TorusDoc → native JSON must preserve the agreed structure, attributes, identities, and reference relationships. Readable Markdown can normalize equivalent text-leaf segmentation; strict preservation of every original leaf boundary requires an explicit representation.
7. **Report unsupported or malformed content.** Do not silently flatten unknown inline elements or discard attributes. Establish validation errors and an explicit preservation mechanism for native payloads beyond the readable syntax profile.

Verification should cover every inline-table row, all mark combinations relevant to serialization, nesting and escaping, code/literal contexts, exact formula source, attribute types, IDs, void children, and reference resolution. Round-trip assertions should compare canonical native trees under a documented normalization policy; rendering parity supplements structural checks.

### Feasibility and implementation scope

The recommended direction is **Markdown + attributed spans + named directives + referenced YAML payloads**. It covers every inline-table row with a coherent authoring format. There is no apparent representational blocker.

Implementation is a substantive codec enhancement, especially for parsing, export, native-model normalization, and reference validation. Ordinary Markdown support provides a starting point, but accepting syntax is not equivalent to full native support or lossless round trips.

Repository grounding:

- [Native text marks](../../../../assets/src/data/content/model/text.ts)
- [Native element definitions](../../../../assets/src/data/content/model/elements/types.ts)
- [Native schema](../../../../assets/src/data/content/model/schema.ts)
- [Current inline parser](../../../../lib/oli/torus_doc/markdown/inline_parser.ex)
- [Current Markdown pipeline](../../../../lib/oli/torus_doc/markdown/markdown_parser.ex)

This exploration makes no code changes and does not claim an implemented or tested extension grammar.

## Block StructuredContent Support

**All block-table capabilities can be represented with ordinary Markdown plus one consistent block-directive mechanism: fenced directives, typed YAML options, and named child sections.** Common prose stays simple while tables, media, semantic structures, and legacy representations have an explicit form.

Everything in this section is proposed TorusDoc syntax. It covers the StructuredContent block table in [basic-support.md](basic-support.md), not the other page elements outside StructuredContent.

### Inspiration and recommended direction

| Source | Useful idea | Application to TorusDoc |
|---|---|---|
| [Pandoc](https://pandoc.org/MANUAL.html#pandocs-markdown) | Fenced containers, attributes, definition lists, extended tables | Familiar Markdown shorthand and attributed containers |
| [MyST / reStructuredText](https://mystmd.org/guide/quickstart-myst-markdown) | Named directives with options and parsed or literal bodies | One extension mechanism for all specialized blocks |
| [AsciiDoc](https://docs.asciidoctor.org/asciidoc/latest/tables/span-cells/) | Explicit cell properties and spans | Structured tables with per-cell metadata |

MyST supplies the strongest overall pattern for extensibility. TorusDoc should borrow these ideas without attempting compatibility with every syntax these formats support.

### One block-extension grammar

Use a named colon fence, an optional YAML options header, and a body:

```markdown
:::image
---
id: cell-image
src: cell.png
alt: A diagram of a cell
width: 480
---

:::caption
A **cell** and its major structures.
:::

:::
```

The general rules are:

- The directive name identifies the native element.
- An optional `---` header carries typed YAML properties.
- The body is Markdown, literal source, or named child sections, according to the directive.
- Child sections map to specific native fields; they do not introduce extra native wrapper elements.
- Nesting is parsed structurally. Code fences and literal bodies protect their contents from directive parsing.

This exact grammar is TorusDoc-specific. The YAML header avoids extending inline attribute strings to accommodate arrays, objects, booleans, and numeric/string distinctions. The parser must distinguish an options header from body content by its position immediately after the opening directive.

Every block should have an explicit directive representation, even when Markdown shorthand exists. This provides a consistent way to preserve IDs and properties during export. Directive names may be readable aliases for native types, but the mapping must be explicit and versioned.

### Ordinary text, lists, and quotations

| Native capability | Readable shorthand | Explicit representation |
|---|---|---|
| Paragraph | Ordinary paragraph | `paragraph` directive |
| Headings 1–6 | `#` through `######` | `heading` with `level` |
| Unordered list | Markdown bullets | `list` with `ordered: false` and `style` |
| Ordered list | Markdown numbering | `list` with `ordered: true` and `style` |
| List item and nested lists | Markdown indentation | Nested `item` and `list` directives |
| Description list | Pandoc-style term followed by `: definition` | `description-list`, `term`, and `description` sections |
| Description-list term (`dt`) | Term in description-list shorthand | `term` section |
| Description-list definition (`dd`) | Definition in description-list shorthand | `description` section |
| Blockquote | `>` | `blockquote` directive |

For example:

```markdown
:::list
---
ordered: true
style: lower-roman
id: procedure
---

:::item
First step.
:::

:::item
Second step.
:::

:::
```

For description lists, the explicit form also preserves the native rich `title`, individual `dt`/`dd` IDs, and multiple definitions.

Markdown numbering does not imply a native Torus `start` property; the current interface does not declare one. Blockquotes currently permit paragraph children, so supporting broader Markdown quotation syntax must not silently create incompatible children.

Nested lists require a deliberate native mapping. Current types/schema permit arrangements that differ from conventional Markdown ASTs. The codec must preserve supported native structures rather than assume a generic Markdown serializer will do so. This also addresses the current importer behavior that places nested lists as siblings of the preceding `li` and emits simple list-item contents without the expected block structure.

### Code, formulas, and legacy structures

| Capability | Proposed representation |
|---|---|
| Current code block | Ordinary fenced code; explicit `code` directive for caption, ID, and other properties |
| Legacy code block and `code_line` | `code` with `representation: lines`, containing `code-line` sections |
| Legacy `math` and `math_line` | `math` containing `math-line` sections |
| Display LaTeX formula | `$$` shorthand; explicit `formula` directive |
| Display MathML formula | `formula` with `subtype: mathml` |
| ECL REPL | Explicit `ecl` directive with literal code body |

An explicit formula could be:

```markdown
:::formula
---
id: equation-1
subtype: latex
legacyBlockRendered: false
---
x^2 + y^2 = z^2
:::
```

Formula bodies are literal. MathML remains source text rather than being interpreted as HTML. Current code and ECL bodies are likewise literal, with caption metadata stored in options or a referenced definition. A string such as `:::caption` inside source code must not accidentally become a child section.

The grammar must specify how literal bodies containing closing-fence lines are escaped or delimited, for example through longer outer fences or a referenced literal source. Exact whitespace and trailing-newline preservation also need a defined representation.

Legacy line-based representations require explicit support. Converting them to current code strings or formulas can discard line IDs, marks, and structure. A `representation` option is codec metadata, not an additional native property. Line-section bodies must preserve their native text leaves and marks, using the inline representation or an explicit native payload when necessary.

### Tables: shorthand and explicit structure

Pipe tables remain useful for simple rectangular tables, but cannot comfortably express everything Torus supports. Use the same directive grammar for complete tables:

```markdown
:::table
---
id: results
border: solid
rowstyle: alternating
---

:::caption
Results by **condition**.
:::

:::row

:::header
---
colspan: 2
align: center
---
Measurements
:::

:::

:::row

:::cell
First condition.
:::

:::cell
Second condition.
:::

:::

:::
```

| Native capability | Mapping |
|---|---|
| `table` | `table` directive |
| `tr` | `row` section |
| `th` | `header` section |
| `td` | `cell` section |
| Alignment and merged cells | Cell options: `align`, `rowspan`, `colspan` |
| `tc` conjugation cell | `conjugation-cell` with `audioSrc`, `audioType`, and `pronouns` |
| Rich cell content | Parsed block content within each cell |
| Captions and table appearance | `caption` section plus table options |
| IDs | Options on table, rows, and cells |

The parser should validate the occupied grid, including row spans, and reject overlapping cells. Cell content must respect Torus's supported children; parsed Markdown does not automatically mean every block type is valid inside a cell. Simple pipe-table cells must be converted into valid native child structures rather than bare text leaves.

Pandoc grid tables and AsciiDoc tables are useful precedents, but another specialized table grammar adds complexity when nested directives already cover the full model. Pipe tables can compile to the same native representation, including correct alignment mapping.

### Media and embedded content

Use explicit directives for every block media type:

| Native element | Directive | Properties |
|---|---|---|
| `img` | `image` | Source, alt text, dimensions, caption, legacy display |
| `youtube` | `youtube` | Source, timing, dimensions, alt text, caption, legacy display |
| `audio` | `audio` | Source, alt text, caption |
| `video` | `video` | Source array, poster, caption tracks, dimensions, alt text |
| `iframe` | `iframe` | Source/type, target ID, listening, dimensions, accessible title, caption, legacy display |

Typed YAML handles video's nested properties naturally:

```markdown
:::video
---
id: demonstration
src:
  - url: demonstration.mp4
    contenttype: video/mp4
poster: demonstration.jpg
captions:
  - language_code: en
    label: English
    src: demonstration-en.vtt
width: 640
height: 360
alt: Demonstration of the procedure
---
:::
```

Here, `captions` means subtitle tracks. It must not be confused with a rich descriptive caption: the current native `Video` interface does not declare the latter.

Retain `![alt](src)` as an inline image and require `image` for a block image. [MyST image and figure conventions](https://mystmd.org/guide/figures) provide useful inspiration, but Torus benefits from an explicit distinction rather than changing node type based on paragraph placement.

### Semantic blocks and supporting children

| Capability | Directive / sections |
|---|---|
| Block callout | `callout` with parsed body |
| Figure | `figure`, `title`, and body |
| Definition | `definition` with `term` option; `meaning`, `translation`, and `pronunciation` sections |
| Definition meaning | `meaning` section |
| Translation | `translation` section |
| Pronunciation | `pronunciation` with audio options and text-block body |
| Dialog | `dialog` with title/speakers options and `line` sections |
| Dialog line | `line` with speaker reference and parsed body |
| Conjugation | `conjugation` with title/verb options, `pronunciation`, and `table` sections |

For example:

```markdown
:::definition
---
term: photosynthesis
---

:::meaning
The process by which plants convert light into chemical energy.
:::

:::translation
Photosynthèse
:::

:::pronunciation
---
src: photosynthesis.mp3
contenttype: audio/mpeg
---
Photosynthesis
:::

:::
```

These sections map directly into native fields such as `meanings`, `translations`, and `pronunciation`; they are not all ordinary `children` entries. Likewise, dialog speakers belong in the `speakers` array, dialog lines in `lines`, and a conjugation table in `table`. Named sections make one grammar work across these different native shapes.

A figure's rich title is distinct from a media caption. The codec must preserve the native field and allowed child types rather than infer one from the other. Supporting child sections must retain their IDs and native properties where applicable.

### Triggers, navigation, and captions

| Capability | Proposed representation |
|---|---|
| Content trigger | `trigger` with `trigger_type: content` and literal `prompt` option |
| Page-navigation block | `page-link` with native `idref` and `purpose` |
| Rich captions | Named `caption` section on elements that support captions |
| Legacy string captions | Explicit string-valued `caption` option |

A rich caption and a legacy string caption must remain distinguishable for exact preservation. Supplying both is an error. Caption sections must honor the native caption child contract rather than accept arbitrary block content.

A `page-link` directive remains separate from an inline hyperlink. Markdown horizontal rules must not acquire page-break semantics; native page breaks belong to the inventory of page elements outside StructuredContent.

### Implementation requirements and feasibility

The syntax is feasible, but full support requires more than adding directive handlers:

1. **A real block parser** handles nesting, options, literal bodies, delimiter collisions, and source locations.
2. **A native-model mapping registry** defines each directive's properties, named sections, child restrictions, defaults, and shorthand conversions.
3. **Resolution of existing model inconsistencies** establishes a documented authoritative contract where TypeScript interfaces, editor schema, normalization, and rendering disagree, including semantic children and table cells.
4. **A reverse serializer** chooses shorthand when safe and explicit directives when needed to preserve structure and identity.
5. **Round-trip coverage** exercises every block-table row, including legacy representations, IDs, rich captions, literal-source whitespace, list structure, and table spans.
6. **An explicit native payload form** preserves shapes beyond the readable profile, with validation rather than silent flattening or discarded properties.

The recommended direction is one fenced-directive grammar with typed options and named sections, keeping Markdown as shorthand. This covers all block rows without requiring separate specialized syntaxes for media, tables, definitions, dialogs, and conjugations. Existing inline definitions and future block definitions should share a coherent policy for scope, reference resolution, payload typing, and identity.

Repository grounding:

- [Native element definitions](../../../../assets/src/data/content/model/elements/types.ts)
- [Native schema](../../../../assets/src/data/content/model/schema.ts)
- [Trigger model](../../../../assets/src/data/triggers.ts)
- [Current block parser](../../../../lib/oli/torus_doc/markdown/block_parser.ex)
- [Current table parser](../../../../lib/oli/torus_doc/markdown/table_parser.ex)
- [Current Markdown pipeline](../../../../lib/oli/torus_doc/markdown/markdown_parser.ex)

This remains an exploration, not an implemented or tested grammar. No application code changes are proposed by this document update itself.

## Page Elements Outside StructuredContent

This layer is substantially simpler syntactically: YAML already expresses the native page tree well. The recommended approach is a thin, versioned YAML representation close to native field names, with Markdown used inside StructuredContent. The deeper work is identity, reference resolution, nesting validation, and preservation.

### One page tree and recursive parser

Use native element names and `children` consistently, with `body_md` as the readable alternative to native StructuredContent children:

```yaml
format_version: "1"
type: page
title: Introduction
graded: false

objectives:
  attached: [101]
tags: [201]

content:
  version: "0.1.0"
  model:
    - type: content
      id: introduction
      editor: slate
      textDirection: ltr
      body_md: |
        # Introduction

        Welcome to the lesson.

    - type: group
      id: worked-example
      purpose: example
      layout: vertical
      audience: always
      paginationMode: normal
      children:
        - type: content
          id: example-explanation
          body_md: |
            Consider the following example.

    - type: break
      id: next-page
```

This is proposed syntax. `format_version` describes TorusDoc, while `content.version` describes native page content. They remain separate.

This representation is slightly more verbose than the current `blocks` format, but minimizes translation rules. Existing `prose`, `blocks`, `activity_reference`, `bank-selection`, and `pagination_mode` can remain input aliases under a documented compatibility policy. Export should produce one canonical form; conflicting aliases should be rejected.

Avoid introducing a second set of YAML names for every native property. Existing native names mix conventions, but matching them is simpler than maintaining a comprehensive renaming layer.

### Coverage

| Capability | Proposed representation |
|---|---|
| StructuredContent wrapper | `type: content`, ID, `editor`, `textDirection`, and either `body_md` or native `children` |
| Activity placement | `type: activity-reference` with an explicitly typed activity reference |
| Existing activity-reference alias | Compatibility input alias; canonical export uses `activity-reference` |
| Bank selection | `type: selection`, `count`, `pointsPerActivity`, native recursive `logic` |
| Purpose groups | `type: group` with purpose, layout, audience, pagination, trigger, and children |
| Survey | `type: survey`, title, children |
| Report placement | `type: report`, activity reference, `reportType`, title, children |
| Alternatives placement | `type: alternatives`, referenced Alternatives resource, branch children |
| Alternative branch | `type: alternative`, `value`, children |
| Learning Objectives display | Native mode, sub-objective setting, and per-objective configurations |
| Page break | `type: break` |

Examples, checkpoints, quizzes, labs, and the other purpose labels remain values of `group.purpose`. The supported native vocabulary includes `none`, `checkpoint`, `didigetthis`, `example`, `labactivity`, `learnbydoing`, `learnmore`, `manystudentswonder`, `priorknowledgecheck`, `quiz`, `simulation`, and `walkthrough`. Existing TorusDoc values such as `myresponse` need an explicit compatibility decision rather than silent conversion.

Validate group layout (`vertical`, `deck`), pagination (`normal`, `manualReveal`, `automatedReveal`), and audience (`always`, `instructor`, `feedback`, `never`). Survey fields outside the native title/children contract must not be advertised as supported delivery behavior merely because the current converter emits them.

### A consistent reference policy

The editor and persisted page content both use numeric `activity_id` resource references. Revision slugs remain separate activity metadata; the TorusDoc converter emits only `activity_id` on reference nodes.

Use an explicit interchange reference:

```yaml
- type: activity-reference
  id: question-placement
  activity:
    resource_id: 123
```

For portable bundles, allow a local reference instead:

```yaml
activity:
  local: question-1
```

A resolver converts the reference to the identity required by the destination. Each reference specifies exactly one supported identity form. Node `id` remains the placement identity, separate from the referenced resource identity.

Apply the same policy to activities, report activities, Alternatives resources, objective/page links, tags, and bibliography dependencies. Fields already unambiguously defined as native resource IDs can retain scalar numeric values; symbolic references should use explicit objects. The exact interchange field names for each reference-bearing element remain a schema design decision.

Activity definitions remain separate from placements. A bundle can contain both, but broadening activity-model support is a separate undertaking. Reference resolution must verify resource kind and project scope as well as existence.

### Preserve native bank logic

Use the existing expression tree directly:

```yaml
- type: selection
  id: practice-selection
  count: 3
  pointsPerActivity: 0
  logic:
    conditions:
      operator: all
      children:
        - fact: tags
          operator: contains
          value: [201]
        - operator: any
          children:
            - fact: type
              operator: equals
              value: oli_multi_choice
            - fact: text
              operator: contains
              value: photosynthesis
```

Preserve `conditions: null`, nested `all`/`any`, array order, and omitted versus zero points. Use native operators (`contains`, `does_not_contain`, `equals`, `does_not_equal`) rather than the current converter's alternative vocabulary.

This example is illustrative, not an executed selection fixture. Native types describe recursive logic, but the frontend validity helper explicitly assumes a shallow expression. Full support needs verification through selection execution and subsequent UI editing, including allowed fact/operator/value combinations.

### Context-aware container validation

One recursive parser can read all containers, followed by whole-tree validation against native rules:

- `alternative` belongs under `alternatives`, not at page root.
- Alternatives cannot contain another Alternatives placement, including through intervening groups.
- Surveys cannot nest within surveys.
- Reports accept activity-reference children.
- Learning Objectives displays belong at page root.
- Groups have additional restrictions involving purpose-bearing ancestors and descendants.

These constraints are more nuanced than unrestricted recursion or the current parser's blanket rejection of nested groups and surveys. Use the same validation contract across YAML import and editor writes, with errors identifying paths such as `content.model[2].children[1]`.

### Alternatives depend on an external definition

An Alternatives placement holds branch content, while strategy and available options come from a separate Alternatives resource. Full support requires preserving/resolving `alternatives_id`, preserving branch `value` identifiers, checking branches against the referenced definition, and respecting existing feature and strategy validation.

Do not move strategy configuration onto the placement merely because YAML permits it. Portable documents can bundle the referenced resource separately; experiment configuration remains a separate dependency where applicable.

### Learning Objectives: attachments, display, and resolved membership

Keep three concerns distinct: page objective attachments (`objectives.attached`), the display element, and objectives resolved from the page's container and activities.

The display can use its native shape:

```yaml
- type: learning_objectives
  id: objectives-introduction
  mode: introduction
  include_sub_objectives: true
  learning_objectives:
    - resource_id: 101
      enabled: true
      revisit_pages: [301]
      practice_pages: [302]
```

The editor reconciles these rows on page load against resolved objectives. Stored rows are display configuration, not the authority for objective membership. The codec should preserve stored configuration, while contextual validation explains mismatches. Import must not silently attach objectives or rewrite membership to make the display appear valid.

Test codec round-trip preservation separately from changes caused by later editor reconciliation. Both `introduction` and `summary` modes, sub-objective settings, enabled flags, and revisit/practice references need coverage.

### Page metadata and preservation

| Concern | Proposed location / behavior |
|---|---|
| Title and graded flag | Page fields |
| Resource identity and revision/concurrency context | Explicit document/transport identity, separate from node IDs |
| Objective attachments and tags | Page revision fields |
| Bibliography and page trigger | Under `content` |
| Group trigger | On the group |
| Rich descendant IDs | Preserved by the Markdown/directive codec |
| Inline/block definitions | Explicit interchange-only definitions section |
| Unknown native fields | Explicit preservation mechanism retaining their original location |

Bibliography requires special care: page `bibrefs`, citation numeric `bibref`, and project bibliography entries are related but not interchangeable representations. Existing TypeScript declarations alone do not establish their complete persistence contract.

For StructuredContent, permit exactly one of `body_md` or native `children`:

```yaml
body_md: |
  Readable content.
```

```yaml
children:
  - type: p
    id: paragraph-1
    children:
      - text: Readable content.
```

The native form provides a fidelity option for legacy structures and unsupported extensions. Unknown future page-element types can use an explicit `native` payload wrapper, subject to destination validation. Preservation does not imply that the running application can render or accept every future type. Raw HTML is unnecessary as a universal escape hatch because native payloads express the intended structure more precisely.

Omission, explicit nulls, empty arrays, defaults, and unknown properties need documented preservation rules. Existing attachments, tags, bibliography, and extension fields must not be reset as a side effect of conversion.

### Implementation assessment

This layer requires a schema-driven recursive YAML codec, shared reference resolution, contextual validation, and a reverse serializer. Reuse existing page persistence rules rather than create another save path.

The current importer needs more than a few missing cases: it resets attachments/tags, omits metadata, has inconsistent identities, and restricts nesting. A versioned canonical representation provides a clear target while retaining compatibility aliases.

The recommended representation is native-shaped YAML for page structure and metadata, Markdown/directives for readable rich content, and native payloads for exact preservation. References and native behavior account for most implementation and verification effort.

Repository grounding:

- [Page and container model](../../../../assets/src/data/content/resource.ts)
- [Bank logic](../../../../assets/src/data/content/bank.ts)
- [Learning Objectives reconciliation](../../../../assets/src/data/content/learningObjectives.ts)
- [Page persistence and identity conversion](../../../../lib/oli/authoring/editing/page_editor.ex)
- [Alternatives resolution](../../../../lib/oli/resources/alternatives.ex)
- [Current YAML parser](../../../../lib/oli/torus_doc/page_parser.ex)
- [Current page converter](../../../../lib/oli/torus_doc/page_converter.ex)

## Expected MCP Authoring Performance: TorusDoc and Native JSON

The relevant outcomes are fewer iterations to author a valid page and a higher likelihood that the result fulfills the user's request. Assume both interfaces provide validation and actionable error feedback.

**A mature TorusDoc interface is expected to outperform raw whole-page JSON for common authoring tasks, but not consistently across all Torus features. A hybrid interface is more likely to achieve both fewer iterations and higher fidelity to the request.** This is a prediction based on the examined structures, not an experimentally established result.

The current TorusDoc implementation would lose to a complete JSON interface on coverage and preservation. The proposed full-support version could reverse that for many tasks.

### Why TorusDoc can help

Its main advantage is reducing the structural decisions the model must make. For a request such as “write an explanation with three paragraphs, a list, a formula, and a checkpoint,” Markdown expresses much of the result directly. Native JSON requires constructing wrappers, child arrays, text leaves, marks, IDs, and other contracts. TorusDoc can let the server supply those details deterministically.

This should reduce malformed structures and some mistakes where valid structure fails to express the intended content.

| Task | Expected advantage | Reason |
|---|---|---|
| Create a page dominated by prose, headings, lists, links, and formulas | TorusDoc | Compact, familiar representation closely matches the request |
| Rewrite an explanation while preserving basic formatting | TorusDoc | Less structural bookkeeping |
| Assemble groups, surveys, activity references, and page breaks | Roughly equal | Proposed YAML is essentially the native tree in another notation |
| Create rich media or semantic elements | Depends on interface design | Named constructs help, but required properties and relationships remain |
| Create complex tables or heavily nested content | Uncertain | Explicit directives become verbose and introduce delimiter/nesting errors |
| Make a precise change to an existing complex page | JSON-based targeted operations | Exact field and node targeting minimizes unrelated changes |
| Preserve legacy structures or unusual metadata | Native JSON | No additional representational translation is needed |

TorusDoc's biggest benefit comes from its abstractions, not YAML itself. Replacing JSON braces with YAML indentation offers relatively little advantage when both describe the same detailed tree. Turning a paragraph tree into a Markdown paragraph is a more meaningful simplification.

Extending TorusDoc can also erode that advantage. Nested directives, YAML headers, named sections, external definitions, and literal-body rules constitute a custom language. The model must satisfy both that language and native content rules. JSON is verbose, but its structure is explicit.

### Validation does not establish intent fidelity

Validation feedback helps both approaches, but does not fully address a page that is valid while expressing the wrong thing: for example, an inline image where a block image was requested, or an objectives display where objective attachment was intended.

Clear tool semantics and examples matter more for these failures than serialization format alone. Validation success and fulfillment of the request must be measured separately.

### Recommended MCP interface

Design task-sized operations with both representations available:

- Use TorusDoc for creating content and replacing a selected prose region.
- Use typed operations for inserting activities, configuring groups, attaching objectives, and setting up Alternatives.
- Use node IDs and targeted native updates for precise changes.
- Have the server generate structural defaults, resolve references, and return normalized results with actionable errors.
- Preserve untouched native content instead of requiring the model to regenerate an entire page.

For example, a tool accepting “insert this Markdown into group `example-1`” can outperform both whole-page TorusDoc replacement and whole-page JSON replacement because the model has fewer opportunities to disturb unrelated content.

If choosing one document format for new-page authoring, mature TorusDoc is the preferred candidate for typical prose-heavy basic pages. If choosing one interface for all creation and editing tasks, prefer a native JSON foundation with TorusDoc accepted in rich-content fields.

### Validate the prediction with a benchmark

Compare identical authoring requests across interfaces using the same model, equivalent documentation, validation feedback, and execution budgets. Include both new-page creation and edits to existing complex pages. Measure:

- First-attempt validity.
- Repair calls and total iterations to a successful result.
- Human-assessed fulfillment of the request.
- Unintended changes to existing content, metadata, identities, and references.

Distinguish format comparisons from operation-design comparisons: a targeted JSON tool versus whole-page TorusDoc replacement changes more than serialization. Compare whole-page formats under equivalent conditions, then separately evaluate task-sized hybrid operations.

The strongest prediction is that a hybrid will outperform either format used exclusively, particularly when preservation of existing content counts toward success. No benchmark results are claimed here.

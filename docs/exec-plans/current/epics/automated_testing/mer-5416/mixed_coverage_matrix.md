# MER-5416 Mixed Workflow Coverage Matrix

This matrix is the row-complete workflow coverage inventory for the external `MIXED` spreadsheet tab.

## Source of Truth

- Regression spreadsheet, `MIXED` tab: <https://docs.google.com/spreadsheets/d/1Ne9lo3DfcqS4U25pUE4aYkPy4mlqko9rEb4oU6w79pY/edit?gid=270463718#gid=270463718>
- Spreadsheet ID: `1Ne9lo3DfcqS4U25pUE4aYkPy4mlqko9rEb4oU6w79pY`; tab GID: `270463718`.
- Last reconciled: 2026-07-20. The tab contains 80 cases; all 80 are represented below. The sole identifier difference is trailing whitespace in spreadsheet `INLINE-T`, which is normalized here as `INLINE-T`.

Update this matrix whenever a workflow test changes row coverage. The spreadsheet defines the regression cases; this document records Torus automation status and the workflow test that provides the evidence.

## Spreadsheet Evidence Model

The `MIXED` spreadsheet records four validation surfaces for each row:

- `A: Editing`: the Playwright action performs the authoring interaction and observes the editor result.
- `B: Persisted`: the authored change is saved by the application.
- `C: Preview`: Author Preview renders the authored change.
- `D: Delivery`: the published section renders the authored change for delivery.

For workflow-driven coverage, `B` is evidenced by `C` when the action explicitly flushes pending editor changes, waits for the saved state, and then opens Author Preview as a separate server-rendered request. A successful Preview assertion therefore proves that the change was not only local editor state. A separate editor reload is not required unless a row specifically targets the reopen-editor experience.

It exists to answer three questions durably:

1. which spreadsheet rows are already covered by workflow-driven automation
2. which rows are still planned but not yet covered
3. which follow-up slice owns each remaining row

## Status Legend

- `covered`
  - a workflow-driven test in `assets/automation/tests/torus/course_authoring` already covers the row behavior end to end
- `planned`
  - the row is in scope for workflow migration but not yet implemented
- `needs-triage`
  - the row needs a narrower implementation decision before it can be assigned cleanly to a slice

## Slice Inventory

These slices are coverage batches, not implementation phases.

- `Initial Slice`
  - corresponds to the first implementation PR after the workflow infrastructure is ready
- `Follow-up Slice`
  - corresponds to later grouped coverage PRs
- `Initial Slice`
  - workflow foundation plus representative `CODEBLOCK` and `CALLOUT` coverage
- `Follow-up Slice 2`
  - `CORE` + `INLINE` + `LIST`
- `Follow-up Slice 3`
  - `TABLE`
- `Follow-up Slice 4`
  - `IMAGE` + `FIGURE`
- `Follow-up Slice 5`
  - `YOUTUBE` + `VIDEO` + `WEBPAGE`
- `Follow-up Slice 6`
  - `DIALOG` + `CONJUGATION`
- `Follow-up Slice 7`
  - `DEFINITION` + `DESCRIPTIONLIST` + `THEOREM` + `FORMULA`
- `Follow-up Slice 8`
  - remaining `CODEBLOCK` lifecycle rows such as delete and undo

## Coverage Rules

- Every spreadsheet row must appear exactly once in this document.
- Every row must have a non-empty status for `A: Editing`, `B: Persisted`, `C: Preview`, and `D: Delivery`.
- Every row with an evidence status other than `covered` must have a non-empty `Target Slice`.
- When a workflow test lands, update the affected A/B/C/D evidence statuses and `Workflow Test / Notes`.
- A row may share a Playwright workflow with other rows, but it is `covered` only when its note names the exact workflow/spec and the row-specific action or assertion that proves its behavior. A group-level reference without that mapping is not coverage evidence.
- This matrix is considered complete when all 80 spreadsheet rows are represented, even if some remain `planned`.

## Matrix

### `CORE`

| Row | Spreadsheet Behavior | A: Editing | B: Persisted | C: Preview | D: Delivery | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `CORE-A` | Type in a couple of sentences. Verify there is no editing lag | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `mixed-workflow.spec.ts > MIXED workflow > CORE > CORE-A: typing text persists to author preview and delivery`; `core.workflow.yaml` fills the authored paragraph and the post-Playwright scenario asserts the text in author preview and published delivery. |

### `INLINE`

| Row | Spreadsheet Behavior | A: Editing | B: Persisted | C: Preview | D: Delivery | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `INLINE-C` | Apply bold | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `INLINE-C/D/E/I/J/K/L/M/S/T` in `inline-formatting.workflow.yaml`; exact mark is asserted in Preview and published Delivery. |
| `INLINE-D` | Apply italic | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `INLINE-C/D/E/I/J/K/L/M/S/T` in `inline-formatting.workflow.yaml`; exact mark is asserted in Preview and published Delivery. |
| `INLINE-E` | Apply code | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `INLINE-C/D/E/I/J/K/L/M/S/T` in `inline-formatting.workflow.yaml`; exact mark is asserted in Preview and published Delivery. |
| `INLINE-F` | Create hyperlink to another page in the course | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `INLINE-F` in `inline-internal-link.workflow.yaml`; selected course-page target is asserted in Preview and Delivery. |
| `INLINE-G` | Create hyperlink to an external site | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `INLINE-G` in `inline-external-link.workflow.yaml`; external URL and link text are asserted in Preview and Delivery. |
| `INLINE-I` | Apply underline | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `INLINE-C/D/E/I/J/K/L/M/S/T` in `inline-formatting.workflow.yaml`; exact mark is asserted in Preview and published Delivery. |
| `INLINE-J` | Apply strikethrough | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `INLINE-C/D/E/I/J/K/L/M/S/T` in `inline-formatting.workflow.yaml`; exact mark is asserted in Preview and published Delivery. |
| `INLINE-K` | Apply subscript | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `INLINE-C/D/E/I/J/K/L/M/S/T` in `inline-formatting.workflow.yaml`; exact mark is asserted in Preview and published Delivery. |
| `INLINE-L` | Apply superscript | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `INLINE-C/D/E/I/J/K/L/M/S/T` in `inline-formatting.workflow.yaml`; exact mark is asserted in Preview and published Delivery. |
| `INLINE-M` | Apply term | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `INLINE-C/D/E/I/J/K/L/M/S/T` in `inline-formatting.workflow.yaml`; exact mark is asserted in Preview and published Delivery. |
| `INLINE-N` | Apply foreign. Select a language | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `INLINE-N` in `inline-foreign.workflow.yaml`; Arabic foreign element is asserted in Preview and published Delivery. |
| `INLINE-O` | Apply popup content | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `INLINE-O` in `inline-popup.workflow.yaml`; trigger is asserted in Preview and popup content in published Delivery. |
| `INLINE-R` | Apply inline callout | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `INLINE-R` in `inline-callout.workflow.yaml`; inline callout is asserted in Preview and published Delivery. |
| `INLINE-S` | Change text to be a heading | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `INLINE-C/D/E/I/J/K/L/M/S/T` in `inline-formatting.workflow.yaml`; heading structure is asserted in Preview and published Delivery. |
| `INLINE-T` | Change text direction | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `INLINE-C/D/E/I/J/K/L/M/S/T` in `inline-formatting.workflow.yaml`; RTL direction is asserted in Preview and published Delivery. |

### `LIST`

| Row | Spreadsheet Behavior | A: Editing | B: Persisted | C: Preview | D: Delivery | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `LIST-C` | Customize the bullet style of one of the lists | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `LIST-C/D` in `list-formatting.workflow.yaml`; circle bullet style is asserted in Preview and published Delivery. |
| `LIST-D` | Indent one of the list items | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 2` | `LIST-C/D` in `list-formatting.workflow.yaml`; nested-list indentation is asserted in Preview and published Delivery. |

### `TABLE`

| Row | Spreadsheet Behavior | A: Editing | B: Persisted | C: Preview | D: Delivery | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `TABLE-B` | Add a column | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 3` | `TABLE-B/C/D/E/F` in `table-structure.workflow.yaml`; Preview verifies three cells in the first row and Delivery verifies the table row structure. Verified in Playwright. |
| `TABLE-C` | Add a row | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 3` | `TABLE-B/C/D/E/F` in `table-structure.workflow.yaml`; Preview and Delivery assert a three-row table. Verified in Playwright. |
| `TABLE-D` | Toggle a cell to be a header | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 3` | `TABLE-B/C/D/E/F` in `table-structure.workflow.yaml`; Preview asserts `th` and Delivery asserts `type: th`. Verified in Playwright. |
| `TABLE-E` | Merge the contents of two cells | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 3` | `TABLE-B/C/D/E/F` in `table-structure.workflow.yaml`; Preview and Delivery assert the merged cell's `colspan: 2`. Verified in Playwright. |
| `TABLE-F` | Change the alignment of one cell | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 3` | `TABLE-B/C/D/E/F` in `table-structure.workflow.yaml`; Preview asserts `.text-center` and Delivery asserts `align: center`. Verified in Playwright. |
| `TABLE-G` | Create a second table with four rows and set row style set to Alternating | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 3` | `TABLE-G/H` in `table-styles.workflow.yaml`; creates a baseline first table, then a four-row second table; Preview asserts `table-striped` and Delivery asserts `rowstyle: alternating`. Verified in Playwright. |
| `TABLE-H` | Create a third table with border style set to Hidden | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 3` | `TABLE-G/H` in `table-styles.workflow.yaml`; creates a baseline first table and alternating second table before the hidden-border third table; Preview asserts `table-borderless` and Delivery asserts `border: hidden`. Verified in Playwright. |

### `IMAGE`

| Row | Spreadsheet Behavior | A: Editing | B: Persisted | C: Preview | D: Delivery | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `IMAGE-B` | Insert a block image. In media manager, upload both a PNG and JPG image. Select the PNG | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 4` | `IMAGE-B/C/D/E/F` in `image.workflow.yaml`; uploads JPG then PNG, inserts JPG, and replaces it with PNG so the final authored image is PNG. This intentionally reverses the spreadsheet's B/C order while covering the same insertion and replacement capabilities. |
| `IMAGE-C` | Change the image to the JPG | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 4` | `IMAGE-B/C/D/E/F` in `image.workflow.yaml`; covers image replacement in the agreed reverse order (JPG → PNG), with final PNG asserted in Preview and Delivery. |
| `IMAGE-D` | Enter a caption | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 4` | `IMAGE-B/C/D/E/F` in `image.workflow.yaml`; asserts caption in Preview and Delivery. Verified in Playwright. |
| `IMAGE-E` | Using image settings, specify alternate text | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 4` | `IMAGE-B/C/D/E/F` in `image.workflow.yaml`; asserts alternative text in Preview and Delivery. Verified in Playwright. |
| `IMAGE-F` | Using image settings, define a custom width | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 4` | `IMAGE-B/C/D/E/F` in `image.workflow.yaml`; asserts rendered width in Preview and numeric width in Delivery. Verified in Playwright. |

### `YOUTUBE`

| Row | Spreadsheet Behavior | A: Editing | B: Persisted | C: Preview | D: Delivery | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `YOUTUBE-B` | Insert YouTube video using only the YouTube video id | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 5` | Embed insertion workflow family. |
| `YOUTUBE-C` | Edit the caption of the YouTube video | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 5` | Embed caption workflow family. |
| `YOUTUBE-D` | Click to open the YouTube video in full screen in new tab | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 5` | New-tab behavior may remain browser-only within the workflow. |
| `YOUTUBE-E` | Click to copy the YouTube video URL to the clipboard | `needs-triage` | `needs-triage` | `needs-triage` | `needs-triage` | `Follow-up Slice 5` | Clipboard assertions need a stable local strategy. |
| `YOUTUBE-F` | Using settings menu, change the video to a new id | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 5` | Embed settings workflow family. |
| `YOUTUBE-G` | Using settings menu, set the alternative text for YouTube video | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 5` | Accessibility workflow family. |
| `YOUTUBE-H` | Delete a YouTube video | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 5` | Embed lifecycle workflow family. |
| `YOUTUBE-I` | Undo the deletion (Ctrl-z) | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 5` | Embed lifecycle workflow family. |

### `CODEBLOCK`

| Row | Spreadsheet Behavior | A: Editing | B: Persisted | C: Preview | D: Delivery | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `CODEBLOCK-B` | Change language to Python | `covered` | `covered` | `covered` | `covered` | `Initial Slice` | `mixed-workflow.spec.ts > MIXED workflow > CODEBLOCK > CODEBLOCK-B/C: Python language and formatted source persist to author preview and delivery`; `codeblock.workflow.yaml` selects Python and the assertion scenario verifies the published result. |
| `CODEBLOCK-C` | Edit source of CodeBlock to insert a few lines of actual, formatted Python code | `covered` | `covered` | `covered` | `covered` | `Initial Slice` | `mixed-workflow.spec.ts > MIXED workflow > CODEBLOCK > CODEBLOCK-B/C: Python language and formatted source persist to author preview and delivery`; `codeblock.workflow.yaml` writes `print("mixed workflow code block")` and the assertion scenario verifies it in author preview and published delivery. |
| `CODEBLOCK-D` | Delete the CodeBlock | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 8` | Lifecycle row, separate from insertion coverage. |
| `CODEBLOCK-E` | Undo the deletion (ctrl-z) | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 8` | Lifecycle row, separate from insertion coverage. |

### `VIDEO`

| Row | Spreadsheet Behavior | A: Editing | B: Persisted | C: Preview | D: Delivery | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `VIDEO-B` | Add additional video track via Settings dialog | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 5` | Video settings workflow family. |
| `VIDEO-C` | Add caption track via Settings dialog | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 5` | Accessibility workflow family. |
| `VIDEO-D` | Set poster image via Settings dialog | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 5` | Video settings workflow family. |
| `VIDEO-E` | Set size of the video via Settings dialog | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 5` | Video settings workflow family. |
| `VIDEO-F` | Delete the video | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 5` | Media lifecycle workflow family. |
| `VIDEO-G` | Undo the deletion (ctrl-z) | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 5` | Media lifecycle workflow family. |

### `WEBPAGE`

| Row | Spreadsheet Behavior | A: Editing | B: Persisted | C: Preview | D: Delivery | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `WEBPAGE-A` | Insert webpage (iframe) | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 5` | Embed insertion workflow family. |
| `WEBPAGE-B` | Click to open in new tab | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 5` | New-tab browser behavior plus persist/delivery validation. |
| `WEBPAGE-C` | Click to copy URL | `needs-triage` | `needs-triage` | `needs-triage` | `needs-triage` | `Follow-up Slice 5` | Clipboard assertions need a stable local strategy. |
| `WEBPAGE-D` | Using settings dialog, change the URL | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 5` | Embed settings workflow family. |

### `FORMULA`

| Row | Spreadsheet Behavior | A: Editing | B: Persisted | C: Preview | D: Delivery | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `FORMULA-B` | Insert block formula, change type to Latex, and enter valid Latex | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 7` | Block math workflow family. |

### `CALLOUT`

| Row | Spreadsheet Behavior | A: Editing | B: Persisted | C: Preview | D: Delivery | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `CALLOUT-A` | Insert block callout, enter text | `covered` | `covered` | `covered` | `covered` | `Initial Slice` | `mixed-workflow.spec.ts > MIXED workflow > CALLOUT > CALLOUT-A: block callout text persists to author preview and delivery`; `callout.workflow.yaml` inserts the callout text and the assertion scenario verifies author preview and published delivery. |

### `DEFINITION`

| Row | Spreadsheet Behavior | A: Editing | B: Persisted | C: Preview | D: Delivery | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `DEFINITION-B` | Click edit and change the term, add multiple definitions, a translation and a pronunciation | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 7` | Definition editing workflow family. |

### `FIGURE`

| Row | Spreadsheet Behavior | A: Editing | B: Persisted | C: Preview | D: Delivery | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `FIGURE-B` | Edit Figure title | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 4` | `FIGURE-B/C` in `figure.workflow.yaml`; asserts title in Preview and Delivery. Verified in Playwright. |
| `FIGURE-C` | Insert other block content within Figure content | `covered` | `covered` | `covered` | `covered` | `Follow-up Slice 4` | `FIGURE-B/C` in `figure.workflow.yaml`; inserts nested content and asserts it in Preview and Delivery. Verified in Playwright. |

### `DIALOG`

| Row | Spreadsheet Behavior | A: Editing | B: Persisted | C: Preview | D: Delivery | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `DIALOG-B` | Edit dialog title | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Dialog editing workflow family. |
| `DIALOG-C` | Add a speaker | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Dialog speaker workflow family. |
| `DIALOG-D` | Associate an image with a speaker | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Dialog media workflow family. |
| `DIALOG-E` | Delete a speaker | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Dialog speaker workflow family. |
| `DIALOG-F` | Edit a speaker label | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Dialog speaker workflow family. |
| `DIALOG-G` | Add a dialog line | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Dialog line workflow family. |
| `DIALOG-H` | Edit the text within speaker line | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Dialog line workflow family. |
| `DIALOG-I` | Add content element within speaker line | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Dialog nested-content workflow family. |
| `DIALOG-J` | Toggle the speaker associated with a line | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Dialog line workflow family. |
| `DIALOG-K` | Add a second line | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Dialog line workflow family. |
| `DIALOG-L` | Delete line | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Dialog line workflow family. |

### `CONJUGATION`

| Row | Spreadsheet Behavior | A: Editing | B: Persisted | C: Preview | D: Delivery | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `CONJUGATION-B` | Edit title | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Conjugation editing workflow family. |
| `CONJUGATION-C` | Edit verb | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Conjugation editing workflow family. |
| `CONJUGATION-D` | Edit pronunciation | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Conjugation editing workflow family. |
| `CONJUGATION-E` | Edit conjugation table headers (singular, plural) | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Conjugation table workflow family. |
| `CONJUGATION-F` | Edit conjugate content | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Conjugation table workflow family. |
| `CONJUGATION-G` | Edit conjugate pronouns | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Conjugation table workflow family. |
| `CONJUGATION-H` | Associate audio clip with conjugate | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 6` | Conjugation media workflow family. |

### `DESCRIPTIONLIST`

| Row | Spreadsheet Behavior | A: Editing | B: Persisted | C: Preview | D: Delivery | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `DESCRIPTIONLIST-B` | Edit Description List title | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 7` | Description-list editing workflow family. |
| `DESCRIPTIONLIST-C` | Edit default term and description | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 7` | Description-list editing workflow family. |
| `DESCRIPTIONLIST-D` | Add term | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 7` | Description-list structure workflow family. |
| `DESCRIPTIONLIST-E` | Add multiple definitions | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 7` | Description-list structure workflow family. |

### `THEOREM`

| Row | Spreadsheet Behavior | A: Editing | B: Persisted | C: Preview | D: Delivery | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `THEOREM-B` | Edit title, statement, proof | `planned` | `planned` | `planned` | `planned` | `Follow-up Slice 7` | Theorem editing workflow family. |

# MER-5416 Mixed Workflow Coverage Matrix

This matrix is the row-complete workflow coverage inventory for the external `MIXED` spreadsheet tab.

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
- Every row must have a non-empty `Workflow Status`.
- Every row that is not `covered` must have a non-empty `Target Slice`.
- When a workflow test lands, update both:
  - `Workflow Status`
  - `Workflow Test / Notes`
- This matrix is considered complete when all 80 spreadsheet rows are represented, even if some remain `planned`.

## Matrix

### `CORE`

| Row | Spreadsheet Behavior | Workflow Status | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- |
| `CORE-A` | Type in a couple of sentences. Verify there is no editing lag | `planned` | `Follow-up Slice 2` | Fold into the core text-editing workflow slice. |

### `INLINE`

| Row | Spreadsheet Behavior | Workflow Status | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- |
| `INLINE-C` | Apply bold | `planned` | `Follow-up Slice 2` | Inline formatting workflow family. |
| `INLINE-D` | Apply italic | `planned` | `Follow-up Slice 2` | Inline formatting workflow family. |
| `INLINE-E` | Apply code | `planned` | `Follow-up Slice 2` | Inline formatting workflow family. |
| `INLINE-F` | Create hyperlink to another page in the course | `planned` | `Follow-up Slice 2` | Inline link workflow family. |
| `INLINE-G` | Create hyperlink to an external site | `planned` | `Follow-up Slice 2` | Inline link workflow family. |
| `INLINE-I` | Apply underline | `planned` | `Follow-up Slice 2` | Inline formatting workflow family. |
| `INLINE-J` | Apply strikethrough | `planned` | `Follow-up Slice 2` | Inline formatting workflow family. |
| `INLINE-K` | Apply subscript | `planned` | `Follow-up Slice 2` | Inline formatting workflow family. |
| `INLINE-L` | Apply superscript | `planned` | `Follow-up Slice 2` | Inline formatting workflow family. |
| `INLINE-M` | Apply term | `planned` | `Follow-up Slice 2` | Inline semantic-markup workflow family. |
| `INLINE-N` | Apply foreign. Select a language | `planned` | `Follow-up Slice 2` | Inline semantic-markup workflow family. |
| `INLINE-O` | Apply popup content | `planned` | `Follow-up Slice 2` | Inline popup workflow family. |
| `INLINE-R` | Apply inline callout | `planned` | `Follow-up Slice 2` | Distinct from block callout in `CALLOUT-A`. |
| `INLINE-S` | Change text to be a heading | `planned` | `Follow-up Slice 2` | Block-format workflow family. |
| `INLINE-T` | Change text direction | `planned` | `Follow-up Slice 2` | Directionality workflow family. |

### `LIST`

| Row | Spreadsheet Behavior | Workflow Status | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- |
| `LIST-C` | Customize the bullet style of one of the lists | `planned` | `Follow-up Slice 2` | List formatting workflow family. |
| `LIST-D` | Indent one of the list items | `planned` | `Follow-up Slice 2` | List formatting workflow family. |

### `TABLE`

| Row | Spreadsheet Behavior | Workflow Status | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- |
| `TABLE-B` | Add a column | `planned` | `Follow-up Slice 3` | Table structure workflow family. |
| `TABLE-C` | Add a row | `planned` | `Follow-up Slice 3` | Table structure workflow family. |
| `TABLE-D` | Toggle a cell to be a header | `planned` | `Follow-up Slice 3` | Table semantics workflow family. |
| `TABLE-E` | Merge the contents of two cells | `planned` | `Follow-up Slice 3` | Table structure workflow family. |
| `TABLE-F` | Change the alignment of one cell | `planned` | `Follow-up Slice 3` | Table formatting workflow family. |
| `TABLE-G` | Create a second table with four rows and set row style set to Alternating | `planned` | `Follow-up Slice 3` | Table style workflow family. |
| `TABLE-H` | Create a third table with border style set to Hidden | `planned` | `Follow-up Slice 3` | Table style workflow family. |

### `IMAGE`

| Row | Spreadsheet Behavior | Workflow Status | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- |
| `IMAGE-B` | Insert a block image. In media manager, upload both a PNG and JPG image. Select the PNG | `planned` | `Follow-up Slice 4` | Media insertion workflow family. |
| `IMAGE-C` | Change the image to the JPG | `planned` | `Follow-up Slice 4` | Media replacement workflow family. |
| `IMAGE-D` | Enter a caption | `planned` | `Follow-up Slice 4` | Image caption workflow family. |
| `IMAGE-E` | Using image settings, specify alternate text | `planned` | `Follow-up Slice 4` | Accessibility workflow family. |
| `IMAGE-F` | Using image settings, define a custom width | `planned` | `Follow-up Slice 4` | Media settings workflow family. |

### `YOUTUBE`

| Row | Spreadsheet Behavior | Workflow Status | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- |
| `YOUTUBE-B` | Insert YouTube video using only the YouTube video id | `planned` | `Follow-up Slice 5` | Embed insertion workflow family. |
| `YOUTUBE-C` | Edit the caption of the YouTube video | `planned` | `Follow-up Slice 5` | Embed caption workflow family. |
| `YOUTUBE-D` | Click to open the YouTube video in full screen in new tab | `planned` | `Follow-up Slice 5` | New-tab behavior may remain browser-only within the workflow. |
| `YOUTUBE-E` | Click to copy the YouTube video URL to the clipboard | `needs-triage` | `Follow-up Slice 5` | Clipboard assertions need a stable local strategy. |
| `YOUTUBE-F` | Using settings menu, change the video to a new id | `planned` | `Follow-up Slice 5` | Embed settings workflow family. |
| `YOUTUBE-G` | Using settings menu, set the alternative text for YouTube video | `planned` | `Follow-up Slice 5` | Accessibility workflow family. |
| `YOUTUBE-H` | Delete a YouTube video | `planned` | `Follow-up Slice 5` | Embed lifecycle workflow family. |
| `YOUTUBE-I` | Undo the deletion (Ctrl-z) | `planned` | `Follow-up Slice 5` | Embed lifecycle workflow family. |

### `CODEBLOCK`

| Row | Spreadsheet Behavior | Workflow Status | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- |
| `CODEBLOCK-B` | Change language to Python | `covered` | `Initial Slice` | Covered by `mixed-workflow.spec.ts` code block phase. |
| `CODEBLOCK-C` | Edit source of CodeBlock to insert a few lines of actual, formatted Python code | `covered` | `Initial Slice` | Covered by `mixed-workflow.spec.ts` code block phase. |
| `CODEBLOCK-D` | Delete the CodeBlock | `planned` | `Follow-up Slice 8` | Lifecycle row, separate from insertion coverage. |
| `CODEBLOCK-E` | Undo the deletion (ctrl-z) | `planned` | `Follow-up Slice 8` | Lifecycle row, separate from insertion coverage. |

### `VIDEO`

| Row | Spreadsheet Behavior | Workflow Status | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- |
| `VIDEO-B` | Add additional video track via Settings dialog | `planned` | `Follow-up Slice 5` | Video settings workflow family. |
| `VIDEO-C` | Add caption track via Settings dialog | `planned` | `Follow-up Slice 5` | Accessibility workflow family. |
| `VIDEO-D` | Set poster image via Settings dialog | `planned` | `Follow-up Slice 5` | Video settings workflow family. |
| `VIDEO-E` | Set size of the video via Settings dialog | `planned` | `Follow-up Slice 5` | Video settings workflow family. |
| `VIDEO-F` | Delete the video | `planned` | `Follow-up Slice 5` | Media lifecycle workflow family. |
| `VIDEO-G` | Undo the deletion (ctrl-z) | `planned` | `Follow-up Slice 5` | Media lifecycle workflow family. |

### `WEBPAGE`

| Row | Spreadsheet Behavior | Workflow Status | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- |
| `WEBPAGE-A` | Insert webpage (iframe) | `planned` | `Follow-up Slice 5` | Embed insertion workflow family. |
| `WEBPAGE-B` | Click to open in new tab | `planned` | `Follow-up Slice 5` | New-tab browser behavior plus persist/delivery validation. |
| `WEBPAGE-C` | Click to copy URL | `needs-triage` | `Follow-up Slice 5` | Clipboard assertions need a stable local strategy. |
| `WEBPAGE-D` | Using settings dialog, change the URL | `planned` | `Follow-up Slice 5` | Embed settings workflow family. |

### `FORMULA`

| Row | Spreadsheet Behavior | Workflow Status | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- |
| `FORMULA-B` | Insert block formula, change type to Latex, and enter valid Latex | `planned` | `Follow-up Slice 7` | Block math workflow family. |

### `CALLOUT`

| Row | Spreadsheet Behavior | Workflow Status | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- |
| `CALLOUT-A` | Insert block callout, enter text | `covered` | `Initial Slice` | Covered by `mixed-workflow.spec.ts` callout phase. |

### `DEFINITION`

| Row | Spreadsheet Behavior | Workflow Status | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- |
| `DEFINITION-B` | Click edit and change the term, add multiple definitions, a translation and a pronunciation | `planned` | `Follow-up Slice 7` | Definition editing workflow family. |

### `FIGURE`

| Row | Spreadsheet Behavior | Workflow Status | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- |
| `FIGURE-B` | Edit Figure title | `planned` | `Follow-up Slice 4` | Figure settings workflow family. |
| `FIGURE-C` | Insert other block content within Figure content | `planned` | `Follow-up Slice 4` | Nested-content workflow family. |

### `DIALOG`

| Row | Spreadsheet Behavior | Workflow Status | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- |
| `DIALOG-B` | Edit dialog title | `planned` | `Follow-up Slice 6` | Dialog editing workflow family. |
| `DIALOG-C` | Add a speaker | `planned` | `Follow-up Slice 6` | Dialog speaker workflow family. |
| `DIALOG-D` | Associate an image with a speaker | `planned` | `Follow-up Slice 6` | Dialog media workflow family. |
| `DIALOG-E` | Delete a speaker | `planned` | `Follow-up Slice 6` | Dialog speaker workflow family. |
| `DIALOG-F` | Edit a speaker label | `planned` | `Follow-up Slice 6` | Dialog speaker workflow family. |
| `DIALOG-G` | Add a dialog line | `planned` | `Follow-up Slice 6` | Dialog line workflow family. |
| `DIALOG-H` | Edit the text within speaker line | `planned` | `Follow-up Slice 6` | Dialog line workflow family. |
| `DIALOG-I` | Add content element within speaker line | `planned` | `Follow-up Slice 6` | Dialog nested-content workflow family. |
| `DIALOG-J` | Toggle the speaker associated with a line | `planned` | `Follow-up Slice 6` | Dialog line workflow family. |
| `DIALOG-K` | Add a second line | `planned` | `Follow-up Slice 6` | Dialog line workflow family. |
| `DIALOG-L` | Delete line | `planned` | `Follow-up Slice 6` | Dialog line workflow family. |

### `CONJUGATION`

| Row | Spreadsheet Behavior | Workflow Status | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- |
| `CONJUGATION-B` | Edit title | `planned` | `Follow-up Slice 6` | Conjugation editing workflow family. |
| `CONJUGATION-C` | Edit verb | `planned` | `Follow-up Slice 6` | Conjugation editing workflow family. |
| `CONJUGATION-D` | Edit pronunciation | `planned` | `Follow-up Slice 6` | Conjugation editing workflow family. |
| `CONJUGATION-E` | Edit conjugation table headers (singular, plural) | `planned` | `Follow-up Slice 6` | Conjugation table workflow family. |
| `CONJUGATION-F` | Edit conjugate content | `planned` | `Follow-up Slice 6` | Conjugation table workflow family. |
| `CONJUGATION-G` | Edit conjugate pronouns | `planned` | `Follow-up Slice 6` | Conjugation table workflow family. |
| `CONJUGATION-H` | Associate audio clip with conjugate | `planned` | `Follow-up Slice 6` | Conjugation media workflow family. |

### `DESCRIPTIONLIST`

| Row | Spreadsheet Behavior | Workflow Status | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- |
| `DESCRIPTIONLIST-B` | Edit Description List title | `planned` | `Follow-up Slice 7` | Description-list editing workflow family. |
| `DESCRIPTIONLIST-C` | Edit default term and description | `planned` | `Follow-up Slice 7` | Description-list editing workflow family. |
| `DESCRIPTIONLIST-D` | Add term | `planned` | `Follow-up Slice 7` | Description-list structure workflow family. |
| `DESCRIPTIONLIST-E` | Add multiple definitions | `planned` | `Follow-up Slice 7` | Description-list structure workflow family. |

### `THEOREM`

| Row | Spreadsheet Behavior | Workflow Status | Target Slice | Workflow Test / Notes |
| --- | --- | --- | --- | --- |
| `THEOREM-B` | Edit title, statement, proof | `planned` | `Follow-up Slice 7` | Theorem editing workflow family. |

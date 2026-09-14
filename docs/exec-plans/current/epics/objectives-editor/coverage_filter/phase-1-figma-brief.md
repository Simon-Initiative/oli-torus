# Phase 1 — Governed Figma Brief: Coverage Issues Filter

Work item: `docs/exec-plans/current/epics/objectives-editor/coverage_filter`
Phase: 1 — Figma reconnaissance and governed design mapping (no code produced)

Source of truth: Figma file `iVKgFJwC1iKP7jmJBGILOK` ("Learning Objectives
Updates"). Inspected via Figma MCP on 2026-09-02 after the connection was
restored (no reauthentication error this session).

This brief satisfies the Phase 1 gate in `plan.md`/`fdd.md`: inspect the
named nodes/subnodes and record toolbar placement, count badge, settings
affordance, icons/tokens, and warning states before any UI implementation.
It does not implement or modify any LiveView/HEEx code.

## 0. Node inventory

| Node        | Label (product-supplied) | What it shows                                                                                             | First inspected                                 |
| ----------- | ------------------------ | --------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `365:14554` | Coverage warning (light) | Full page: toolbar default state, per-row inline issue badges, sub-objective warning banner               | 2026-09-02, first pass                          |
| `365:17228` | Coverage warning (dark)  | Same page, dark theme (screenshot only, not walked node-by-node)                                          | 2026-09-02, first pass                          |
| `365:19034` | Coverage filter applied  | Full page with the Coverage Issues filter **active** — toolbar button pressed state, filtered result list | 2026-09-02, second pass (link supplied by user) |
| `365:18532` | Coverage filter settings | Full page with the settings popover **open**, anchored under the gear button                              | 2026-09-02, second pass (link supplied by user) |
| `365:19751` | Settings (light mode)    | The settings popover in isolation, light theme                                                            | 2026-09-02, second pass (link supplied by user) |
| `365:19793` | Settings (dark mode)     | The settings popover in isolation, dark theme                                                             | 2026-09-02, second pass (link supplied by user) |
| `329:532`   | Default (light mode)     | Collapsed objective list; LO 2 carries a coverage issue while still collapsed                             | 2026-09-02, third pass (link supplied by user)  |
| `365:16457` | Expanded - Dark Mode     | Same LO expanded; the specific flagged sub-objective row is outlined in red                               | 2026-09-02, third pass (link supplied by user)  |

**Correction / disclosure**: the first pass of this brief was built from
`365:14554` and `365:17228` only. It did **not** include the settings
popover's open state, the filter-applied toggle state, the dark-mode
settings popover, the collapsed-card issue indicator, or the expanded
red-bordered sub-objective row — those six links were supplied by the user
across two follow-up messages after the first draft. This revision
incorporates them and corrects two conclusions from the first draft: the
"Learn more" link **does** exist in the design, inside the settings
popover, not in the warning banner as originally checked (§5); and the
row-level issue badge is a **bordered pill**, not a filled
`Fill-fill-danger` pill as the first draft assumed (§7, corrected below).

## 1. Toolbar composition (light root, node `365:14702`, confirmed identical in `365:19034`/`365:18532`)

**Superseded by the merged MER-5797 PR (#6820, merged 2026-09-07, commit
`b913d0463a`)**: the flat left-to-right order below was the Figma design's
intent, but the actual merged toolbar in `ObjectivesLive.render/1` is one
`flex w-full flex-wrap items-center gap-2` row containing, in order: the
search box (`OliWeb.Common.SearchInput`, fixed `w-56`), the sort `<form>`,
then a `<div class="ml-auto flex shrink-0 items-center gap-2">` (margin-
left-auto, not a second explicit flex group) holding Download CSV and New
Objective. There is no "Course content" dropdown at all. Coverage
Issues/Settings need a real placement decision against this actual
structure (most likely inserted after the sort form and before the
`ml-auto` div) before Phase 3/4 write any toolbar markup.

Left-to-right order confirmed via metadata + screenshot (Figma intent,
not necessarily current implementation — see warning above):

1. `365:14703` — `Search-Bar` instance (owned by MER-5797's PR, do not touch)
2. `365:14704` — `Title` sort dropdown (owned by MER-5797's PR, do not touch)
3. divider `365:14711`
4. `365:14712` — **Coverage Issues** button (this ticket)
5. `365:14720` — **Settings** icon button (this ticket)
6. divider `365:14724`
7. `502:12519` — `Content filter` ("Course content") instance (owned by
   MER-5797's PR, do not touch)
8. spacer `365:14730`
9. `365:14731` — Download CSV button (existing)
10. `365:14736` — New Objective button (existing, primary/blue)

Screenshot (light, default state): confirms this order and that the
Coverage Issues button and the gear icon sit directly adjacent, both with
light chrome and a visible border, positioned between sort and the content
filter — i.e. inside the existing toolbar `Container`, not a new row.

This confirms the handoff's warning: items 1, 2, 7 are MER-5797's PR's surface.
Items 4 and 5 are the two new controls this ticket owns, inserted between
the existing divider pair without disturbing MER-5797's PR's nodes.

## 2. Coverage Issues button — default (inactive) state (node `365:14712`)

```
[⚠ triangle icon]  Coverage Issues  [1]
```

- Container: `Button`, rounded 6px, 1px border, horizontal padding 13/8,
  neutral background (`Background-bg-primary`).
- Icon (`365:14713`): triangle-alert glyph, stroke `#CE2C31`
  (`Text-text-danger` / `Icon-icon-danger` light value).
- Label (`365:14717`): "Coverage Issues", Open Sans SemiBold 13px,
  `text-Text-text-high`.
- Count badge (`365:14718`/`365:14719`): **pill** shape, background
  `#FEEBED` (`Fill-fill-danger`), text `#A42327` (`Table-text-danger`),
  bold 11px.

## 2b. Coverage Issues button — active/applied state (node `365:19195`, from `365:19034`)

When the filter is currently applied, the button's own visual treatment
changes — this was not visible in the first-pass frame and is a real state
to implement, not just a filtered result list:

- Container background switches to `Fill-fill-danger`
  (`bg-[var(--fill/fill-danger,#33181a)]` in the export — the literal hex
  is the token's dark-mode value; the token itself is theme-aware, use
  `bg-Fill-fill-danger` and let the token resolve per theme).
- Border switches to `Border-border-default`.
- Count badge shape changes from **pill to full circle**, background
  becomes `Icon-icon-danger` (`#CE2C31`), and text becomes
  `Text-text-white` (white) instead of the pill's `Table-text-danger`.
- Label text color is unchanged (`Text-text-high`).

Implementation implication: the button needs two rendered variants keyed
off whether `filter[:coverage_issues]` (or equivalent) is currently set —
not just a `filtered_count` differing, but a distinct "pressed" style
including a shape change on the badge.

## 3. Settings button (node `365:14720`, popover trigger)

- 30×30 icon-only button, same chrome as the Coverage Issues button,
  immediately to its right.
- Icon (`365:14721`): gear/cog glyph, stroke `#757682`.
- **Exact match found in the codebase**: `Oli.OliWeb.Icons.settings/1`
  (`lib/oli_web/icons.ex:2467`) uses the identical path data and identical
  stroke color (`stroke-[#757682] dark:stroke-[#BAB8BF]`). Reuse this
  component directly — do not introduce a new icon.
- In `365:18532` this button is shown as the anchor for the open settings
  popover (§4), positioned with the popover directly below/centered on it
  and a small triangular "tail" pointing back at the button (nodes
  `365:18837`/`365:18838` in that frame, `365:19788`/`365:19789` in the
  standalone popover node).

## 4. Settings popover (nodes `365:19751` light / `365:19793` dark, anchored per `365:18532`)

298×261 popover, white/dark surface, 10px radius, drop-shadow
`0px 8px 14px rgba(0,50,99,0.14)`, 1px `Border-border-default` border, with
a small pointer triangle at the top pointing at the gear button.

Three stacked sections:

**a. Threshold rows** (padding 16/12, gap 12px between rows):

- Row 1 — "Minimum formative": circular 26px icon badge, fill
  `Fill-Accent-fill-accent-blue` (`#DEECFF` light / `#363B59` dark), a
  clipboard-style icon inside, label "Minimum formative" (Open Sans
  SemiBold 13px, `Text-text-high`), then a stepper control.
- Row 2 — "Minimum summative": circular 26px icon badge, fill
  `Fill-Accent-fill-accent-orange` (`#FFECDE` light / `#4C3F39` dark), a
  flag-style icon inside, label "Minimum summative", same stepper control.
- Stepper control: 90×30, 1px border `Border-border-active`
  (`#353740` light / `#EEEBF5` dark), three cells: `−` button (28×28) |
  value text (32px wide, bold 13px, e.g. `3`) | `+` button (28×28), each
  cell divided by the same border color. **No explicit numeric input
  field** — value only changes via the −/+ buttons.
- **No Save/Apply/Cancel button was found anywhere in this popover.**
  Only "Restore default" and "Learn more" exist in the footer (below).
  Implementation must treat each −/+ click as either (a) live-persisting
  immediately, or (b) staged with an implicit save-on-close — this is not
  specified by Figma and needs a product/engineering decision in Phase 4;
  do not silently assume one.

**b. Explanatory paragraph** (separate section, top border
`Border-border-default`, background `Surface-surface-secondary`):

> "These thresholds determine which objectives are flagged as coverage
> issues. An objective is flagged when it has fewer formative or
> summative activities than the minimums set above."

Open Sans Regular 11px, `Text-text-high`.

**c. Footer** (top border `Border-border-default`, `justify-between`):

- Left: **"Restore default"** — secondary bordered button
  (`Border-border-bold`, text `Specially-Tokens-Text-text-button-secondary`
  `#006CD9`), resets both thresholds to the product default (3/3).
- Right: **"Learn more"** — bold text-only link, `Text-text-button`
  `#006CD9` light / `#4CA6FF` dark.

## 5. "Learn more" — corrected finding and resolution (2026-09-02)

**Correction to the first-pass brief**: that draft stated no "Learn more"
link existed anywhere in the inspected frame. That was true only for the
single frame checked at the time (`365:14554`'s warning banner). The
settings popover (§4c, node `365:19787` light / `365:19829` dark) **does**
contain a "Learn more" link, in the popover footer next to "Restore
default".

**Resolution**: no Learn more URL ships with this ticket. MER-5919 owns the
knowledge-base article, destination, and visible activation. MER-5799 keeps
the already-styled Learn more node in the `justify-between` footer but marks
it `hidden` and leaves it non-interactive. This preserves the final Figma
styling and a stable extension point without exposing an incomplete link.

## 6. Warning banner (sub-objective detail, node `365:14951`, light root)

Appears inside `SubObjectiveDetail`, below the activity tabs, when a
sub-objective has an issue:

```
⚠ This sub-objective contains limited practice opportunities. Additional
  formative activities may improve both learning and insight quality.
```

- Exact copy (captured via design-context export, not the truncated Figma
  layer name): _"This sub-objective contains limited practice
  opportunities. Additional formative activities may improve both learning
  and insight quality."_
- Only a **formative** variant is present in this frame (only one banner
  instance was found under node `365:14554`, and none under the other four
  inspected frames either). No summative-specific banner copy exists in
  any inspected frame — Phase 4 should confirm with product whether a
  distinct summative message is needed or whether this same banner pattern
  (icon + message) is reused with different copy, rather than inventing
  wording.
- Container: `bg-Fill-fill-danger`, `border-Border-border-danger`,
  6px radius, 13/9 padding, 8px gap.
- Icon: rounded alert-triangle glyph, stroke `#CE2C31`. **Matches
  `Oli.OliWeb.Icons.warning_triangle/1`** (`lib/oli_web/icons.ex:2102`) —
  same triangle+exclamation construction (viewBox differs, 19x17 vs
  Figma's 14x12, but it is the same icon; the component's default class
  (`stroke-Icon-icon-accent-orange`) must be overridden to
  `stroke-Text-text-danger`/`stroke-Icon-icon-danger` to match this red
  variant — the default orange is a different semantic (warning vs.
  danger) already used elsewhere in the codebase).
- Text: `text-Text-text-high`, Open Sans Regular 13px.
- Confirmed again on this pass: the banner has exactly two children (icon
  - paragraph) — no "Learn more" link lives here; that link is exclusively
    in the settings popover (§4c/§5).

## 7. Inline issue badge on objective/sub-objective row headers (corrected)

Present at every hierarchy level: top-level `ObjectiveCard` (confirmed via
node `329:813` in the collapsed list `329:532`, and node `365:19289`/
`365:18787` in the toolbar-state frames) and `SubObjectiveRow` (node
`365:16776`, expanded frame `365:16457`). Same treatment at every level —
this is not a sub-objective-only indicator.

Next to the formative activity count in a row header, when that count is
below threshold, a small badge groups the alert icon with the clipboard
icon and the count (e.g. `⚠ [clipboard] 5 Formative`). This is the
"direct" issue indicator described in `phase-2-execution.md`/`issues.ex`
(`direct_formative_issue`/`direct_summative_issue`), rendered inline rather
than as a separate banner.

**Correction to the first-pass brief**: verified against
`get_design_context` code (not just the metadata layer names), this badge
is a **fully-rounded bordered pill**, not a filled `Fill-fill-danger`
pill:

- Flagged bucket (e.g. formative when below threshold): background
  `Background-bg-secondary`, border `Border-border-danger` (`#FF4040`),
  alert-triangle + clipboard icons, text `Text-text-high`.
- Healthy bucket (e.g. summative when at/above threshold): same pill
  shape, background `Background-bg-secondary`, but border
  `Border-border-default` (`#3B3740`), no alert icon, just the flag icon +
  count.

So formative and summative pills are styled **independently** — each
reflects only its own threshold state, confirming the classifier's
per-bucket `direct_formative_issue`/`direct_summative_issue` flags map
directly to per-pill styling, not a single combined "any issue" style at
the pill level (that combined treatment exists one level up — see §7b).

## 7b. Card/row-level red outline (node `329:813`'s parent `329:787`, and `365:16766`)

New finding from `329:532` (collapsed) and `365:16457` (expanded): when an
objective or sub-objective carries **any** issue (`issue.any_issue` in
`issues.ex`), the **entire card/row container** gets a 1px
`Border-border-danger` (`#FF4040`) outline, replacing its default neutral
border — confirmed identical at both levels:

- `ObjectiveCard` (node `329:787`): default is presumably a neutral/no
  border (not captured in this pass since only the flagged LO 2 was
  inspected in detail); flagged state is
  `border border-[#ff4040] ... rounded-[8px]` around the whole card,
  visible **while still collapsed** — the user does not need to expand a
  card to see that it has a coverage issue.
- `SubObjectiveRow` (node `365:16766`): same pattern,
  `border border-[#ff4040] ... rounded-[6px]` around the whole row, only
  present on the specific sub-objective that fails coverage — its sibling
  row (`365:16739`, "Given concentrations..." vs. the healthy sibling) does
  not get this border.

This is a second, independent visual signal on top of the per-bucket pill
border in §7 — implementation needs both: the outer card/row border keyed
off `issue.any_issue` (or the rolled-up parent flag for objectives with
flagged descendants), and the inner pill border keyed off each bucket's
own flag.
Use `Icons.warning_triangle/1` (color-overridden, per §6/§9) for the
alert-triangle glyph in both the pill and the banner — same icon family
confirmed across every inspected frame.

## 8. Design token mapping (verified against `assets/tailwind.tokens.js`)

| Figma value                                       | Token name                                                         | Verified codebase usage                                                                                                |
| ------------------------------------------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| `#CE2C31` (icon/text stroke)                      | `Text-text-danger` / `Icon-icon-danger`                            | `text-Text-text-danger` used in `objectives_table_model.ex`, `challenging_objectives_tile.ex`, etc.                    |
| `#FEEBED` (pill badge fill)                       | `Fill-fill-danger`                                                 | `bg-Fill-fill-danger` used in `sub_objectives_table_model.ex`, `objectives_table_model.ex`, `gradebook_table_model.ex` |
| `#A42327` (pill badge text)                       | `Table-text-danger`                                                | `text-Table-text-danger` used in `sections/table_model.ex`                                                             |
| `#FF4040` (banner border)                         | `Border-border-danger`                                             | `border-Border-border-danger` used in `design_tokens/primitives/button.ex`, `common.ex`                                |
| `#757682` (settings icon)                         | matches `Icons.settings/1`'s existing hardcoded stroke exactly     | n/a — icon already ships this color                                                                                    |
| `#DEECFF` / `#363B59` (formative icon badge fill) | `Fill-Accent-fill-accent-blue`                                     | confirmed present in `tailwind.tokens.js:129`                                                                          |
| `#FFECDE` / `#4C3F39` (summative icon badge fill) | `Fill-Accent-fill-accent-orange`                                   | confirmed present in `tailwind.tokens.js:141`                                                                          |
| `#353740` / `#EEEBF5` (stepper border)            | `Border-border-active`                                             | confirmed present in `tailwind.tokens.js:219`                                                                          |
| `#FFFFFF` / `#1B191F` (popover surface)           | `Surface-surface-primary`                                          | confirmed present in `tailwind.tokens.js:18`                                                                           |
| `#FFFFFF` / `#2B282E` (paragraph section surface) | `Surface-surface-secondary`                                        | confirmed present in `tailwind.tokens.js:26`                                                                           |
| `#8AB8E5` (Restore default border)                | `Border-border-bold`                                               | confirmed present in `tailwind.tokens.js:223`                                                                          |
| `#006CD9` (Restore default / Learn more text)     | `Text-text-button` / `Specially-Tokens-Text-text-button-secondary` | confirmed present in `tailwind.tokens.js:268`, `:494`                                                                  |
| `#FFFFFF` / `black` (row/card & pill background)  | `Background-bg-secondary`                                          | confirmed present in `tailwind.tokens.js:9`                                                                            |

No new design tokens are needed anywhere in this feature. Every color
inspected across all seven frames maps 1:1 to an existing token already
used elsewhere in this codebase.

## 9. Icon reuse (verified against `lib/oli_web/icons.ex`)

- Coverage Issues button / inline row badge / warning banner triangle →
  `Icons.warning_triangle/1` (needs a `class` override to the danger/red
  token instead of its default orange accent).
- Settings gear → `Icons.settings/1` (already the correct color, no
  override needed).
- Settings popover row icons (clipboard-style for formative, flag-style
  for summative) were not resolved to a specific existing icon function in
  this pass — they visually resemble the existing `IconClipboardList`/
  `IconFlag` glyphs already used elsewhere on the same page (row-level
  page/formative/summative counts), so Phase 4 should check
  `lib/oli_web/icons.ex` for a clipboard and a flag icon before assuming
  new ones are needed.

No new icon needs to be created for the elements this brief covers in
detail (toolbar button, badge, warning banner, settings trigger).

## 10. What Phase 1 still does not resolve

- No explicit save/cancel interaction is specified for the threshold
  steppers (§4a) — needs a product/engineering decision in Phase 4.
- No explicit zero-issues badge state is shown in either the toolbar pill,
  toolbar circular badge, or row-level pill variants.
- No explicit summative-flagged example (red-bordered summative pill, or a
  summative-only warning banner) was found in any inspected frame — every
  flagged example available is formative. Phase 4 should treat the
  summative treatment as symmetric to formative by design intent
  (`fdd.md` treats both buckets equivalently) rather than waiting for a
  Figma example that may not exist.
- No default/healthy `ObjectiveCard` example was captured in this pass
  (only the flagged `329:787` was inspected in detail) — Phase 4 should
  confirm the neutral card border token (likely `Border-border-default`,
  by symmetry with the row-level pill and the toolbar button's inactive
  state) rather than assume.
- The two settings-popover row icons (§9) were not conclusively matched to
  an existing icon function.
- Keyboard/focus order and full responsive behavior were not evaluated —
  `fdd.md` already scopes this as "Manual Figma comparison for light/dark,
  keyboard focus, responsive layout" (out of this automated brief's
  scope).
- Dark-theme node trees were walked via direct `get_design_context` calls
  for the settings popover only (§4, confirmed token-for-token parity);
  the dark warning/toolbar frame (`365:17228`) was only screenshotted, not
  walked node-by-node — acceptable because every token involved is
  theme-aware by construction (each token has a `light`/`dark` pair in
  `tailwind.tokens.js`).

## 11. Next steps

1. This brief is ready for Phase 3/4 implementation — MER-5797's PR (#6820)
   merged 2026-09-07 and this branch is rebased onto it, satisfying
   `plan.md`'s Phase 1 gate.
2. Phase 4 should reuse `Icons.warning_triangle/1` and `Icons.settings/1`,
   the token names in §8, and the exact copy in §4b/§6, rather than
   re-deriving them.
3. Phase 4 resolved both interaction questions: stepper changes persist
   immediately, and Learn more remains styled but hidden until MER-5919.
4. Phase 4 should locate the existing clipboard/flag icon functions (§9)
   before assuming new icons are needed for the settings popover rows.

## Decision Log

### 2026-09-08 - Keep Learn more styled and hidden

- Change: The brief now records the selected hidden-placeholder approach and names MER-5919 as the activation ticket.
- Reason: The URL is intentionally outside MER-5799, while the final footer styling is already available from Figma.
- Evidence: `lib/oli_web/live/workspaces/course_author/objectives/coverage_settings_popover.ex` and the user's final Figma review.
- Impact: Phase 4 has no unresolved Learn more implementation choice.

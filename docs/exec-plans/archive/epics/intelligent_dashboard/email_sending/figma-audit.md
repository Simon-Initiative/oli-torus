# Figma Audit — DraftEmailModal

Systematic element-by-element comparison between Figma node `955:17500` and current code.

- **Figma**: https://www.figma.com/design/2DZreln3n2lJMNiL6av5PP/Instructor-Intelligent-Dashboard?node-id=955-17500
- **Branch**: `MER-5642-context-aware-email-draft-modal-ui-implementation`
- **Last audited**: 2026-05-27
- **Re-audited**: 2026-05-27 (post-fix verification using updated figma-to-code skill)
- **Source files**:
  - `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/draft_email_modal.ex`
  - `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/recipient_chip_list.ex`
  - `lib/oli_web/components/design_tokens/primitives/button.ex`
  - `lib/oli_web/components/modal.ex`
  - `assets/tailwind.tokens.js`

## Status legend

- `[ ]` not started
- `[~]` in progress
- `[x]` fixed and re-audit verified
- `[—]` won't fix (with reason)

---

## Group 1: To: Field (RecipientChipList)

### 1.1 — Container horizontal padding
- **Figma**: `px: spacing-200 (16px)` — node 955:17510
- **Before**: `px-3` (12px) — `recipient_chip_list.ex:23`
- **After**: `px-4` (16px)
- [x] Fixed — verified: `px-4` = 16px matches Figma spacing-200

### 1.2 — Container background
- **Figma**: no fill (transparent) — node 955:17510
- **Before**: `bg-Surface-surface-primary` (#1B191F dark) — `recipient_chip_list.ex:23`
- **After**: removed (transparent)
- [x] Fixed — verified: no bg class, inherits parent `bg-primary`

### 1.3 — Chip background token
- **Figma**: `fill-detail-pill` (#FFFFFF1A = rgba(255,255,255,0.1)) — node 955:17513
- **Before**: `bg-Fill-Chip-Gray` (#353740 dark) — `recipient_chip_list.ex:33`
- **After**: `bg-Specially-Tokens-Fill-fill-detail-pill` (#FFFFFF1A dark)
- [x] Fixed — verified: token dark value #FFFFFF1A matches Figma resolved #ffffff1a

### 1.4 — Overflow pill text
- **Figma**: "..." — node 955:17517
- **Before**: "Show more" — `recipient_chip_list.ex:61`
- **After**: "..."
- [x] Fixed — verified: text matches. `aria-label="Show all recipients"` retained for accessibility.

---

## Group 2: Subject Input

### 2.1 — Subject input background
- **Figma**: no fill (transparent) — node 955:17520
- **Before**: `bg-Surface-surface-primary` — `draft_email_modal.ex:117`
- **After**: `bg-transparent`
- [x] Fixed — verified: transparent bg, border still visible against dark parent

---

## Group 3: Controls Card

### 3.1 — Card border radius
- **Figma**: `radius-150` (12px) — node 955:17522
- **Before**: `rounded-[8px]`
- **After**: `rounded-[12px]`
- [x] Fixed — verified

### 3.2 — Card padding
- **Figma**: `spacing-075` (6px) all sides — node 955:17522
- **Before**: `px-4 py-3` (16px/12px)
- **After**: `p-[6px]`
- [x] Fixed — verified: uniform 6px all sides

### 3.3 — Card shadow
- **Figma**: `shadow-card` → `0px 2px 10px rgba(0,50,99,0.05)` — node 955:17522
- **Before**: none
- **After**: `shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]`
- [x] Fixed — verified: matches Figma shadow-card resolved value

### 3.4 — Card width
- **Figma**: 517px — node 955:17522
- **Before**: full width
- **After**: `w-[517px]`
- [x] Fixed — verified

### 3.5 — Card layout direction
- **Figma**: outer card flex-col (955:17522), inner row flex (955:17523)
- **Before**: single flex row
- **After**: outer div (card styling) wraps inner div (`flex items-center gap-[6px]`)
- [x] Fixed — verified: matches Figma nesting structure

### 3.6 — Controls row gap
- **Figma**: `spacing-075` (6px) — node 955:17523
- **Before**: `gap-3` (12px)
- **After**: `gap-[6px]`
- [x] Fixed — verified

### 3.7 — Remove "Tone:" label
- **Figma**: not present
- **Before**: `<span>Tone:</span>` present
- **After**: removed
- [x] Fixed — verified: no "Tone:" text in output. Test updated (removed assertion).

### 3.8 — Remove divider line
- **Figma**: not present
- **Before**: `<div class="h-6 w-px bg-Border-border-subtle" />` present
- **After**: removed
- [x] Fixed — verified

---

## Group 4: Generate Button

### 4.1 — Generate button horizontal padding
- **Figma**: `spacing-200` (16px) — node 955:17524 "Button/Small-w-Icon"
- **Before**: `px-6` (24px) inherited from Button :primary :sm `size_classes`
- **After**: `class="!px-4"` override on Button (Tailwind `!important` overrides component `px-6`)
- [x] Fixed — verified: Button.button accepts `class` attr (line 310), appends at line 355. `!px-4` generates `padding: 1rem !important` which overrides `px-6`.

---

## Group 5: Tone Buttons

### 5.1 — Tone selected: background
- **Figma**: `fill-secondary-hover` (rgba(255,255,255,0.1)) — node 955:17530
- **Before**: `bg-Fill-Buttons-fill-primary-bold` (solid blue)
- **After**: `bg-Fill-Buttons-fill-secondary-hover`
- [x] Fixed — verified: token dark #FFFFFF1A matches Figma #ffffff1a

### 5.2 — Tone selected: border
- **Figma**: `border-bold-hover` (white #FFFFFF), solid — node 955:17530
- **Before**: none
- **After**: `border border-Border-border-bold-hover`
- [x] Fixed — verified: token dark #FFFFFF matches Figma #ffffff

### 5.3 — Tone selected: shadow
- **Figma**: `shadow-button-hover` → `0px 2px 6px rgba(0,52,99,0.15)` — node 955:17530
- **Before**: none
- **After**: `shadow-[0px_2px_6px_0px_rgba(0,52,99,0.15)]`
- [x] Fixed — verified

### 5.4 — Tone unselected: border
- **Figma**: `border-bold` (rgba(255,255,255,0.5)), solid — node 955:17531
- **Before**: none
- **After**: `border border-Border-border-bold`
- [x] Fixed — verified: token dark #FFFFFF80 matches Figma #ffffff80

### 5.5 — Tone unselected: shadow
- **Figma**: `shadow-button` → `0px 2px 4px rgba(0,52,99,0.1)` — node 955:17531
- **Before**: none
- **After**: `shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]`
- [x] Fixed — verified

### 5.6 — Tone unselected: text color
- **Figma**: `text-button-secondary` (white) — node 955:17531
- **Before**: `text-Text-text-high` (#eeebf5)
- **After**: `text-Specially-Tokens-Text-text-button-secondary` (shared base class for both states)
- [x] Fixed — verified: token dark #FFFFFF matches Figma #ffffff

### 5.7 — Tone buttons: horizontal padding
- **Figma**: `spacing-300` (24px) — nodes 955:17530-32
- **Before**: `px-3` (12px)
- **After**: `px-6` (24px)
- [x] Fixed — verified

### 5.8 — Tone buttons: vertical padding
- **Figma**: `spacing-100` (8px) — nodes 955:17530-32
- **Before**: `py-1.5` (6px)
- **After**: `py-2` (8px)
- [x] Fixed — verified

### 5.9 — Tone buttons: gap between buttons
- **Figma**: `spacing-050` (4px) — node 955:17529
- **Before**: `gap-2` (8px)
- **After**: `gap-1` (4px)
- [x] Fixed — verified

---

## Group 6: Body Field

### 6.1 — Body container background
- **Figma**: no fill (transparent) — node 955:17535
- **Before**: `bg-Surface-surface-primary` — both generating state and editor container
- **After**: `bg-transparent` — both instances
- [x] Fixed — verified: both `:if={@generating}` div and `:if={not @generating}` div updated

---

## Group 7: Footer

### 7.1 — Footnote font size
- **Figma**: Regular 14px/16px (Label/S.400) — node 955:17549
- **Before**: `text-xs` (12px)
- **After**: `text-sm` (14px)
- [x] Fixed — verified

### 7.2 — Footnote text content
- **Figma**: "Fields contained in square brackets like {first_name}..."
- **Before**: "Fields contained in curly braces like {first_name}..."
- **After**: "Fields contained in square brackets like {first_name}..."
- [x] Fixed — verified

---

## Group 8: Header Spacing

### 8.1 — Header padding top
- **Figma**: 31px (content at top:31px) — node 955:17505
- **Before**: `pt-[30px]`
- **After**: `pt-[31px]`
- [x] Fixed — verified

### 8.2 — Header padding bottom
- **Figma**: ~27px (line at 58.54px, content starts at 31px → 27.54px to line separator)
- **Before**: `pb-5` (20px)
- **After**: `pb-[27px]`
- [x] Fixed — verified

---

## Accepted minor differences

| Element | Figma | Code | Reason |
|---------|-------|------|--------|
| Subject height | 39px | `h-[40px]` | 1px — form element rounding |
| Backdrop blur | 3px | `backdrop-blur-sm` (4px) | Modal component default, not worth overriding |
| Modal ring/shadow | none | `ring-1 ring-zinc-700/10 shadow-lg` | Modal component default, subtle, not worth overriding |
| Cancel button | inside body overflow (not visible) | footer (visible) | Intentional deviation per G-D12 |

## Summary

| Group | Items | Fixed | Remaining |
|-------|-------|-------|-----------|
| 1 — To: Field | 4 | 4 | 0 |
| 2 — Subject | 1 | 1 | 0 |
| 3 — Controls Card | 8 | 8 | 0 |
| 4 — Generate Button | 1 | 1 | 0 |
| 5 — Tone Buttons | 9 | 9 | 0 |
| 6 — Body Field | 1 | 1 | 0 |
| 7 — Footer | 2 | 2 | 0 |
| 8 — Header | 2 | 2 | 0 |
| **Total** | **28** | **28** | **0** |

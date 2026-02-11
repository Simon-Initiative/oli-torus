# UI Review Checklist (Language-Agnostic)

> Use this during PR review to catch usability, accessibility, and UI performance issues early. Prefer **specific, actionable** comments with file:line references and suggested fixes.

---

## 1) Core UX Principles
- [ ] **Clarity**: Plain language, obvious labels, meaningful icons with text.
- [ ] **Consistency**: Reuse patterns, spacing, and terms. One way to do a thing.
- [ ] **Feedback**: Affordances + instant responses (hover/focus/pressed/disabled).
- [ ] **Forgiveness**: Undo for destructive actions; confirm only when necessary.
- [ ] **Progressive disclosure**: Show essentials first; reveal advanced options on demand.
- [ ] **Empty/Loading/Error/No-permission states**: Thoughtful copy + helpful actions.

---

## 2) Accessibility (WCAG-aligned)
- [ ] **Semantics**: Real headings (`h1→h6`), lists, buttons, links; avoid `div` soup.
- [ ] **Keyboard**: Fully usable without a mouse (Tab/Shift+Tab, Enter/Space, Esc). No traps.
- [ ] **Focus**: Visible focus ring (≥3:1 contrast); logical order; return focus after modals/menus.
- [ ] **Color contrast**: Text ≥4.5:1 (normal), ≥3:1 (large); UI icons/graphics ≥3:1 when essential.
- [ ] **Do not rely on color alone**: Add icons, text, or patterns for state differences.
- [ ] **Names/labels**: Inputs have `<label>` or programmatic names; controls have accessible names.
- [ ] **ARIA**: Use sparingly, only to **fix** semantics; keep roles/states in sync.
- [ ] **Motion**: Respect `prefers-reduced-motion`; avoid parallax/auto-animations by default.
- [ ] **Timing**: No essential time limits; if present, provide extend/pause/disable.
- [ ] **Assistive tech**: Landmarks (`header/main/nav/footer`), skip-to-content link, descriptive page titles.
- [ ] **Media**: Images have meaningful `alt`; decorative images are empty `alt`. Video captions + transcripts.
- [ ] **Forms**: required/optional clear; errors are textual + field-associated (aria-describedby, aria-invalid); placeholder ≠ label; use autocomplete.
- [ ] **Overlays**: dialogs trap focus + restore focus; Esc supported; live regions for async status/toasts.
- [ ] **Pointer + touch**: hit targets ≥24px (prefer 44px); hover content also on focus/touch; avoid down-event activation for destructive actions.
- [ ] **Structure**: one H1; headings in order; DOM order matches visual; lang set.
- [ ] **Reflow/zoom**: usable at 200% zoom / 320px width; no lost content; text spacing doesn’t break layout.
- [ ] **Data UI**: real tables with headers/scope; sorting announced (aria-sort); charts have text summary/table.

---

## 3) Responsiveness & Layout
- [ ] **Mobile-first CSS**: Scale up with breakpoints; avoid fixed heights causing overflow.
- [ ] **Fluid layout**: Percent/flex/grid, not pixel-locked widths; content reflows naturally.
- [ ] **Readable line length**: ~45–90 characters for body text; adequate line height.
- [ ] **Touch targets**: Min target area ~44×44px; comfortable spacing between interactive items.
- [ ] **Safe areas**: Respect notches/home indicators; test portrait/landscape.
- [ ] **Responsive media**: Use responsive images (srcset/sizes) and intrinsic aspect ratios.
- [ ] **Orientation**: Works both orientations or communicates constraints clearly.

---

## 4) Forms & Validation
- [ ] **Labels**: Every control has a persistent label; placeholder isn’t a label.
- [ ] **Help & examples**: Clear hints and input masks (but allow paste/voice).
- [ ] **Validation**: Inline, specific messages; validate on blur/change + on submit.
- [ ] **Error presentation**: Associate errors to fields (ARIA `aria-describedby`/`aria-invalid`), summary at top.
- [ ] **Keyboard flow**: Logical tab order; Enter submits; Esc closes non-modal popovers only.
- [ ] **Autofill & type**: Correct `type` (email, url, number), `autocomplete` tokens, locale-aware parsing.
- [ ] **State**: Preserve user input on error; loading/disabled states prevent double submits.
- [ ] **Long forms**: Group sections; show progress; allow save-and-resume.

---

## 5) Navigation & Information Architecture
- [ ] **Global nav** is consistent and keyboard accessible; active states are clear.
- [ ] **Breadcrumbs** for deep hierarchies; back behavior is predictable.
- [ ] **Search** where content discovery matters; empty/results states are helpful.
- [ ] **In-page TOC** for long content; distinct section headings.

---

## 6) Data Display (Tables, Lists, Cards)
- [ ] **Tables**: Use `<th>` with `scope`, `<caption>` (visually hidden if needed); sortable headers announce state.
- [ ] **Large datasets**: Pagination or virtualization; sticky header; row hover/focus styles.
- [ ] **Density controls**: Comfortable/compact toggles; user preference persists.
- [ ] **No data**: Show empty state + primary action; avoid blank screens.

---

## 7) Performance & Perceived Speed
- [ ] **Budgets**: Define size/LCP/INP targets; guard against regressions.
- [ ] **Code splitting**: Load critical above-the-fold first; defer non-critical.
- [ ] **Images**: Modern formats (AVIF/WebP fallback), compression, `loading="lazy"` where safe.
- [ ] **Fonts**: Limit families/weights; use `font-display: swap`; preconnect to font hosts.
- [ ] **Avoid layout shifts**: Reserve dimensions; skeletons > spinners for long loads.
- [ ] **Prefetch**: Predictive prefetch on intent (hover/viewport) for internal links.
- [ ] **Caching**: ETags/immutable assets; respect HTTP cache hints.

---

## 8) Internationalization & Localization (i18n/l10n)
- [ ] **No hard-coded copy**: All text strings externalized; supports plural/gender rules.
- [ ] **Layout**: Anticipate text expansion (≈30%); avoid clipped buttons/labels.
- [ ] **RTL**: Directionality support (`dir`), mirrored icons where appropriate.
- [ ] **Formats**: Localize dates/times/numbers/currencies/units; show user time zone.
- [ ] **Input**: Accept localized input; normalize and validate server-side.

---

## 9) Visual Design & Theming
- [ ] **Design tokens** for color/spacing/typography; single source of truth.
- [ ] **Light/Dark/High-contrast** themes; maintain contrast thresholds in all.
- [ ] **State colors** (info/success/warn/danger) have sufficient contrast and non-color cues.
- [ ] **Iconography**: Consistent set; icons have text where meaning isn’t universal.

---

## 10) Motion & Micro-interactions
- [ ] **Purposeful**: Motion communicates state changes, not decoration.
- [ ] **Duration**: Generally 150–250ms; avoid long blocking animations.
- [ ] **Reduced motion**: Honor `prefers-reduced-motion`; provide non-animated affordances.

---

## 11) Security & Privacy in the UI
- [ ] **Sensitive data**: Mask secrets by default with reveal toggle; avoid copying to logs.
- [ ] **Clipboard**: Ask before copying sensitive content; clear on page unload if applicable.
- [ ] **External links**: Indicate leaving site; `rel="noopener"` to prevent tab-nabbing.
- [ ] **Permissions**: Be explicit (camera, mic, location) and degrade gracefully.

---

## 12) Offline, Errors & Resilience
- [ ] **Graceful offline**: Communicate status; queue user actions for retry when safe.
- [ ] **Error taxonomy**: Distinguish validation, auth, permission, server, network; actionable guidance.
- [ ] **Retries**: Backoff + user control; don’t loop forever silently.

---

## 13) Observability & Ethics
- [ ] **Events**: Name consistently; include context (screen, component, action, target).
- [ ] **Privacy**: No PII in analytics; honor Do Not Track/regional consent.
- [ ] **A/B**: Guard against flicker and layout shift; document exposure & success metrics.

---

## 14) Components & Patterns (Reusable)
- [ ] **Buttons/Links**: Buttons for actions; links for navigation; disabled vs. loading states distinct.
- [ ] **Modals/Drawers**: Trap focus; Esc closes; restore focus to trigger; prevent background scroll.
- [ ] **Menus/Comboboxes**: Arrow keys, type-ahead, Home/End; announce selection/expanded state.
- [ ] **Toasts**: Don’t block; queue; auto-dismiss with pause on hover and screen-reader announcements.

---

## 15) Testing & Review Aids
- [ ] **Accessibility**: Automated checks (axe), manual keyboard pass, screen reader smoke test.
- [ ] **Visual**: Snapshot/visual diff on critical screens and states.
- [ ] **Cross-browser/device**: Latest Chrome/Firefox/Safari + iOS/Android; low-end device sanity.
- [ ] **Perf**: Lab + field (e.g., Web Vitals) before/after for major changes.
- [ ] **Docs**: Update component README/stories and design tokens when behavior/props change.

---

## Reviewer Red Flags (paste as actionable comments)
- “Control is not reachable by keyboard; add proper role and key handlers, ensure focus order.”
- “Insufficient color contrast (3.2:1); adjust token to meet ≥4.5:1 for body text.”
- “Modal doesn’t return focus to trigger; store trigger and restore on close.”
- “Table headers are `div`s; replace with semantic `<table>/<th scope>` for screen readers.”
- “Touchable target is ~28×28px; increase to ~44×44px and add spacing.”
- “Spinner only; add skeleton or inline placeholders to reduce perceived wait.”
- “Hard-coded English string; externalize and add pluralization keys.”
- “Layout shift on image load; set width/height/aspect-ratio to reserve space.”

---

## Quick Snippets (illustrative HTML)
**Skip link + landmarks**
```html
<a class="skip-link" href="#main">Skip to content</a>
<header>…</header>
<nav aria-label="Primary">…</nav>
<main id="main">…</main>
<footer>…</footer>

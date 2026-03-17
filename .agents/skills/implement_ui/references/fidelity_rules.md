# Fidelity Rules

Use this reference when the brief must describe how closely implementation should match Figma and where controlled deviation is acceptable.

## Figma As Contract

For first-pass fidelity, treat the requested Figma node as the contract for the default UI state.

Before calling a detail "matched", confirm:

- `fileKey`
- `nodeId`
- relevant variant or state
- effective layout, spacing, typography, fills, strokes, effects, opacity, and assets

Do not assume parent-level uniformity if child-level overrides may exist.

## Static vs Dynamic Content

State explicitly whether each important region is static or dynamic.

For static content:

- match Figma dimensions, spacing, and visual hierarchy as closely as practical

For dynamic content, such as counters, localized strings, percentages, user-provided labels, or variable-length text:

- preserve the Figma layout as the default state
- define bounded fallback behavior only for the regions that can overflow
- document what triggers the fallback
- keep the fallback scoped so the rest of the layout remains faithful to the design

## Structural Restraint

Do not reproduce Figma frame nesting literally unless it is required for:

- semantics
- accessibility
- layout behavior
- interaction/state handling

Avoid recommending unnecessary wrappers or ad hoc CSS when token-aligned utilities and existing patterns are sufficient.

## Tailwind Mapping

When describing implementation guidance:

- prefer existing tokenized utilities first
- prefer native Tailwind scale values when they preserve intent
- use arbitrary values only when no reasonable native utility preserves the design intent

## Output Expectations

When fidelity rules matter, the brief should capture:

- which parts of the design are strict first-pass fidelity targets
- which regions are dynamic and need overflow/fallback handling
- any implementation constraint that justifies a bounded deviation from the default Figma layout

# Responsive Validation

Use this reference when the design includes responsive behavior, dense layouts, dashboards, charts, multi-column compositions, or any breakpoint-specific ambiguity.

## Approval Boundary

The base brief should describe the default responsive expectations visible in the design.

If further responsive polish or runtime verification is needed after base fidelity, call that out explicitly as follow-on implementation work rather than silently expanding scope.

## Validation Mindset

Responsive assessment should be viewport-driven, not guess-driven.

Check practical widths around:

- `sm`
- `md`
- `lg`
- `xl`
- `2xl`
- one or two in-between widths when the layout is especially fragile

## What To Check

During responsive assessment, always look for:

- overlap between sibling regions
- clipped or truncated critical text
- horizontal overflow or hidden controls
- broken alignment when columns stack
- regressions in selected, empty, loading, or long-content states

When charts, canvases, or runtime-sized regions are involved:

- verify behavior after resize events, not only at initial load

## Fallback Guidance

For dynamic or dense regions:

- keep the default Figma layout when content fits
- recommend bounded fallback behavior only when content no longer fits
- prefer narrow breakpoint or narrow range adjustments over global redesign

Examples of acceptable bounded fallback:

- reducing chart size in a narrow breakpoint band
- collapsing a two-column legend into one column
- stacking supporting metadata beneath a title only when the title wraps

## Output Expectations

When responsive behavior is in scope, the brief should state:

- what the default layout expectation is
- which breakpoints or layout ranges appear risky
- what bounded fallback behavior should be considered if content stops fitting
- which responsive questions still need explicit approval

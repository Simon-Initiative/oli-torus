# Guardrails

## Tokens

Use the term `design tokens` broadly.

This includes:
- color tokens
- text tokens
- border tokens
- icon tokens
- fill/background tokens
- spacing/radius/shadow tokens when relevant

If the design uses a color or semantic role that does not map clearly to an existing token:
- call it out explicitly
- recommend a token addition only as a proposal
- do not silently hardcode it

When translating layout values from Figma into Tailwind:
- prefer native Tailwind utility classes first
- use arbitrary values only when native Tailwind does not offer a close, intention-preserving equivalent
- avoid copying raw Figma numbers mechanically when a standard Tailwind utility already matches

## Icons

Do not introduce one-off local icons when the system should own them.

If the design needs an icon that does not exist:
- identify the missing icon
- first verify it is not already present in the Torus design-system icon catalog (`node-id=2:24`)
- if it is not present there, attempt MCP asset extraction from the feature-level Figma node before drawing anything manually
- recommend extending the correct icon system
- do not inline an arbitrary SVG as the default path

## Reusable Components

Prefer existing components or patterns first.

If the design introduces a pattern with likely reuse, recommend incremental extraction.
Good candidates include:
- buttons with multiple states/variants
- pills/badges
- cards/panels
- tab triggers
- icon buttons

Do not recommend extraction for every local layout wrapper.

## Ambiguity

Escalate when the design does not answer:
- hover/focus/pressed/disabled states
- responsive behavior
- empty/loading/error states
- token mapping
- icon choice

The goal is governed implementation, not blind visual cloning.

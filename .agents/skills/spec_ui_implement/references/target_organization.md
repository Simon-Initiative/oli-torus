# Target Organization

This skill should not treat every reusable UI fragment as a design-system component.

It should aim toward a gradual consolidation model:
- design tokens remain the source of truth for visual semantics
- cross-feature primitives and shared feedback components can move into `design_tokens/`
- feature-specific compositions stay close to their feature modules

## Naming Direction

When proposing or creating shared UI homes, prefer `design_tokens` in the path name.

Recommended shared homes:

### HEEx / LiveView

- `lib/oli_web/components/design_tokens/`

Suggested sub-areas:
- `primitives/`
- `feedback/`
- `icons/` or thin wrappers around the canonical icon module
- optional `typography/` or helper modules only when repeated usage justifies them

### React / TypeScript

- `assets/src/components/design_tokens/`

Suggested sub-areas:
- `primitives/`
- `feedback/`
- `icons/`

## Source of Truth vs Consumption Layer

Do not confuse token definitions with token-governed components.

Token definitions should continue to live in the existing token/theme files:
- `assets/tailwind.tokens.js`
- `assets/tailwind.theme.js`

The `design_tokens/` component directories are the consumption layer:
- shared buttons
- icon buttons
- flash messages
- other cross-feature primitives

They are not the place to redefine raw color, spacing, or typography scales.

## What Belongs in `design_tokens/`

Good candidates:
- buttons
- icon buttons
- flash messages
- badges or pills
- simple surface or card primitives
- small typography wrappers when repeated and stable

These should be:
- cross-feature or clearly trending toward reuse
- governed by design tokens
- free of domain-specific business logic

## What Should Stay in Feature Directories

Keep these near the feature unless there is clear cross-feature reuse:
- page shells
- dashboard-specific chrome
- tile groups
- feature panels
- domain-specific composites

Reusable does not automatically mean global.
If a component knows too much about a single workflow or domain, keep it local.

## Extraction Heuristic

When evaluating a design implementation:

- reuse an existing shared component first if it already fits
- if the pattern is repeated or has obvious cross-feature value, recommend extraction into `design_tokens/`
- if the pattern is local to a feature, keep it local even if it is cleanly abstracted

Do not force early centralization.
Prefer gradual consolidation through real implementation work.

## Current Priority Areas

Based on the current design-system material, the first shared extraction targets should generally be:
- buttons
- icon buttons
- flash messages

Layout and spacing should usually remain token-driven conventions, not large shared component modules, unless the repo develops repeated wrappers that justify them.

## Figma Alignment

The current design-system references include:
- layout
- spacing
- colors
- typography
- icons
- buttons
- flash messages

This means the skill should treat the following as especially important:
- token mapping for color and spacing
- icon reuse or icon-system extension
- button standardization
- shared flash-message semantics

## Output Expectation

When the skill recommends a file target, it should explicitly say one of:
- `extract to design_tokens shared primitive`
- `extend existing design_tokens shared primitive`
- `keep feature-local`

That recommendation should be justified briefly in terms of reuse and domain coupling.

# Repo Waypoints

Use these as the first places to inspect when mapping design to implementation:

## Design Tokens

- `assets/tailwind.tokens.js`
- `assets/tailwind.theme.js`
- `assets/css/app.css`

Prefer tokenized Tailwind utility classes already wired into the repo.

## Icons

- `lib/oli_web/icons.ex`
- `assets/src/components/misc/icons/Icons`

Choose the icon module that matches the implementation surface:
- HEEx/LiveView -> `OliWeb.Icons`
- React/TS -> `components/misc/icons/Icons`

## Existing UI Patterns

Search for existing implementations before proposing new primitives:
- buttons
- tabs
- badges/pills
- cards/panels
- empty states
- modals/dropdowns

Look in both:
- `lib/oli_web/components/**`
- `assets/src/components/**`

## Target Shared Homes

When a new primitive should become shared, prefer these target locations:
- `lib/oli_web/components/design_tokens/**`
- `assets/src/components/design_tokens/**`

Use `design_tokens/` for cross-feature primitives and feedback components.
Keep feature-specific compositions in their existing domain directories unless reuse clearly justifies extraction.

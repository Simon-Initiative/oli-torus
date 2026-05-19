# Design Tokens Components

## Purpose

This document defines the incremental adoption model for shared UI primitives in Torus.

Torus should not attempt a one-time migration of every existing button, badge, pill, or surface into a unified component library. The current repository contains legacy and surface-specific UI patterns, so consolidation must happen gradually through real feature work.

The goal is to create a clear canonical home for shared primitives and make that path easy to follow for both humans and AI agents.

## Core Direction

- design tokens remain the source of truth for color, spacing, typography, and theme semantics
- shared UI primitives should live in `design_tokens/`
- domain or workflow-specific composites should stay near the feature unless they become clearly cross-feature
- migration should happen incrementally as teams touch real surfaces

## Terminology

- `Design System` refers to the broader Torus visual system and its Figma reference surfaces
- `design tokens` refers to the underlying visual values such as color, spacing, typography, and theme semantics
- `design_tokens/` refers to the code layer where shared token-governed UI primitives and feedback components should live

## Figma References

When working on shared primitives or design-system alignment, use the Torus design-system Figma references captured in:

- `.agents/skills/implement_ui/references/design_system_sources.md`

That file is the operational lookup guide for:

- which Figma nodes define buttons, icons, colors, spacing, typography, and flash messages
- which design-system source to inspect first
- when feature-level Figma should override the design-system Figma as the primary visual source

This document remains the source of truth for repository policy and placement conventions. The skill reference remains the source of truth for where to look in Figma.

## Canonical Locations

### HEEx / LiveView

- `lib/oli_web/components/design_tokens/primitives/`
- `lib/oli_web/components/design_tokens/feedback/`
- `lib/oli_web/components/design_tokens/icons/` if the icon layer is later consolidated

### React / TypeScript

- `assets/src/components/design_tokens/primitives/`
- `assets/src/components/design_tokens/feedback/`
- `assets/src/components/design_tokens/icons/`

## Recommended Directory Structure

The recommended code structure for shared UI primitives is:

### HEEx / LiveView

- `lib/oli_web/components/design_tokens/primitives/`
  - shared primitives such as buttons, icon buttons, badges, pills, and simple surfaces
- `lib/oli_web/components/design_tokens/feedback/`
  - flash messages, alerts, banners, and similar shared feedback components
- `lib/oli_web/components/design_tokens/icons/`
  - optional future consolidation point for shared icon access
  - current canonical icon module still lives at `lib/oli_web/icons.ex`

### React / TypeScript

- `assets/src/components/design_tokens/primitives/`
  - shared primitives for React surfaces
- `assets/src/components/design_tokens/feedback/`
  - shared feedback components for React surfaces
- `assets/src/components/design_tokens/icons/`
  - optional future consolidation point for shared icon access
  - current canonical icon module still lives at `assets/src/components/misc/icons/Icons`

## What This Structure Does Not Mean

The Figma design-system categories should not be translated mechanically into component directories.

For example:

- `Layout`
- `Spacing`
- `Colors`
- `Typography`

are design-system reference categories, but they are not necessarily component module categories.

Those underlying values should continue to live in token/theme source files such as:

- `assets/tailwind.tokens.js`
- `assets/tailwind.theme.js`

`design_tokens/` is the code-layer consumption model for shared token-governed components, not the storage layer for raw token definitions.

## What Belongs Here

Good shared primitive candidates include:

- buttons
- icon buttons
- badges
- pills
- small feedback surfaces
- simple cards or surfaces with stable cross-feature semantics

These components should be:

- governed by design tokens
- free of domain-specific business logic
- useful across multiple features or clearly trending in that direction

## What Should Stay Feature-Local

Keep these near their feature unless reuse becomes obvious:

- dashboard-specific tile compositions
- page shells
- workflow-specific controls
- domain-specific action composites

Reusable does not automatically mean global. If a component knows too much about a single workflow, it should remain local and compose shared primitives underneath when possible.

## Adoption Rule

For new UI work or refactors that introduce a cross-feature primitive pattern:

1. Search for an existing shared primitive first.
2. If one exists and is close, extend it.
3. If the pattern is clearly cross-feature and no suitable primitive exists, create one in `design_tokens/`.
4. If the pattern is still feature-specific, keep it local and avoid premature extraction.

The burden of proof should favor `design_tokens/` for primitives like buttons and icon buttons, and favor feature-local ownership for domain composites.

## First Priority Areas

The first shared extraction targets should generally be:

- buttons
- icon buttons
- flash or feedback surfaces

These are the most likely to benefit from incremental standardization without forcing large architectural changes.

## Composition Rule

Domain-specific components should prefer composing shared primitives instead of redefining primitive styling locally.

Example:

- `EmailButton` should remain a domain-specific component because it owns email-related behavior
- but it should render through a shared `Button` primitive for its visual treatment and baseline interaction states

That separation allows Torus to evolve the design system incrementally while preserving domain-specific behavior.

## Dev Catalog Requirement

Every shared primitive added under `design_tokens/primitives` should be visible in a dev-only preview surface:

- route: `/dev/design_tokens`

That surface should:

- autodiscover primitives rather than relying on manual registration
- show supported variants and states
- support light and dark mode previews
- expose a link to the Figma node that defines the primitive when a canonical Figma source exists

The intent is to make shared primitives discoverable, inspectable, and harder to drift.

Current starting point:

- `Button` now lives under `lib/oli_web/components/design_tokens/primitives/button.ex`
- `/dev/design_tokens` is the current HEEx dev catalog surface for shared primitives

These are the first concrete implementations of this convention and should be treated as the reference pattern for future shared primitives.

## Primitive Catalog Contract

Shared primitives should expose enough metadata to support autodiscovery by the dev catalog.

The exact implementation can evolve, but the contract should include at least:

- a stable display name
- the demo variants or states the catalog should render
- a Figma URL or node reference when one exists

This metadata should live with the primitive module so the preview surface remains self-updating as the primitive library grows.

## Documentation Expectations

Each shared primitive should include:

- a clear `@moduledoc`
- a documented public API
- notes on when it should be used
- any catalog metadata needed for `/dev/design_tokens`

## AI Agent Guidance

Repo-local guidance for AI agents should align with this document.

In particular:

- `implement_ui` should strongly prefer `design_tokens/` for cross-feature primitives
- agents should avoid creating ad hoc local primitive styling when a shared primitive exists or should exist
- when a new shared primitive is created, agents should wire it into the dev catalog and include the Figma reference when available

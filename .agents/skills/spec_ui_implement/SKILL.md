---
name: spec_ui_implement
description: Convert a provided UI design source into an implementation-ready design brief that maps visual intent to Torus design tokens, icons, reusable components, and code targets. Use when a Jira ticket or developer provides Figma or another design reference and the team needs governed implementation guidance before coding. Supports full feature-spec mode and lightweight `spec_work` mode.
examples:
  - "$spec_ui_implement docs/epics/intelligent_dashboard/tile_chrome slice=section-chrome figma=https://figma.com/..."
  - "Use spec_ui_implement for MER-5258; the Jira ticket has the Figma links"
  - "Before implementing this UI tweak with spec_work, run spec_ui_implement against this Figma link"
when_to_use:
  - "A feature or ticket has meaningful UI work and the visual source of truth is Figma or another design reference."
  - "The team needs to map design intent to existing tokens, icons, reusable components, and repo conventions before implementation."
  - "A ticket is small enough for `spec_work`, but still needs design-system triage before coding."
when_not_to_use:
  - "The work is backend-only or does not materially change the UI."
  - "There is no external design reference and local code inspection alone is sufficient."
  - "The task is direct implementation after design mapping is already settled."
---

## Required Resources

Always load before running:

- `references/workflow.md`
- `references/repo_waypoints.md`
- `references/guardrails.md`
- `references/target_organization.md`
- `references/design_system_sources.md`
- `assets/templates/ui_implementation_brief_template.md`

When running in feature mode, also read:

- `<feature_dir>/prd.md`
- `<feature_dir>/fdd.md` when present
- `<feature_dir>/plan.md` when present

When the feature lives under an epic, also consult relevant epic docs under `docs/epics/<epic_slug>/`.

## Mission

This skill does not implement UI code directly.

It produces an implementation-ready design brief that:

- identifies the visual source of truth
- maps design to existing Torus design tokens, icons, and reusable components
- identifies gaps that need developer confirmation
- recommends where code should live

Use it as a bridge between design references and implementation skills such as `spec_develop` or `spec_work`.

## Modes

Choose one mode up front:

- `full`
  - Use for feature work that already has a spec pack.
  - Write a durable artifact to `<feature_dir>/design/<slice_slug>.md`.
  - This mode is appropriate when the design materially affects planning or slice-level implementation.

- `lightweight`
  - Use for `spec_work` tickets or smaller UI changes.
  - Produce the brief in chat by default.
  - Do not create a file unless the user explicitly asks to persist the brief.

If the request does not specify a mode:

- prefer `full` when `feature_dir` is provided
- otherwise prefer `lightweight`

## Workflow

1. Resolve the source of truth for the design.
   - Prefer explicit Figma links from the user.
   - If the user points to a Jira ticket, extract Figma links from the ticket or its comments.
   - If multiple Figma nodes exist, identify which nodes correspond to the scope being implemented.
   - For icons, first check the Torus design-system icon source at `https://www.figma.com/design/4pTqLuqHbALAbZ31wvIHIX/NG-23---Torus-Design-System?node-id=2-24`.

2. Classify the implementation surface.
   - `liveview/heex`
   - `react`
   - `mixed`
   - State the chosen surface explicitly.

3. Inventory the design.
   - layout and structure
   - typography
   - colors and semantic intent
   - iconography
   - interactive states
   - responsive behavior
   - ambiguities or missing states

4. Map the design to the existing system.
   - design tokens
   - icon system
   - existing reusable components or patterns
   - likely target modules/files
   - for icons, prefer exact SVG extraction from Figma node assets over manual reconstruction

5. Detect and record gaps.
   - unrecognized token usage
   - hardcoded colors with no clear token mapping
   - missing icons
   - reusable component candidates
   - missing or ambiguous design states

6. Produce the design brief.
   - Use the exact section blocks from `assets/templates/ui_implementation_brief_template.md`.
   - In `full` mode, write `<feature_dir>/design/<slice_slug>.md`.
   - In `lightweight` mode, return the brief in chat unless the user explicitly requests persistence.

7. End with a clear handoff.
   - If implementation should follow, state whether the next skill should be `spec_develop` or `spec_work`.
   - Do not proceed to coding unless the user explicitly asks.

## Output Contract

Every brief must include:

- `Design Sources`
- `Implementation Surface`
- `Design System Alignment`
- `Token Mapping`
- `Icon Mapping`
- `Component Reuse Plan`
- `File Targets`
- `Open Questions / Requires Approval`

In `lightweight` mode, keep the same structure in chat unless the user asks for a shorter summary.

## Hard Rules

- Prefer existing design tokens over hardcoded colors or arbitrary utility values.
- When translating Figma spacing/radius/sizing into Tailwind utilities, prefer native Tailwind utility classes first.
  - Example: prefer `rounded-xl` over `rounded-[12px]` when they are equivalent.
  - Only use arbitrary values like `rounded-[13px]`, `px-[13px]`, or `h-[37px]` when there is no reasonable native Tailwind utility that preserves the design intent.
- If a color in the design does not map cleanly to an existing token, flag it and ask for approval before proposing implementation.
- Prefer the existing icon systems:
  - `OliWeb.Icons` for HEEx/LiveView
  - `assets/src/components/misc/icons/Icons` for React/TS
- Icon source priority is:
  - first, find the icon in the Torus design-system icon catalog at `node-id=2:24`
  - second, if it is not present there, inspect the feature-level Figma node
  - third, for feature-level icons, use MCP asset extraction to fetch the exact SVG from the icon node or its vector-owning child node
- When implementing or proposing a new icon from Figma, the default extraction method is:
  - identify the exact icon node, not just a surrounding frame
  - call Figma context/metadata tools on that node
  - if the response includes an asset URL from `https://www.figma.com/api/mcp/asset/...`, fetch that asset and use the returned SVG as the source of truth
  - if the selected node is a composite wrapper, recurse into the child node that owns the vector asset until you get the real icon SVG
  - do not manually redraw or approximate a Figma icon when the design-system catalog or MCP asset flow can provide an SVG
- Only fall back to manual SVG reconstruction when:
  - the icon is not available in the design-system icon catalog
  - the MCP asset flow does not expose an SVG for the node after checking the relevant child vector nodes
  - and that limitation is called out explicitly in the brief or handoff
- If an icon is missing, recommend extending the relevant icon system instead of introducing a local ad hoc icon.
- Prefer existing reusable components and patterns before introducing new primitives.
- If a repeated visual pattern suggests reuse, recommend extraction, but do not force a new shared component without justification.
- Avoid unnecessary nested tags and wrapper elements. Do not reproduce Figma frame nesting literally unless that structure is required for semantics, layout, accessibility, or interactive state handling.
- Do not invent missing design behavior. Escalate ambiguities.
- Do not create or modify design tokens automatically. You may recommend additions, but approval is required before implementation.

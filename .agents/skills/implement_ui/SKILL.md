---
name: implement_ui
description: Convert a provided UI design source into an implementation-ready design brief that maps visual intent to Torus design tokens, icons, reusable components, and code targets. Use when a Jira ticket or developer provides Figma or another design reference and the team needs governed implementation guidance before coding. Supports durable feature briefs and lightweight ticket-level briefs.
examples:
  - "$implement_ui docs/exec-plans/current/epics/intelligent_dashboard/tile_chrome slice=section-chrome figma=https://figma.com/..."
  - "Use implement_ui for MER-5258; the Jira ticket has the Figma links"
  - "Before implementing this UI tweak with harness-work, run implement_ui against this Figma link"
when_to_use:
  - "A feature or ticket has meaningful UI work and the visual source of truth is Figma or another design reference."
  - "The team needs to map design intent to existing tokens, icons, reusable components, and repo conventions before implementation."
  - "A ticket is small enough for `harness-work`, but still needs design-system triage before coding."
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

Load when needed:

- `references/icon_mapping.md`
  - when the brief needs to map a new icon, verify whether an icon already exists, or recommend icon-system extension
- `references/fidelity_rules.md`
  - when the brief must describe static vs dynamic fidelity, overflow handling, or implementation constraints that affect layout matching
- `references/responsive_validation.md`
  - when the design includes breakpoint-specific behavior, dense dashboards, charts, stacked layouts, or any responsive ambiguity that should be called out before coding

When running in feature mode, also read:

- `<feature_dir>/prd.md`
- `<feature_dir>/fdd.md` when present
- `<feature_dir>/plan.md` when present

When the feature lives under an epic, also consult relevant epic docs under `docs/exec-plans/current/epics/<epic_slug>/`.

## Mission

This skill does not implement UI code directly.

It produces an implementation-ready design brief that:

- identifies the visual source of truth
- maps design to existing Torus design tokens, icons, and reusable components
- identifies gaps that need developer confirmation
- recommends where code should live

Use it as a bridge between design references and implementation skills such as `harness-develop` or `harness-work`.

## Preferred Execution Context

This skill can run in plain Codex mode.

Prefer Tidewave when available for:

- complex UI surfaces
- responsive layouts
- dashboard or chart-heavy views
- work where visual fidelity is especially important

Why:

- Tidewave enables faster runtime inspection, viewport resizing, and visual verification against the design source.
- In practice this often produces a stronger brief with fewer hidden assumptions than Codex-only execution.

If Tidewave is not available, continue in Codex and record uncertainty more explicitly in `Open Questions / Requires Approval`.

## Modes

Choose one mode up front:

- `full`
  - Use for feature work that already has a spec pack.
  - Write a durable artifact to `<feature_dir>/design/<slice_slug>.md`.
  - This mode is appropriate when the design materially affects planning or slice-level implementation.

- `lightweight`
  - Use for `harness-work` tickets or smaller UI changes.
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
   - whether the result should stay feature-local or be extracted to `design_tokens/`
   - load conditional references when icon extraction, fidelity rules, or responsive behavior need deeper guidance

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
   - If implementation should follow, state whether the next skill should be `harness-develop` or `harness-work`.
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

## Guardrails

Follow the detailed rules in:

- `references/guardrails.md`
- `references/target_organization.md`
- `references/design_system_sources.md`
- `references/icon_mapping.md` when icon work is in scope
- `references/fidelity_rules.md` when fidelity or overflow behavior must be specified
- `references/responsive_validation.md` when responsive behavior must be assessed

Non-negotiable rules:

- Prefer existing design tokens, icons, and reusable components before proposing new ones.
- If a token, icon, interaction, or responsive behavior is ambiguous, record it under `Open Questions / Requires Approval`.
- Do not invent missing design behavior.
- Do not create or modify design tokens automatically. Recommend additions only when necessary and only with explicit approval.

## Validation

Before finishing, verify that the brief:

- uses the exact section structure from `assets/templates/ui_implementation_brief_template.md`
- names the primary design source and the relevant Figma node ids or links
- states the implementation surface explicitly
- maps tokens, icons, reusable components, and file targets
- records any unresolved ambiguity or approval-dependent decision in `Open Questions / Requires Approval`

## Handoff Guidance

If the user wants implementation next:

- use `harness-develop` for planned feature execution
- use `harness-work` for smaller ticket-level execution
- tell the implementer to read the resulting brief before coding

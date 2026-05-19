---
name: ui_workflow
description: Execute the repo-local Figma-backed UI implementation workflow, including governed design mapping, current-state audit, targeted implementation, verification, iteration, and runtime memory management outside the repository.
examples:
  - "$ui_workflow MER-5258"
  - "Use ui_workflow for this Jira ticket; the design is in Figma"
  - "Run ui_workflow against this Figma link before implementing the UI"
when_to_use:
  - "A ticket or feature includes a Figma design and the implementation needs fidelity to that source."
  - "UI implementation should be compared iteratively against the design source."
  - "A work item needs governed design mapping plus implementation and QA, not just a brief."
when_not_to_use:
  - "The task is backend-only."
  - "There is no external design source and local code inspection alone is sufficient."
  - "The work only needs governed design mapping with no implementation or iteration."
---

## Required Resources

Always load before running:

- `.agents/ui-workflow/README.md`
- `.agents/ui-workflow/runtime-contract.md`
- `.agents/commands/ui-plan.md`
- `.agents/commands/ui-implement.md`
- `.agents/commands/ui-qa.md`
- `.agents/commands/ui-fix.md`
- `.agents/commands/ui-reflect.md`
- `.agents/agents/ui-jira-figma-resolver.md`
- `.agents/agents/ui-browser-readiness-checker.md`
- `.agents/agents/ui-current-state-auditor.md`
- `.agents/agents/ui-implementer.md`
- `.agents/agents/ui-layout-verifier.md`
- `.agents/agents/ui-visual-verifier.md`
- `.agents/agents/ui-reviewer.md`
- `.agents/agents/ui-retrospective-updater.md`
- `.agents/skills/implement_ui/SKILL.md`

Load when needed:

- `.agents/skills/implement_ui/references/workflow.md`
- `.agents/skills/implement_ui/references/repo_waypoints.md`
- `.agents/skills/implement_ui/references/guardrails.md`
- `.agents/skills/implement_ui/references/target_organization.md`
- `.agents/skills/implement_ui/references/design_system_sources.md`
- `.agents/skills/implement_ui/references/icon_mapping.md`
- `.agents/skills/implement_ui/references/fidelity_rules.md`
- `.agents/skills/implement_ui/references/responsive_validation.md`
- `.agents/skills/implement_ui/assets/templates/ui_implementation_brief_template.md`

## Mission

This skill is the canonical entrypoint for Figma-backed UI implementation work in this repository.

It owns:

- governed design mapping
- canonical brief creation
- current-state auditing
- targeted UI implementation
- layout and visual verification
- iterative review
- runtime workflow memory under `~/.codex/memories/oli-torus-ng/ui-work/`

The workflow should validate the Browser MCP window after the human prepares the correct route, role, and app state for browser-based QA.

## Entry Modes

Choose the narrowest matching mode:

- `plan`
  - when the scope has not been normalized yet
  - creates the canonical brief and runtime state

- `implement`
  - when a scope already has a brief and should move through audit, implementation, and iteration

- `qa`
  - when implementation already happened and verification should run again

- `fix`
  - when one or more existing deltas should be corrected without widening scope

- `reflect`
  - when the scope produced a reusable workflow or implementation learning

If the request does not specify a mode:

- prefer `plan` when no runtime state exists yet
- otherwise prefer `implement`

## Canonical Sequence

1. Resolve the UI source of truth from Jira and/or Figma.
2. Initialize or reuse the runtime scope directory under `~/.codex/memories/oli-torus-ng/ui-work/<scope>/`.
3. Run the governed design-mapping phase to create the canonical brief.
4. Audit the current implementation and produce structured deltas.
5. Implement targeted fixes against the active delta set.
6. Run browser-readiness, then layout and visual verification when available.
7. Review the result and decide `done`, `iterating`, or `needs-human-review`.
8. Record iteration outputs in runtime memory.
9. Capture generalized workflow learnings back into the repo when warranted.

## Operational Procedure

### Mode: `plan`

Use `.agents/commands/ui-plan.md` as the execution contract.

The skill should:

1. Normalize the input using `ui-jira-figma-resolver`.
2. Determine a stable `<scope>` name.
3. Create or reuse the runtime directory.
4. Run the governed design-mapping phase.
5. Write:
   - `session.json`
   - `source_refs.json`
   - `brief.md`
6. Set `session.json` to a planned state.

### Mode: `implement`

Use `.agents/commands/ui-implement.md` as the execution contract.

The skill should:

1. Load the existing runtime state.
2. Run `ui-current-state-auditor`.
3. Update `audit.md`.
4. Generate or update `deltas.json`.
5. Run `ui-implementer`.
6. Run `ui-browser-readiness-checker` before browser-based QA when required by the runtime policy.
7. Run `ui-layout-verifier` when the relevant data is available and browser readiness is confirmed.
8. Run `ui-visual-verifier` when the relevant data is available and browser readiness is confirmed.
9. Run `ui-reviewer`.
10. Write a new iteration record.
11. Update `session.json`.

### Mode: `qa`

Use `.agents/commands/ui-qa.md` as the execution contract.

The skill should:

1. Reuse the canonical brief and current runtime state.
2. Re-run `ui-browser-readiness-checker`.
3. Re-run the available verification stages.
4. Run `ui-reviewer`.
5. Write a new iteration record and update `session.json`.

### Mode: `fix`

Use `.agents/commands/ui-fix.md` as the execution contract.

The skill should:

1. Load `deltas.json`.
2. Narrow the active delta set if the user specified ids or categories.
3. Run `ui-implementer` only against that targeted scope.
4. Run `ui-browser-readiness-checker` before browser-based QA when needed.
5. Run the available verification stages.
6. Run `ui-reviewer`.
7. Write a new iteration record and update `session.json`.

### Mode: `reflect`

Use `.agents/commands/ui-reflect.md` as the execution contract.

The skill should:

1. Read the current scope state and iteration history.
2. Capture the local learning in `learnings.md`.
3. If the learning affects future workflow behavior, update the repo-local workflow files in the same task.

## Scope Resolution

Use this precedence when choosing the runtime scope id:

1. explicit Jira issue key
2. explicit user-provided scope name
3. stable slug derived from the Figma-backed surface

Examples:

- `MER-5258`
- `MER-5258--student-dashboard-overview`
- `student-dashboard-overview`

## Adding Figma Nodes

During execution, the human may add one or more Figma nodes to the active scope.

The workflow should accept either:

- natural language, for example `Add this Figma node to MER-5254 as "close button modal"`
- or an explicit form such as `$ui_workflow add-node MER-5254 <figma-url> alias="close button modal"`

The workflow must not assume the human already knows the `add-node` name.

If the workflow detects that the current Figma reference is missing a specific node or is too ambiguous for reliable implementation or QA, it should suggest both options explicitly.

When a node is added:

- update `source_refs.json`
- preserve any useful human-friendly alias
- refresh the brief or downstream runtime state only when the added node materially changes the source of truth

## State Transitions

`session.json` should move through these states as appropriate:

- `planned`
- `auditing`
- `implementing`
- `iterating`
- `needs-human-review`
- `done`

Prefer explicit state transitions over implicit assumptions.

## Relationship To `implement_ui`

`implement_ui` is not the canonical entrypoint for Figma-backed implementation work.

Within this skill, it is treated as part of the governed design-mapping phase and its useful rules must be preserved:

- token mapping
- icon reuse
- shared-vs-local component placement
- `design_tokens/` extraction decisions
- surface classification
- responsive ambiguity handling
- explicit file targeting

## Output Expectations

The skill must produce or maintain runtime state under:

```text
~/.codex/memories/oli-torus-ng/ui-work/<scope>/
```

At minimum, the active scope should have:

- `session.json`
- `source_refs.json`
- `brief.md`

And, once implementation begins:

- `audit.md`
- `deltas.json`
- `iterations/*.md`
- `qa/*.json` when verification runs

## Verification Policy

When verification stages are available:

- run layout verification before visual verification
- let `ui-reviewer` decide the final workflow status
- do not let visual similarity override the canonical brief or governed-design rules
- if the browser lands on login or otherwise lacks a valid session, stop and tell the user which role-specific session is required before continuing
- use Browser MCP for live inspection in the human-prepared QA browser window
- use Figma MCP for design-source inspection

If verification is not yet available for a given scope, continue to use the brief, audit, and reviewer decision explicitly rather than pretending verification happened.

## Browser Readiness Contract

The workflow should ask the human to prepare the Browser MCP window before deep QA and then treat that window as the canonical QA browser for the active scope.

If authentication, navigation, or role selection is still required:

- stop QA
- tell the human which role is required
- tell the human to log in and navigate to the intended surface in that same Browser MCP window
- re-run browser readiness before continuing

## Guardrails

- Do not bypass the canonical brief.
- Do not treat visual similarity as a reason to ignore token, icon, or component-governance rules.
- Do not invent missing states, interactions, or responsive behavior.
- Do not commit runtime iteration files to the repository.
- If a workflow learning changes future behavior, update the repo-local workflow in the same task.

## Handoff

Typical next actions:

- after `plan` → continue with `implement`
- after `implement` with open deltas → continue with `fix` or `qa`
- after `done` or `needs-human-review` → run `reflect` if there is a reusable learning

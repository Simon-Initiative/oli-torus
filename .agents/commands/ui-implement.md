# UI Implement

Implement and refine a Figma-backed UI scope using the repo-local UI workflow.

## Purpose

Use this command after `ui-plan` has produced the canonical brief.

This command owns:

- current-state auditing
- delta generation
- targeted implementation
- iterative review state

## Inputs

- `<scope>` corresponding to:

```text
~/.codex/memories/oli-torus-ng/ui-work/<scope>/
```

## Workflow

1. Load `session.json`, `source_refs.json`, and `brief.md`.
2. Run `ui-current-state-auditor`.
3. Generate or update `audit.md`.
4. Generate or update `deltas.json`.
5. Run `ui-implementer` against the active delta set.
6. Run `ui-browser-readiness-checker` before any browser-based QA step when:
   - no previous browser check exists
   - the last check is older than one hour
   - the validated route, role, or equivalent context fingerprint changed
   - the previous result was not ready
7. If browser readiness fails, record the blocker in `session.json`, tell the human to prepare the Browser MCP window with the required role and the intended UI surface, and continue code iteration only when useful work remains outside browser QA.
8. Run `ui-layout-verifier` only when browser readiness is confirmed and deterministic checks are available.
9. If `layout-qa` finds material structural issues, loop back through `ui-implementer` before trusting visual closure.
10. Run `ui-visual-verifier` only when browser readiness is confirmed and visual comparison is available.
11. Run the review step and update runtime state.
12. If the scope appears ready, move to `needs-human-review` rather than `done` until the human checkpoint occurs.
13. If the scope is not yet complete, write an iteration report.

## Required Outputs

The command must create or update:

- `audit.md`
- `deltas.json`
- `iterations/<n>.md`
- `session.json`
- `qa/browser-readiness-<n>.json` when readiness is checked

under:

```text
~/.codex/memories/oli-torus-ng/ui-work/<scope>/
```

## Status Model

`session.json` should move through these states as appropriate:

- `planned`
- `auditing`
- `implementing`
- `iterating`
- `needs-human-review`
- `done`

## Rules

- Do not bypass the canonical brief.
- Do not chase visual fidelity by breaking token, icon, or component-governance rules.
- Do not invent missing design states or interactions.
- If the implementation surface is unclear, resolve it explicitly as `liveview/heex`, `react`, or `mixed`.
- Use the Browser MCP window prepared by the human as the canonical QA browser for the active scope.

# UI QA

Re-run verification and review for a previously planned UI scope without re-planning it.

## Purpose

Use this command when:

- a scope was edited manually
- a previous implementation pass needs re-checking
- verification should run again without rebuilding the entire plan

## Inputs

- `<scope>` corresponding to:

```text
~/.codex/memories/oli-torus-ng/ui-work/<scope>/
```

## Workflow

1. Load `session.json`, `source_refs.json`, `brief.md`, and `deltas.json`.
2. Run `ui-browser-readiness-checker` before verification starts.
3. The readiness checker must inspect the Browser MCP window as the human left it for this scope.
4. If the browser is not on the intended surface, lacks a valid session, or uses the wrong role, stop and tell the user:
   - which role must be logged in
   - that they should use the Browser MCP window for this scope
   - that they should navigate to the intended surface there before QA continues
5. Re-run `ui-layout-verifier` first when deterministic checks are available.
6. If `layout-qa` still finds material structural issues, report that the scope should return to the automatic fix loop before trusting visual closure.
7. Re-run `ui-visual-verifier` for the current state when visual comparison is available.
8. Run `ui-reviewer`.
9. If the automatic QA pass appears ready, prefer `needs-human-review` over `done` until the human checkpoint occurs.
10. Write a new iteration record summarizing the result.
11. Update `session.json`.

## Required Outputs

The command must update:

- `iterations/<n>.md`
- `session.json`
- `qa/browser-readiness-<n>.json`

and any verification artifacts already used by the workflow.

## Rules

- Do not re-plan the scope unless the source of truth changed materially.
- Use the existing brief as the contract unless the brief itself is revised.
- Do not spend time on downstream QA steps if the browser session is not authenticated for the required role.
- Use the Browser MCP window prepared by the human as the canonical QA browser for the active scope.
- If route, role, theme, or app state are not ready for inspection, stop and report that blocker explicitly.

# UI Fix

Fix one or more identified deltas for an existing UI workflow scope.

## Purpose

Use this command when a scope already exists and the work should focus on targeted fixes rather than a full re-plan.

Typical cases:

- one or more deltas remain open after a prior iteration
- manual review identified a specific mismatch to correct
- a follow-up pass should address a narrow subset of issues

## Inputs

- `<scope>` corresponding to:

```text
~/.codex/memories/oli-torus-ng/ui-work/<scope>/
```

- optional delta ids or categories to narrow the fix scope

## Workflow

1. Load `session.json`, `brief.md`, `audit.md`, and `deltas.json`.
2. Select the active delta set for this fix pass.
3. Run `ui-implementer` against only those deltas.
4. Run `ui-layout-verifier` first when deterministic checks are available.
5. If `layout-qa` still finds material structural issues, keep the scope in the automatic loop instead of treating visual output as closure-ready.
6. Run `ui-visual-verifier` when visual comparison is available.
7. Run `ui-reviewer`.
8. If the automatic loop appears complete, move to `needs-human-review` instead of `done` until the human checkpoint occurs.
9. Write a new iteration report and update `session.json`.

## Required Outputs

The command must update:

- `deltas.json`
- `iterations/<n>.md`
- `session.json`

and any relevant verification artifacts.

## Rules

- Do not widen scope unless the existing delta set requires it.
- Keep fixes targeted and explicit.
- If a targeted fix exposes a broader governed-design issue, record that in the runtime state instead of silently expanding the work.

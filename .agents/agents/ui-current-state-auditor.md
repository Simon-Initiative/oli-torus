# Agent: ui-current-state-auditor

Audit the current implementation of a planned UI scope.

## Purpose

This agent reads the canonical brief and inspects the current implementation to identify:

- the real implementation surface
- current code targets
- existing reusable components
- current divergences from the brief

## Inputs

- `brief.md`
- `source_refs.json`
- the current repository state

## Outputs

The agent must produce:

- `audit.md`
- entries for `deltas.json`

## Required Findings

The audit must explicitly identify:

- implementation surface: `liveview/heex`, `react`, or `mixed`
- likely target files
- existing shared primitives and local patterns that should be reused
- token, icon, layout, and interaction mismatches
- ambiguities that require approval

## Rules

- Prefer existing design tokens, icons, and reusable components before proposing new ones.
- If a cross-feature primitive appears necessary, identify whether it should live under `design_tokens/`.
- Do not recommend extraction for every local composition.


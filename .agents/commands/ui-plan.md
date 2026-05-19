# UI Plan

Establish the canonical UI implementation brief for a Figma-backed scope.

## Purpose

Use this command when a ticket or request includes:

- a Jira issue with Figma links
- a direct Figma link
- a concrete UI implementation target that needs governed design mapping before coding

This command is the planning entrypoint for the repo-local UI workflow.

## Inputs

- Jira issue key, or
- direct Figma URL, or
- a work item plus explicit Figma reference

## Workflow

1. Resolve the source of truth for the UI scope.
2. Run `ui-jira-figma-resolver` to normalize Jira and Figma references.
3. Run the governed design-mapping phase for the resolved scope.
4. Produce the canonical brief for downstream UI implementation.
5. Initialize the runtime state under `~/.codex/memories/oli-torus-ng/ui-work/<scope>/`.

## Required Outputs

The command must create or update:

- `session.json`
- `source_refs.json`
- `brief.md`

under:

```text
~/.codex/memories/oli-torus-ng/ui-work/<scope>/
```

## Rules

- Do not implement code in this command.
- Do not skip governed design mapping for Figma-backed work.
- The resulting brief becomes the canonical input for `ui-implement` and `ui-qa`.
- If the scope is ambiguous, record it in the brief and runtime state instead of guessing.

## Handoff

After this command completes, the next step is:

```text
ui-implement <scope>
```


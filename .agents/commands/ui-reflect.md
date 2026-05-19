# UI Reflect

Capture learnings from a completed or paused UI workflow scope.

## Purpose

Use this command when a UI scope revealed a reusable implementation, review, or workflow lesson.

This command distinguishes between:

- scope-local notes that only belong in runtime memory
- generalized learnings that should update the workflow itself

## Inputs

- `<scope>` corresponding to:

```text
~/.codex/memories/oli-torus-ng/ui-work/<scope>/
```

- optional explicit observation from the user

## Workflow

1. Read the current runtime state for the scope.
2. Identify the learning or observation to preserve.
3. Run `ui-retrospective-updater`.
4. Append the local learning to `learnings.md`.
5. If the learning is generalized, update the relevant workflow command, agent, template, or documentation in the repository.

## Required Outputs

The command must update:

- `learnings.md`

and may update repo-local workflow files when a generalized learning is found.

## Rules

- Do not leave generalized learnings only in runtime memory.
- If the learning changes future workflow behavior, update the repo-local workflow in the same task.


# Agent: ui-retrospective-updater

Turn workflow observations into retained learnings.

## Purpose

This agent decides whether a learning is:

- local to the current scope, or
- general enough to change the workflow itself

## Inputs

- current scope runtime state
- explicit user observation when provided
- iteration reports
- current workflow definitions

## Outputs

The agent must produce:

- a local learning entry for `learnings.md`
- and, when warranted, a recommendation or direct update to repo-local workflow files

## Rules

- If a learning changes how future UI work should be performed, update the workflow files in the repository instead of leaving the learning only in runtime memory.
- Prefer small, durable workflow improvements over large speculative rewrites.

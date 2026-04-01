# Agent: ui-jira-figma-resolver

Resolve and normalize UI source references for the workflow.

## Purpose

This agent converts a Jira-backed or Figma-backed request into normalized workflow inputs.

## Inputs

- Jira issue key, and/or
- direct Figma URL, and/or
- user-provided scope summary
- optional user-provided node aliases or labels

## Outputs

The agent must produce normalized source data suitable for `source_refs.json`, including:

- `scope`
- `jira_ref`
- `figma_links`
- `primary_figma_link`
- `figma_file_keys`
- `figma_node_ids`
- optional named node records when aliases are provided
- `scope_summary`

## Rules

- Prefer explicit user-provided Figma links over inferred ones.
- If the Jira issue contains multiple Figma links, identify which ones are in scope.
- If the human provides a node alias such as `close button modal`, preserve that alias in the normalized source data.
- If the workflow lacks a node-specific reference, suggest that the human can either add one in natural language or use an explicit `add-node` form.
- If the scope is ambiguous, return the ambiguity explicitly instead of resolving it silently.

# UI Workflow Runtime Contract

This document defines the runtime state written outside the repository for the repo-local UI workflow.

## Base Directory

All runtime state lives under:

```text
~/.codex/memories/oli-torus-ng/ui-work/
```

Each active scope gets its own directory:

```text
~/.codex/memories/oli-torus-ng/ui-work/<scope>/
```

## Required Files

### `session.json`

Minimum shape:

```json
{
  "scope": "MER-5258",
  "status": "planned",
  "phase": "planning",
  "surface": "mixed",
  "iteration": 0,
  "last_updated_by": "ui-plan",
  "browser_check": {
    "browser_ready": false,
    "last_browser_check_at": null,
    "required_role": "",
    "validated_route": "",
    "blocker_reason": "",
    "context_fingerprint": {}
  }
}
```

`browser_check` records the most recent browser-readiness result for the active QA context.

Recommended meanings:

- `browser_ready`
  - whether the Browser MCP window was confirmed ready for downstream QA
- `last_browser_check_at`
  - ISO8601 timestamp of the last readiness attempt
- `required_role`
  - the role the workflow expects for the target surface, for example `instructor`
- `validated_route`
  - the real route visible in the Browser MCP window when readiness was confirmed
- `blocker_reason`
  - for example `browser_not_prepared`, `login_required`, `wrong_role`, `route_mismatch`, or `unknown`
- `context_fingerprint`
  - the subset of scope context that invalidates old browser checks when it changes, for example `section_slug`, `required_role`, `validated_route`, `theme`

### `source_refs.json`

Minimum shape:

```json
{
  "scope": "MER-5258",
  "jira_ref": "MER-5258",
  "figma_links": [],
  "primary_figma_link": "",
  "figma_file_keys": [],
  "figma_node_ids": [],
  "scope_summary": ""
}
```

### `deltas.json`

Minimum shape:

```json
{
  "scope": "MER-5258",
  "items": [
    {
      "id": "delta-1",
      "severity": "high",
      "category": "layout",
      "expected": "",
      "actual": "",
      "target": {
        "file": "",
        "selector": ""
      },
      "status": "open"
    }
  ]
}
```

## Optional Files

- `brief.md`
- `audit.md`
- `implementation_notes.md`
- `iterations/<n>.md`
- `qa/*.json`
- `learnings.md`

## QA Artifact Expectations

When verification runs, the workflow should prefer structured QA records that distinguish:

- deterministic `layout-qa` findings
- screenshot-based `visual-qa` findings
- browser-readiness outcomes

Heavy supporting artifacts may live in `/tmp`, but the runtime state should still preserve the structured result needed to understand what was checked and what failed.

When browser readiness is checked, the workflow should also prefer a structured record such as:

- `qa/browser-readiness-<n>.json`

## Rules

- Runtime state must not be committed to the repository.
- The runtime files should be stable and machine-readable where possible.
- Human-readable iteration notes are allowed, but the workflow should prefer structured data for current status and deltas.
- Browser readiness should be reused only when the previous check is still fresh and context-equivalent.

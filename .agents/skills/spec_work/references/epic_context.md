# Epic Context

When Jira ticket belongs to an epic, use epic docs for constraints and alignment.

## Epic Context Inputs
- Jira epic key/title from ticket fields.
- Local epic docs under `docs/epics/<epic_slug>/`:
  - `overview.md`
  - `prd.md`
  - `edd.md` (if present)
  - `plan.md` (if present)

## Mapping Rule
1. Prefer an exact slug match when epic slug is known.
2. Otherwise, derive candidate slugs from normalized epic title and choose best local match.
3. If multiple equally plausible matches exist, ask user which epic directory to use.

## Usage Rule
- Epic context constrains implementation decisions and out-of-scope boundaries.
- Do not edit epic docs in this lane unless user explicitly asks.

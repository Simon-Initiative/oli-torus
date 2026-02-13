# Jira Intake

Use Jira MCP as the authoritative source for enhancement requirements.

## Required Inputs
- Jira key or browse URL.

## Fetch Requirements
- Issue type, summary, description, status, labels/components.
- Acceptance criteria/custom fields when present.
- Epic link/parent and related issue links when present.
- All comments, then filter for engineering clarifications.

## Engineering Clarification Extraction
Prioritize comments that include:
- Constraints, non-goals, edge cases, risk notes.
- Architecture notes, module/file hints, data-impact notes.
- Test guidance and rollout cautions.

Treat those as clarification inputs and cite them in the brief plan summary.

## Failure Handling
- If Jira MCP is unavailable or ticket cannot be fetched, stop and report blocker.
- Do not infer missing ticket facts when authoritative Jira data is unavailable.

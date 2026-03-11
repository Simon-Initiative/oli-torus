# Workflow Notes

## Triage

Use this skill only when UI work materially depends on an external design reference.

Quick triage:
- `backend-only`: do not use this skill
- `ui-without-design-source`: usually do not use this skill
- `ui-with-design-source`: use this skill

## Integration with SDD

- `full` mode:
  - supports feature work with PRD/FDD/plan
  - output should become durable design guidance under `design/`

- `lightweight` mode:
  - supports `spec_work`
  - output should remain in chat unless the user explicitly asks to persist it

## Handoff

This skill stops at analysis + mapping + brief.

Typical next step:
- `spec_develop` for feature work
- `spec_work` for small-ticket execution


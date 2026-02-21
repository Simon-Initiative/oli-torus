# Definition of Done

A spec artifact is done only when all checks below pass:

- Required headings exist and are in the expected order.
- Requirement traceability is explicit:
  - PRD uses inline `AC-###` IDs or points sections `6` and `7` to `requirements.yml`, and
  - `requirements.yml` exists when pointer pattern is used.
- No unresolved `TODO` / `TBD` / `FIXME` markers remain.
- Links are valid (local paths resolve, anchors resolve, external URLs are syntactically valid).
- Assumptions and open questions are explicit (none hidden in narrative prose).
- Verification expectations are explicit (tests, commands, or reviewer checks).
- Scope boundaries are explicit (what is intentionally out of scope).

Do not mark a document complete if any item above is failing.

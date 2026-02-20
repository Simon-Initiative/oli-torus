# Definition of Done

A spec artifact is done only when all checks below pass:

- Required headings exist and are in the expected order.
- `requirements.yml` exists with `FR-###` and `AC-###` IDs and passes structure validation.
- `prd.md` does not duplicate FR/AC entries and sections 6 and 7 point to `requirements.yml`.
- No unresolved `TODO` / `TBD` / `FIXME` markers remain.
- Links are valid (local paths resolve, anchors resolve, external URLs are syntactically valid).
- Assumptions and open questions are explicit (none hidden in narrative prose).
- Verification expectations are explicit (tests, commands, or reviewer checks).
- Scope boundaries are explicit (what is intentionally out of scope).

Do not mark a document complete if any item above is failing.

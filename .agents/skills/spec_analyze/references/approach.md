# Approach

Use this sequence when creating or updating a PRD:

1. Confirm input: ensure the user has provided an informal feature description (and screenshots if available).
2. Interpret intent: restate problem, target users, desired outcomes, and constraints in product terms.
3. Draft from template: keep headings and order exactly as required by `assets/templates/prd_template.md`.
4. Convert ambiguity into explicit assumptions: do not block on unknowns; record assumptions and open questions.
5. Make requirements testable:
   - Functional requirements use `FR-###` IDs.
   - Acceptance criteria use `AC-### (FR-###)` and Given/When/Then.
6. Include Torus platform realism: roles, tenancy, NFRs, data and API impacts, observability, security, and rollout posture.
7. Keep scope sharp: separate goals from non-goals to reduce implementation drift.
8. Finish with verification: run checklist, definition of done, and spec validation gate.

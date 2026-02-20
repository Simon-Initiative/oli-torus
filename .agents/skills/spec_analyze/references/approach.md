# Approach

Use this sequence when creating or updating a PRD:

1. Confirm input: ensure the user has provided an informal feature description (and screenshots if available).
2. Interpret intent: restate problem, target users, desired outcomes, and constraints in product terms.
3. Draft from template: keep headings and order exactly as required by `assets/templates/prd_template.md`.
4. Convert ambiguity into explicit assumptions: do not block on unknowns; record assumptions and open questions.
5. Keep requirements source-of-truth clean:
   - In `prd.md`, sections `6` and `7` must each contain only `Requirements are found in requirements.yml`.
   - Place all `FR-###` and `AC-###` content in `requirements.yml`, not `prd.md`.
6. Include Torus platform realism: roles, tenancy, NFRs, data and API impacts, observability, and security. Add rollout posture only when feature flags are explicitly part of scope.
7. Keep scope sharp: separate goals from non-goals to reduce implementation drift.
8. Finish with verification: run checklist, definition of done, and spec validation gate.

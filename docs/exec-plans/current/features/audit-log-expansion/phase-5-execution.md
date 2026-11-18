# Phase 5 Execution Record

Work item: `docs/exec-plans/current/features/audit-log-expansion`
Phase: `5` (MER-6115, PR-05), design `design/pr-05-delivery-and-configuration.md`

## Scope from plan.md
- Coverage for delivery and configuration: assessment settings and the `settings_changes` conversion, student exceptions, section/product/blueprint lifecycle and settings, section DOT and instructor recommendations, saved remixes, publication updates, gating and scheduling, and discussion, notes, and student-support configuration.
- Authorization: checkpoints after design approval, each committed after owner review. No push or publication authorized.
- Branch: `sub-task/MER-6115-audit-log-coverage-delivery-and-configuration`, created from PR-04's last commit `3575b5cacc`; not pushed.

## Implementation Blocks
- [x] Scope aligned with MER-6066 on 2026-11-18, with four owner decisions:
  - `settings_changes` rows become v1 `assessment_setting_changed` events with password values recorded only as redaction markers; the table is dropped in the same migration, and `down/0` rebuilds it from the v1 events without the secrets.
  - Publication updates carry the initiating actor in the job arguments and record their event inside the update transaction; a rerun that finds the publication already applied and a failed update record nothing.
  - All certificate configuration, including the section `certificate_enabled` toggle, belongs to PR-06; PR-05 keeps that key open in the generic section update path.
  - The configuration-key inventory is the classification of the `sections` columns in code, enforced by a test, which restricts `Sections.update_section/2`.
- [x] Design approved by the owner on 2026-11-18 (`design/pr-05-delivery-and-configuration.md`), with decisions D1 to D4 (template entities as `product_*` labeled "Template"; no reset-to-defaults event; no section student-support event; LTI service fields synced by the launch without an event), three facades by owning context plus project-side discussions in `Oli.Authoring.Audited`, the mass assignment fixed in this PR, and pre-deployment update jobs recorded under `scheduled_maintenance`.
- [x] Pre-existing mass assignment in the section edit form, confirmed on 2026-11-18 with a temporary LiveView test (deleted): a non-admin instructor enrolled in the section pushed the `"save"` event of `OliWeb.Sections.EditView` with fields the form does not offer, and `title`, `amount`, `assistant_enabled`, `grade_passback_enabled`, `line_items_service_url`, and `status` were all saved. The section settings command of checkpoint B, which accepts only the form's fields, closes it in this PR (owner decision 2026-11-18: no separate TRIAGE ticket).

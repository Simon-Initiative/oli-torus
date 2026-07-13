# Instructor Customizations

Use `instructor_customization` to apply instructor-owned activity exclusions to a published section page.
The directive calls the real `Oli.Delivery.InstructorCustomizations` context, so it exercises the same
authorization, target validation, and persistence used by delivery code.

## instructor_customization

```yaml
- instructor_customization:
    section: "demo_section"
    page: "Practice"
    actor: "instructor_1"
    ops:
      - exclude_activity:
          activity_virtual_id: "embedded_q1"
      - exclude_bank_selection:
          selection_id: "selection_1"
      - exclude_bank_candidate:
          selection_id: "selection_1"
          activity_virtual_id: "banked_q1"
```

Supported operations:

- `exclude_activity` / `restore_activity`: disable or re-enable an embedded activity by `activity_virtual_id`.
- `exclude_bank_selection` / `restore_bank_selection`: disable or re-enable a whole bank-selection block by `selection_id`.
- `exclude_bank_candidate` / `restore_bank_candidate`: disable or re-enable one banked activity candidate within a selection.

## activity customization assertions

Use `assert.activity_customization` to check persisted customization state without starting a learner attempt.

```yaml
- assert:
    activity_customization:
      section: "demo_section"
      page: "Practice"
      embedded_activities:
        - activity_virtual_id: "embedded_q1"
          enabled: false
      bank_selections:
        - selection_id: "selection_1"
          enabled: true
      bank_candidates:
        - selection_id: "selection_1"
          activity_virtual_id: "banked_q1"
          enabled: false
```

For delivery checks, `assert.activity_attempt` also accepts `exists: false` to verify that an excluded
activity did not produce a learner activity attempt after `view_practice_page` or `visit_page`.

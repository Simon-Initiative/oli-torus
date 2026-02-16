# PRD Checklist

Use this checklist before saving `prd.md`:

- Keep required headings from `assets/templates/prd_template.md`.
- Ensure sections are in the exact template order and all headings are present.
- Use `FR-###` IDs in the Functional Requirements table.
- Use `AC-### (FR-###)` in Given/When/Then format.
- Ensure at least one acceptance criterion exists.
- Make scope boundaries explicit (goals vs non-goals).
- Include role/permission expectations.
- For section 11: if the informal description requires feature flags, include rollout and rollback notes; otherwise include exactly `No feature flags present in this feature`.
- Include Torus-specific constraints where relevant: tenancy, LTI roles, accessibility, observability, security/privacy.
- Include measurable non-functional budgets when relevant.
- Include data model/API contract impacts and permissions matrix entries.
- Include QA coverage across automated and manual checks plus NFR performance verification approach.
- Remove unresolved `TODO`/`TBD`/`FIXME` markers.

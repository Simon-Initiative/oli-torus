# PRD Checklist

Use this checklist before saving `prd.md`:

- Keep required headings from `assets/templates/prd_template.md`.
- Ensure sections are in the exact template order and all headings are present.
- Ensure section 6 contains exactly `Requirements are found in requirements.yml`.
- Ensure section 7 contains exactly `Requirements are found in requirements.yml`.
- Ensure no `FR-###` or `AC-###` requirement entries appear in `prd.md`.
- Ensure `<feature_dir>/requirements.yml` exists and passes structure validation.
- Make scope boundaries explicit (goals vs non-goals).
- Include role/permission expectations.
- For section 11: if the informal description requires feature flags, include rollout and rollback notes; otherwise include exactly `No feature flags present in this feature`.
- If section 11 has `No feature flags present in this feature`, ensure there are no canary/phased rollout or rollout runbook requirements anywhere in the PRD.
- Include Torus-specific constraints where relevant: tenancy, LTI roles, accessibility, observability, security/privacy.
- Include measurable non-functional budgets when relevant.
- Include data model/API contract impacts and permissions matrix entries.
- Include QA coverage across automated and manual checks.
- Ensure manual QA calls out focus areas for risky or hard-to-automate behavior.
- Ensure QA includes an `Oli.Scenarios Recommendation` (`Required`/`Suggested`/`Not applicable`) with rationale.
- Ensure the `Oli.Scenarios Recommendation` states whether related subsystem areas already have YAML-driven scenario coverage and uses that as decision signal.
- Remove unresolved `TODO`/`TBD`/`FIXME` markers.

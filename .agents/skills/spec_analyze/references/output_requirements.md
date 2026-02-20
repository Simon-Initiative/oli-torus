# Output Requirements (PRD)

Produce only the PRD body in markdown with these headings in this exact order:

1. Overview
2. Background & Problem Statement
3. Goals & Non-Goals
4. Users & Use Cases
5. UX / UI Requirements
6. Functional Requirements
7. Acceptance Criteria (Testable)
8. Non-Functional Requirements
9. Data Model & APIs
10. Integrations & Platform Considerations
11. Feature Flagging, Rollout & Migration
12. Analytics & Success Metrics
13. Risks & Mitigations
14. Open Questions & Assumptions
15. Timeline & Milestones (Draft)
16. QA Plan
17. Definition of Done

## Section Requirements

- Functional Requirements:
  - Include exactly: `Requirements are found in requirements.yml`
- Acceptance Criteria:
  - Include exactly: `Requirements are found in requirements.yml`
  - Do not include `FR-###` or `AC-###` entries in `prd.md`; they belong in `requirements.yml`.
- Non-Functional Requirements:
  - Include concrete targets for performance, reliability, security/privacy, compliance, and observability.
- Data Model & APIs:
  - Include schema and migration impacts, context boundaries, interface/contracts, and permission matrix.
- Integrations & Platform:
  - Address LTI impacts, external services, caching/perf posture, multi-tenancy, and GenAI concerns when relevant.
- Feature Flagging, Rollout & Migration:
  - Include feature flag details only when informal input explicitly asks for flags/flag-driven rollout.
  - Otherwise include exactly: `No feature flags present in this feature`.
  - When no feature flags are present, do not include canary/phased rollout notes or rollout runbook requirements.
- QA Plan:
  - Include automated and manual validation strategy.
  - Include explicit manual-testing focus areas for risky or hard-to-automate behavior.
  - Include an `Oli.Scenarios Recommendation` with one of: `Required`, `Suggested`, or `Not applicable`.
  - For the `Oli.Scenarios Recommendation`, state whether related subsystem areas already have YAML-driven `Oli.Scenarios` coverage and use that as a strong signal for whether additional scenario coverage is needed.

## Generation Rules

- Be specific and testable; avoid vague statements.
- Infer plausible Torus-aligned details when missing, then capture them under assumptions.
- Keep FR/AC source-of-truth in `requirements.yml` only; avoid duplicating requirement IDs/content in `prd.md`.
- Do not leave unresolved placeholders (`TODO`, `TBD`, `FIXME`) in final content.
- If something is unknown, frame it as an Open Question and specify what decision/input is needed.
- Use plain markdown only (no HTML).

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
  - Use table format with `FR-###` IDs, priorities (`P0/P1/P2`), and owner.
- Acceptance Criteria:
  - Use `AC-### (FR-###)` and Given/When/Then statements.
  - Ensure criteria are directly testable/automatable when possible.
- Non-Functional Requirements:
  - Include concrete targets for performance, reliability, security/privacy, compliance, and observability.
- Data Model & APIs:
  - Include schema and migration impacts, context boundaries, interface/contracts, and permission matrix.
- Integrations & Platform:
  - Address LTI impacts, external services, caching/perf posture, multi-tenancy, and GenAI concerns when relevant.
- Feature Flagging, Rollout & Migration:
  - Include feature flag details only when informal input explicitly asks for flags/flag-driven rollout.
  - Otherwise include exactly: `No feature flags present in this feature`.
- QA Plan:
  - Include automated and manual validation strategy.
  - Include performance verification approach for NFR confidence.

## Generation Rules

- Be specific and testable; avoid vague statements.
- Infer plausible Torus-aligned details when missing, then capture them under assumptions.
- Do not leave unresolved placeholders (`TODO`, `TBD`, `FIXME`) in final content.
- If something is unknown, frame it as an Open Question and specify what decision/input is needed.
- Use plain markdown only (no HTML).

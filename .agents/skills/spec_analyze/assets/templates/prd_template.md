# <Feature Name> — PRD

## 1. Overview
Feature Name: <name>

Summary: <2-3 sentence summary describing user value and primary capability>

Links: <related docs/issues or `None`>

## 2. Background & Problem Statement
- Current behavior / limitations:
  - <details>
- Affected users/roles:
  - <authors/instructors/students/admins>
- Why now:
  - <trigger/dependency/business value>

## 3. Goals & Non-Goals
- Goals:
  - <goal>
- Non-Goals:
  - <non-goal>

## 4. Users & Use Cases
- Primary Users / Roles:
  - <role and Torus/LTI context>
- Use Cases:
  - <scenario narrative(s)>

## 5. UX / UI Requirements
- Key Screens/States:
  - <screen>
- Navigation & Entry Points:
  - <entry>
- Accessibility:
  - <WCAG and keyboard/screen reader requirements>
- Internationalization:
  - <gettext/RTL requirements or `N/A`>
- Screenshots/Mocks:
  - <links or `None`>

## 6. Functional Requirements
| ID | Description | Priority | Owner |
|---|---|---|---|
| FR-001 | <requirement> | P0 | <owner> |

## 7. Acceptance Criteria
- AC-001 (FR-001) — Given <context>, when <action>, then <observable result>.

## 8. Non-Functional Requirements
- Performance & Scale: <latency p50/p95, throughput/concurrency, LiveView responsiveness>
- Reliability: <error budgets, timeout/retry expectations, graceful degradation>
- Security & Privacy: <authn/authz, PII handling, abuse controls>
- Compliance: <accessibility, retention, audit logging requirements>
- Observability: <telemetry events, metrics, logs, traces, AppSignal dashboard/alert impact>

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - <changes or `None`>
- Context Boundaries:
  - <contexts/modules>
- APIs / Contracts:
  - <interfaces>
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| <role> | <actions> | <notes> |

## 10. Integrations & Platform Considerations
- LTI 1.3: <impact>
- GenAI (if applicable): <routing/fallback/rate limit/cost/redaction implications>
- External services: <impact and contract notes>
- Caching/Perf: <impact>
- Multi-tenancy: <impact>

## 11. Feature Flagging, Rollout & Migration
- <If informal description explicitly requires feature flags or flag-driven rollout, document strategy/rollout/rollback here. Otherwise include exactly: No feature flags present in this feature>

## 12. Analytics & Success Metrics
- KPIs:
  - <metric>
- Events:
  - <event spec>

## 13. Risks & Mitigations
- <risk> -> <mitigation>

## 14. Open Questions & Assumptions
- Assumptions:
  - <assumption>
- Open Questions:
  - <question>

## 15. Timeline & Milestones (Draft)
- <milestone>

## 16. QA Plan
- Automated:
  - <unit/property/liveview/integration/migration tests as applicable>
- Manual:
  - <exploratory/regression/accessibility checks>
- Performance Verification:
  - <how NFR performance targets will be verified>

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)

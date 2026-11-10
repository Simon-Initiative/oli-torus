# Thompson Sampling MVP Adaptive Policy - Product Requirements Document

## 1. Overview
Implement the MVP adaptive assignment policy for native A/B testing using non-contextual Thompson Sampling with a Beta-Bernoulli binary reward model. The policy must integrate with native assignment, reward feedback, current runtime policy state, xAPI policy-update evidence, monitoring, and authoring lifecycle paths while preserving sticky assignment behavior.

## 2. Background & Problem Statement
Native A/B testing must do more than replace simple random assignment; MVP scope includes adaptive assignment through Thompson Sampling. The weighted random authoring lifecycle slice intentionally leaves Thompson Sampling absent or disabled as "Coming soon". This slice must implement the adaptive policy and replace that deferred authoring affordance with selectable, lifecycle-safe Thompson Sampling controls. The implementation needs current policy state for runtime decisions, xAPI/ClickHouse-backed audit evidence for reward and policy-update history, deterministic boundaries for assignment/reward behavior, and guardrails that let Torus operate adaptive experiments safely.

## 3. Goals & Non-Goals
### Goals
- Implement non-contextual Thompson Sampling for A/B/N alternatives experiments.
- Use Beta-Bernoulli posterior state with configurable or default Beta(1,1) priors.
- Update current posterior state from idempotent binary reward events for the assigned condition only.
- Emit reward and policy-update telemetry for durable analytics and research audit history.
- Preserve sticky assignment even as policy state changes.
- Enable authors or permitted administrators to select Thompson Sampling in the A/B Testing authoring surface with MVP-safe defaults and guardrails.
- Update lifecycle validation so adaptive experiments can be activated only when reward readiness, priors, guardrails, and condition mappings are valid.
- Expose enough current policy metadata and ClickHouse-backed event history for research review and operations.

### Non-Goals
- Implement contextual bandits, continuous rewards, score-delta optimization, or multi-objective rewards.
- Implement additional UpGrade or Mooclet adaptive variants.
- Build full adaptive tuning UI beyond required MVP authoring controls and guardrails.

## 4. Users & Use Cases
- Learning engineers and researchers: run adaptive alternatives experiments using binary success/failure outcomes.
- Authors or administrators: select or enable Thompson Sampling where product requirements allow it.
- Operators: inspect current posterior state, ClickHouse-backed reward/update evidence, and guardrail-triggered pauses.
- Students: receive a stable assigned condition without seeing adaptive machinery.

## 5. UX / UI Requirements
- Any authoring/admin controls must make Thompson Sampling selection, required defaults, and guardrail state understandable without exposing implementation internals.
- The A/B Testing authoring surface must replace any disabled "Coming soon" Thompson Sampling affordance from the authoring lifecycle slice with an enabled option only after backend policy validation is available.
- Authoring validation errors must explain invalid priors, guardrails, reward readiness, and activation blockers without exposing learner identities or raw response data.
- Student delivery UI must remain unchanged except for the assigned alternative content.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Posterior updates must be idempotent and scoped to the assigned condition.
- Current policy state needed for assignment may be persisted in PostgreSQL, while reward and policy-update history needed for analytics or research audit must be represented in xAPI/ClickHouse.
- Assignment selection must be performant enough for delivery-time use or safely isolated behind existing background/runtime patterns.
- Random sampling behavior must be testable through deterministic seams or statistical assertions appropriate to the code path.

## 9. Data, Interfaces & Dependencies
- Depends on the assignment algorithm boundary and policy-state contracts from `domain_contract`.
- Depends on delivery runtime reward handoff and experiment telemetry from `delivery_runtime`.
- Depends on weighted random authoring lifecycle, assignment-aware edit rules, and disabled Thompson Sampling affordance from `authoring_lifecycle`.
- Uses current policy state fields for per-condition alpha/beta values, priors, algorithm name/version, and runtime reward counters.
- Emits policy-update telemetry containing enough provenance for ClickHouse-backed reporting and dataset exports.

## 10. Repository & Platform Considerations
- Backend Elixir domain code should own policy selection and posterior updates.
- Existing LiveView authoring surfaces should own adaptive form rendering and lifecycle actions while delegating validation to `Oli.Experiments`.
- Scenario or ExUnit coverage should validate end-to-end reward-to-policy behavior.
- Telemetry should support monitoring missing rewards, assignment imbalance, posterior updates, guardrail pauses, xAPI emission failures, and ClickHouse evidence gaps.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Track current reward counts, posterior updates, assignment share over time, missing or delayed rewards, xAPI/ClickHouse policy-update evidence, and guardrail state.
- Success is measured by correct posterior updates, sticky assignment preservation, and visible operational evidence for adaptive behavior.

## 13. Risks & Mitigations
- Risk: Incorrect reward mapping biases policy state. Mitigation: require explicit binary reward semantics and idempotent reward proof.
- Risk: Adaptive policy over-allocates too early. Mitigation: include MVP guardrails such as warm-up, caps, pause, or imbalance monitoring where required.
- Risk: Policy behavior is hard to audit. Mitigation: persist current algorithm version and prior configuration for runtime behavior, and emit policy-update provenance to xAPI/ClickHouse for durable audit history.
- Risk: Authoring controls enable adaptive experiments before backend policy behavior is safe. Mitigation: make authoring enablement part of this slice and gate activation on policy, reward, and guardrail validation.

## 14. Open Questions & Assumptions
### Open Questions
- Which binary reward signal should drive MVP Thompson Sampling?
- Which guardrails are required before production use?
- Which Thompson Sampling controls are author-facing versus admin-only defaults?
- Which policy-update fields must be emitted to xAPI so ClickHouse reports can reconstruct assignment share, reward counts, and posterior history?

### Assumptions
- MVP Thompson Sampling runs inside the native A/B testing domain.
- Rewards are binary and associated with evaluated learner attempts.
- Weighted random authoring lifecycle exists first and leaves Thompson Sampling unavailable or disabled until this slice enables it.

## 15. QA Plan
- Automated validation:
  - ExUnit tests for posterior sampling, reward updates, idempotent processing, sticky assignment, delayed rewards, and fallback to weighted random when disabled.
  - LiveView/context tests for selecting Thompson Sampling, validating priors and guardrails, and activating adaptive experiments only when all prerequisites pass.
  - Integration tests for reward event flow from delivery runtime into current policy state and xAPI policy-update telemetry.
- Manual validation:
  - Create and activate a Thompson Sampling experiment through the A/B Testing authoring surface, then inspect analytics or monitoring evidence showing current posterior state plus ClickHouse-backed reward/update evidence after controlled student attempts.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes

## 17. Decision Log
### 2026-06-30 - Own Adaptive Authoring Enablement
- Change: Added authoring enablement, lifecycle validation, and UI replacement scope for Thompson Sampling.
- Reason: The parent epic now places Thompson Sampling after weighted random authoring lifecycle, which leaves adaptive controls disabled or absent.
- Evidence: `docs/exec-plans/current/epics/ab_testing/plan.md`; `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle/prd.md`.
- Impact: This work item must turn the deferred authoring affordance into selectable adaptive configuration and validate activation prerequisites.

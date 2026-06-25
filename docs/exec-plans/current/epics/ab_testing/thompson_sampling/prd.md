# Thompson Sampling MVP Adaptive Policy - Product Requirements Document

## 1. Overview
Implement the MVP adaptive assignment policy for native A/B testing using non-contextual Thompson Sampling with a Beta-Bernoulli binary reward model. The policy must integrate with native assignment, reward, policy-state, and monitoring paths while preserving sticky assignment behavior.

## 2. Background & Problem Statement
Native A/B testing must do more than replace simple random assignment; MVP scope includes adaptive assignment through Thompson Sampling. The implementation needs auditable policy state, deterministic boundaries for assignment/reward behavior, and guardrails that let Torus operate adaptive experiments safely.

## 3. Goals & Non-Goals
### Goals
- Implement non-contextual Thompson Sampling for A/B/N alternatives experiments.
- Use Beta-Bernoulli posterior state with configurable or default Beta(1,1) priors.
- Update posterior state from idempotent binary reward events for the assigned condition only.
- Preserve sticky assignment even as policy state changes.
- Expose enough policy metadata for research review and operations.

### Non-Goals
- Implement contextual bandits, continuous rewards, score-delta optimization, or multi-objective rewards.
- Implement additional UpGrade or Mooclet adaptive variants.
- Build full adaptive tuning UI beyond required MVP controls and guardrails.

## 4. Users & Use Cases
- Learning engineers and researchers: run adaptive alternatives experiments using binary success/failure outcomes.
- Authors or administrators: select or enable Thompson Sampling where product requirements allow it.
- Operators: inspect posterior state, reward counts, and guardrail-triggered pauses.
- Students: receive a stable assigned condition without seeing adaptive machinery.

## 5. UX / UI Requirements
- Any authoring/admin controls must make Thompson Sampling selection, required defaults, and guardrail state understandable without exposing implementation internals.
- Student delivery UI must remain unchanged except for the assigned alternative content.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Posterior updates must be idempotent, auditable, and scoped to the assigned condition.
- Assignment selection must be performant enough for delivery-time use or safely isolated behind existing background/runtime patterns.
- Random sampling behavior must be testable through deterministic seams or statistical assertions appropriate to the code path.

## 9. Data, Interfaces & Dependencies
- Depends on the assignment algorithm boundary and policy-state contracts from `domain_contract`.
- Depends on delivery runtime reward handoff and exposure/outcome records from `delivery_runtime`.
- Uses policy state fields for per-condition alpha/beta values, priors, algorithm name/version, update provenance, and reward counts.

## 10. Repository & Platform Considerations
- Backend Elixir domain code should own policy selection and posterior updates.
- Scenario or ExUnit coverage should validate end-to-end reward-to-policy behavior.
- Telemetry should support monitoring missing rewards, assignment imbalance, posterior updates, and guardrail pauses.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Track reward counts, posterior updates, assignment share over time, missing or delayed rewards, and guardrail state.
- Success is measured by correct posterior updates, sticky assignment preservation, and visible operational evidence for adaptive behavior.

## 13. Risks & Mitigations
- Risk: Incorrect reward mapping biases policy state. Mitigation: require explicit binary reward semantics and idempotent reward proof.
- Risk: Adaptive policy over-allocates too early. Mitigation: include MVP guardrails such as warm-up, caps, pause, or imbalance monitoring where required.
- Risk: Policy behavior is hard to audit. Mitigation: persist algorithm version, prior configuration, and update provenance.

## 14. Open Questions & Assumptions
### Open Questions
- Which binary reward signal should drive MVP Thompson Sampling?
- Which guardrails are required before production use?

### Assumptions
- MVP Thompson Sampling runs inside the native A/B testing domain.
- Rewards are binary and associated with evaluated learner attempts.

## 15. QA Plan
- Automated validation:
  - ExUnit tests for posterior sampling, reward updates, idempotent processing, sticky assignment, delayed rewards, and fallback to weighted random when disabled.
  - Integration tests for reward event flow from delivery runtime into policy state.
- Manual validation:
  - Inspect analytics or monitoring evidence showing reward counts and posterior state changes after controlled student attempts.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes

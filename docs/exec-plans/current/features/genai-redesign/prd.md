# GenAI Provider Health and Routing Redesign - Product Requirements Document

## 1. Overview
Restore reliable GenAI routing with independently monitored Providers and isolated, node-local transport capacity for each ServiceConfig tier. Learners and instructors should receive useful responses during normal load and eligible provider outages, while administrators can understand and manage health and capacity.

## 2. Background & Problem Statement
Current per-model breakers treat long successful streams as failures, can fail to recover without traffic, and mix availability with capacity controls. Shared transport pools can couple primary, secondary, and backup traffic. Cancellation can leak application admission counters. The investigation in `docs/exec-plans/current/features/genai-redesign/informal.md` describes these findings and the proposed design.

## 3. Goals & Non-Goals
### Goals
- Detect and recover from broad Provider outages independently of user traffic.
- Route using each tier's actual pool occupancy, with bounded waiting and isolated backup and probe capacity.
- Give administrators usable configuration, health, and diagnostic information.
- Preserve safe streaming, cancellation, and credential handling through migration.

### Non-Goals
- Global upstream request or token quota enforcement, capacity borrowing between ServiceConfigs, or perfect fairness.
- Atomic reservations, separate application admission accounting, or a guarantee of zero queueing.
- Inferring Provider health from normal request outcomes or accelerating probes from those failures.
- Enforcing a different-vendor backup or resolving detailed provider-specific error classifications in this work item; distinct Provider records remain required.
- Claude/Anthropic transport isolation, adapter corrections and runtime verification are deferred; its current implementation remains unchanged and has no pool-only guarantee. Evaluating Anthropic's OpenAI-compatible endpoint is future work.

## 4. Users & Use Cases
- Learners and instructors: receive inference through the preferred model, an eligible secondary, or backup when appropriate, with bounded busy responses under saturation.
- Administrators: configure Providers, models, health checks, and tier pools; diagnose unavailable Providers and exercise configurations safely.
- Operators: monitor per-node health, capacity, checkout delays, and stream failures during deployment and recovery.

## 5. UX / UI Requirements
- Authorized administrators can manage Provider connection settings, tier pool capacity, and the RegisteredModel health-check flag using existing administrative patterns and accessible controls.
- Show administrative and observed health separately, the selected probe model, probe schedule and outcomes, and safe error categories; distinguish disabled, unknown, stale, and missing configuration states.
- Label Hackney capacity as “Maximum checked-out connections” or “Pool capacity”; describe adapter-specific semantics accurately. Never expose credentials or raw sensitive errors.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Pool checkout waits must be finite and separate from connection, inactivity, and total inference deadlines; the timeout value is an implementation decision.
- Preserve cleanup on completion, cancellation, errors, and process death. Pool-only routing depends on verifying installed transport limits, occupancy, resizing, checkout cancellation, and streaming ownership.
- Encrypt credentials, restrict administrative operations using existing authorization, and exclude secrets, prompts, and raw provider payloads from logs and telemetry.
- Monitoring and limits are per node; account for probe load and aggregate provider quotas when sizing deployments. No numeric throughput or latency target is specified.

## 9. Data, Interfaces & Dependencies
- A Provider represents endpoint, credentials, adapter, and observed availability; RegisteredModels reference it and retain model-specific inference settings.
- ServiceConfigs select primary, secondary, and backup; each configured `(service_config_id, tier)` has one persisted pool capacity per node. Existing feature resolution and section overrides remain in effect.
- The OpenAI-compatible adapter uses Hackney; verify its installed-version transport semantics before adopting pool-only capacity management. Claude uses Anthropix/Req/Finch and is explicitly deferred, with its isolation limitation documented.
- Stream completion and errors must be represented reliably by adapters for both requests and synthetic probes.

## 10. Repository & Platform Considerations
- Implement within the existing Elixir/Phoenix GenAI contexts, administrative interfaces, Ecto persistence, and per-node runtime. Follow generated migration and explicit rollback policies in `AGENTS.md`.
- Use repository testing and review policies, including security, performance, and requirements review. Track implementation through the normal Jira workflow; no issue identifier was supplied.

## 11. Feature Flagging, Rollout & Migration
- Use `GENAI_HEALTH_CHECKS_ENABLED` as the specified node-level health-check override, not as a capacity bypass. Remove the current primary-only override.
- Initially migrate exactly one Provider named "OpenAI production", copy credentials from the lowest-ID RegisteredModel with API keys, and associate all existing RegisteredModels with it. Administrators can subsequently create Providers and reassign models.
- Audit ServiceConfigs and pool sizing before rollout; observe probes before enabling health-based diversion, verify transport behavior, and define rollback and obsolete-state handling. Use deployment controls as needed; no additional scoped flag is specified.

## 12. Telemetry & Success Metrics
- Report probe results, scheduling and health changes; routing decisions, busy and unavailable rejections; and backup attempts.
- Report checked-out occupancy and configured capacity by ServiceConfig tier, checkout wait and timeout, queue depth where available, and connection cleanup and pool lifecycle failures.
- Track request outcomes, time to first token, stalls, duration, cancellations, and interrupted streams without treating them as health evidence. Success is evidenced by reliable independent recovery, bounded contention, and reclaimed pool capacity; no numerical target is established.

## 13. Risks & Mitigations
- Transport behavior may not support the design: verify the installed Hackney and each actual adapter, and resolve or explicitly document unsupported semantics before rollout.
- Synthetic probes may miss model-specific failures or create per-node load: retain request telemetry, bound and jitter probes, and account for node count.
- Model or endpoint changes and capacity reductions can strand active work: define safe pool retirement, resizing, and cleanup, and test them under load.
- Initial single-Provider migration may invalidate existing backup configurations: audit configurations and stage administrative reassignment before enabling routing.

## 14. Open Questions & Assumptions
### Open Questions
- Implemented defaults: 1,000 ms checkout, 300,000 ms inference total across both attempts; connection failures, pre-output inactivity and HTTP 500/502/503/504 permit one backup. Stale health is locally ineligible after two regular intervals plus probe deadline.
- Claude transport remains deferred. Verified OpenAI uses isolated transport, administrative capacity four per Provider/origin/node and immediate pool generation replacement with accepted overlap. A future Claude transport decision is outside this work item.
- Transactional designation, committed invalidations and periodic node reconciliation are implemented. `docs/OPERATIONS.md` defines ingress-excluded observation, mixed-version write freeze, audit, canary cutover and explicit rollback preparation.
- Which Provider identity fields are necessary? Different-vendor enforcement and detailed invalid-credential, probe-configuration, and model-throttling classification are deferred in the source.

### Assumptions
- Structurally valid unknown health is initially eligible while an immediate independent probe runs. Stale or invalid configuration does not fabricate a synthetic outage.
- Capacity checks are deliberately non-atomic; short bounded queueing, occasional secondary selection, and transient busy results are acceptable.
- One HTTP/1.1 inference occupies a checked-out connection for the complete stream only if verified. Multiplexed transports require equivalent stream/request capacity or explicitly documented different semantics.

## 15. QA Plan
- Automated validation:
  - Exercise probe selection, thresholds, independent recovery, disabled checks, stale results, configuration changes, and administrative validation.
  - Test pool selection races, bounded checkout, contention classification, isolation, resizing, process death and cleanup against each real transport, including installed Hackney behavior.
  - Cover streaming errors and truncation, guarded backup retry, migration and rollback, credential safety, and per-node propagation.
- Manual validation:
  - Inspect administrative health and model views, safe diagnostics, pool labels, and configuration behavior; observe a staged outage and recovery with production-like streaming.

## 16. Definition of Done
- [x] PRD sections complete
- [x] requirements.yml captured and valid
- [x] PRD validation passes
- [x] Implementation, installed-transport verification, migration/rollback, targeted automated checks, rendered-state/accessibility inspection and required reviews complete within the explicit Claude deferral. Execution records retain full-suite limitations and deployment/browser checks that remain operator gates.

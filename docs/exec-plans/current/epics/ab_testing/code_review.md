# PR 6725 Code Review Triage

## Purpose

This document triages all review feedback currently attached to PR 6725, **Native AB test experiments support**, against:

- MER-5795 and the A/B testing epic scope;
- the PR description and declared non-goals;
- the current `ab-testing` branch rather than the original commented lines;
- `.review/security.md`, `.review/performance.md`, `.review/elixir.md`, `.review/ui.md`, and `.review/requirements.md`.

This is a disposition document only. It does not approve or implement the fixes. PR replies and thread resolution should happen after the selected fixes are implemented and verified.

## Summary

The PR contains 17 review issues plus one informational security review with no finding.

| Disposition | Count | Items |
| --- | ---: | --- |
| Fix | 11 | 4.1–4.5 and 4.7–4.12 |
| Do not fix in this PR; defer with explanation | 1 | 4.6 |
| Already addressed | 3 | 3.1, 3.2, 3.3 |
| No code change | 2 | 5.1, 5.2 |

Items 4.2 and 4.3 describe the same reward-processing bottleneck at different call sites. They should be resolved by one asynchronous, batched, idempotent design rather than by two independent mechanisms. Both remain individually counted review issues because they cover different callers and verification cases.

The highest-priority fixes are:

1. Make attribution hashes identical across direct upload, Lambda ETL, and backfill.
2. Move reward handoff work out of learner-facing evaluation and batch page-finalization rewards.
3. Correct `tcp://` ClickHouse host handling.
4. Add error handling to decision-point selection.
5. Correct the three accessibility findings.

## Implementation Checklist

- [x] 4.1 Handle failures while loading a selected decision point.
- [x] 4.2 Move reward handoff out of synchronous activity evaluation.
- [x] 4.3 Batch reward processing during page grading.
- [x] 4.4 Transform direct-uploader events only once.
- [x] 4.5 Insert direct-uploader attributions in bounded chunks.
- [x] 4.7 Filter reward assignments by relevant attempts in PostgreSQL.
- [x] 4.8 Use one deterministic attribution hash across all ingestion paths.
- [ ] 4.9 Normalize `tcp://` ClickHouse hosts when building HTTP URLs.
- [ ] 4.10 Make alternatives option reordering keyboard accessible.
- [ ] 4.11 Make disabled pagination controls non-actionable.
- [ ] 4.12 Use button semantics for the suggested-slug action.

## 1. Review Inventory

| Source | Type | Issues | Notes |
| --- | --- | ---: | --- |
| Darren Siegel | Human review | 3 | All threads are resolved; current code reflects the requested publication and cardinality corrections. |
| GitHub AI TypeScript review | AI bot | 1 | Actionable correctness/resilience issue. |
| GitHub AI performance review | AI bot | 6 | Five are actionable; one should be deferred pending profiling and a cache-consistency design. |
| GitHub AI Elixir review | AI bot | 2 | Both are actionable correctness issues. |
| GitHub AI UI review | AI bot | 3 | All are actionable accessibility/semantic issues. |
| GitGuardian | Security bot | 1 | False positive for a local-only development credential; scanner incident still needs acknowledgment. |
| Danger | Tooling bot | 1 | Informational large-PR warning; splitting now would increase integration risk. |
| GitHub AI security review | AI bot | 0 | “No issues found”; no action required. |

## 2. Decision Principles

- Correctness, security, accessibility, and bounded learner-facing latency are in scope for this PR.
- The MVP explicitly requires idempotent reward processing and prohibits synchronous S3 or ClickHouse work in learner-facing delivery. It does not require reward processing itself to remain synchronous.
- A fix must preserve the existing requirement that evaluated attempts produce outcome/reward evidence and that replay cannot update Thompson Sampling state twice.
- Performance suggestions are not accepted solely because they are plausible. They must identify a real unbounded path or remove repeated work without weakening correctness.
- Historical revision IDs remain valid evidence. Current authoring and delivery revisions must be resolved through the publication model.
- Accessibility findings follow `.review/ui.md`: actions use button semantics, disabled controls are not actionable, and reordering must be keyboard operable.

## 3. Human Review Threads

### 3.1 Experiment-to-section cardinality

- **Original comment:** The original schema appeared to allow an experiment to apply to only one section.
- **Location at review time:** `lib/oli/experiments/schemas/experiment_definition.ex`.
- **Determination:** Already addressed; do not make another change.
- **Evidence:** Experiment participation is now represented as a many-to-many relationship through experiment-section records, matching MER-5795’s requirement that an experiment select zero or more eligible sections. The original line is outdated and the thread is resolved.
- **PR action:** No code change. Keep the resolved thread closed.

### 3.2 Pinned decision-point revision

- **Original comment:** Why does a decision point pin a specific revision?
- **Location at review time:** `lib/oli/experiments/schemas/decision_point.ex`.
- **Determination:** Already addressed; do not make another change.
- **Evidence:** The exact revision pin was removed as the current content authority. Delivery and authoring now resolve revisions through the publication model while exact revision IDs remain appropriate on historical evidence such as exposures. The original line is outdated and the thread is resolved.
- **PR action:** No code change. Keep the resolved thread closed.

### 3.3 Publication-model bypass and inconsistent revision semantics

- **Original comment:** Experiment authoring discovery, validation, activation, runtime matching, and exposure validation mixed working, deployed, and historical revision meanings and bypassed resolvers.
- **Location at review time:** `lib/oli/experiments.ex` and related runtime paths.
- **Determination:** Already addressed; do not make another change solely for this thread.
- **Evidence:** The current implementation resolves authoring and delivery content through the publication model. For example, media attribution resolution uses `Oli.Publishing.DeliveryResolver`, and the experiment-section model no longer relies on a pinned current revision. The reviewer accepted the follow-up and the thread is resolved.
- **Residual caution:** Any future fix in reward or media attribution code must preserve the distinction between resolved current content and immutable historical evidence.
- **PR action:** No code change. Keep the resolved thread closed.

## 4. Actionable Automated Review Findings

### 4.1 Unhandled failure while loading a selected decision point

- **Source:** GitHub AI TypeScript review.
- **Current location:** `assets/src/components/content/add_resource_content/NonActivities.tsx`, `onDone` for the A/B decision-point selection modal.
- **Issue:** `Persistence.alternatives(projectSlug)` is called with `.then(...)` but without a rejection handler. A network or parsing failure produces an unhandled rejection and leaves the modal open. A successful response that does not contain the selected experiment also silently dismisses the modal.
- **Determination:** Fix.
- **Why:** This is a concrete user-visible reliability defect introduced in the PR. `.review/ui.md` requires explicit error states and graceful network failure behavior.
- **Proposed resolution:** Make `onDone` asynchronous, handle rejected and unsuccessful results, surface an actionable error through the existing notification/error mechanism, and deliberately decide modal dismissal behavior. Prefer keeping the modal open on recoverable failure so the author can retry; dismiss only after success or explicit cancellation. Add a focused test for rejection/unsuccessful response behavior.

### 4.2 Reward handoff blocks activity evaluation

- **Source:** GitHub AI performance review.
- **Current location:** `lib/oli/delivery/attempts/activity_lifecycle/apply_client_evaluation.ex`; the handoff calls `RewardHandoff.record_evaluated_activity/1` synchronously after updating the attempt.
- **Issue:** The handoff performs context reads plus outcome, reward, and policy-state writes before learner-facing evaluation returns.
- **Determination:** Fix together with 4.3.
- **Why:** The claim is confirmed by the current code. `.review/performance.md` requires expensive database work to leave latency-sensitive paths. MER-5795 requires correctness and idempotency but does not require the policy update to finish before the evaluation response.
- **Proposed resolution:** Enqueue one idempotent Oban reward-processing job after the evaluation transaction commits. Use a unique key based on activity-attempt ID (or a deterministic batch identity), make retries safe through the existing reward idempotency keys, and emit telemetry for enqueue, success, retry, and terminal failure. Do not enqueue inside a transaction in a way that permits a job to observe uncommitted or rolled-back data. Add tests covering retry idempotency and commit ordering.

### 4.3 Page grading processes rewards serially per attempt

- **Source:** GitHub AI performance review.
- **Current location:** `lib/oli/delivery/attempts/page_lifecycle/graded.ex`; IDs are extracted with `Enum.take_every(6)` and synchronously processed with `Enum.each/2`.
- **Issue:** Page finalization repeats the full reward context read/write path once per activity attempt, so latency grows with the number of activities.
- **Determination:** Fix as part of the 4.2 design, not as a separate worker per attempt.
- **Why:** The current loop is a confirmed query-in-loop pattern prohibited by `.review/performance.md`. Creating one independent job for every attempt would remove request latency but retain avoidable database amplification.
- **Proposed resolution:** Enqueue a single batch job for the evaluated activity-attempt IDs. Add a batch-aware handoff API that loads common section/resource context and eligible assignments with set-based queries, then applies the existing deterministic outcome/reward keys. Preserve per-attempt isolation so one malformed attempt does not lose the remainder of the batch. Replace the positional `Enum.take_every(6)` coupling with an explicit result shape if the surrounding rollup contract can be changed safely.

### 4.4 Direct uploader transforms each event twice

- **Source:** GitHub AI performance review.
- **Current location:** `lib/oli/analytics/xapi/clickhouse_uploader.ex`; `parse_and_insert_events/3` builds raw rows, then `transform_experiment_attributions/1` calls `transform_to_raw_event/1` again to recover `host_event_type`.
- **Issue:** Event classification, extension extraction, timestamp parsing, and hashing are repeated for attributed events.
- **Determination:** Fix.
- **Why:** The duplicate transformation is confirmed and is easy to remove without changing behavior.
- **Proposed resolution:** Transform each parsed event once into a small intermediate structure containing the raw line, parsed statement, hash, host event type, and optional raw row. Build both table projections from that structure. Add/retain parity tests for raw rows and attribution rows.

### 4.5 Direct uploader assembles one unbounded attribution insert

- **Source:** GitHub AI performance review.
- **Current location:** `lib/oli/analytics/xapi/clickhouse_uploader.ex`; all attribution value tuples are mapped, joined, and concatenated into one SQL binary.
- **Issue:** Peak memory includes the attribution maps, a full values list, joined values, and final SQL statement. The path has no local bound on attribution count.
- **Determination:** Fix.
- **Why:** The implementation is demonstrably unbounded at this boundary, and the performance guide requires bounded memory for large ingestion sets.
- **Proposed resolution:** Insert attribution rows in a configured bounded chunk size, retaining all-or-error reporting at the bundle level. Prefer the same chunking convention used by existing ClickHouse ingestion code; consider a streaming row format only if it is already supported by the project’s HTTP client. Add a test proving multiple chunks preserve row counts and propagate a failed chunk.

### 4.6 Media attribution adds synchronous query and resolver work

- **Source:** GitHub AI performance review.
- **Current location:** `lib/oli/delivery/experiments/media_attributions.ex`.
- **Issue:** A media event within an alternatives branch queries the learner’s assignments, filters them in Elixir, and resolves the relevant revisions before constructing its xAPI host statement.
- **Determination:** Do not fix in this PR; document and defer pending measurement and a cache-consistency design.
- **Why not now:** The work only runs when the media element is inside a matching alternatives branch; revision resolution is already batched by resource ID and uses the required delivery resolver. Moving enrichment after xAPI construction would lose the requirement that the media host statement carry its attribution. A new cache would need invalidation across lifecycle, participation, assignment, publication deployment, and condition changes. Implementing that speculatively in this already-large PR has more correctness risk than the unmeasured latency it may remove.
- **Follow-up:** Add latency/query-count telemetry around `for_media_event/3`, measure on the deployed prototype, and open a follow-up only if the path is material. A follow-up design should prefer request/page-scoped reuse of already-resolved assignment data before adding a cross-request cache.
- **PR action:** Reply with the measured-design rationale; do not silently ignore the comment.

### 4.7 Reward assignments are filtered after loading history

- **Source:** GitHub AI performance review.
- **Current location:** `lib/oli/delivery/experiments/attempt_attributions.ex`; the query selects assignments having a `rewards` object, then `Enum.filter/2` checks activity-attempt-specific reward keys.
- **Issue:** Runtime and memory scale with all reward-bearing assignments for the learner rather than with the supplied attempt IDs.
- **Determination:** Fix.
- **Why:** This is an unbounded historical scan on an xAPI construction path. It also conflicts with the review rule to filter in the database and return only required rows.
- **Proposed resolution:** Push the attempt-specific key match into PostgreSQL using a parameterized JSONB predicate or a set-based lateral expansion joined against the requested attempt IDs. Avoid dynamically interpolated SQL. Select only fields needed to construct attribution payloads. Add tests for multiple assignments, unrelated historical rewards, and an empty attempt-ID set; inspect the query plan before choosing the final JSONB form.

### 4.8 Attribution hashes differ across ingestion paths

- **Source:** GitHub AI Elixir review.
- **Current locations:** `lib/oli/analytics/backfill/query_builder.ex`, `lib/oli/analytics/xapi/clickhouse_uploader.ex`, and `cloud/xapi-etl-processor/lambda_function.py`.
- **Issue:** The direct uploader and Lambda canonicalize attribution objects before hashing, while ClickHouse backfill hashes the raw JSON substring returned for the array element. Semantically equal objects with different key order or insignificant formatting can therefore receive different attribution hashes.
- **Determination:** Fix; release blocker for deterministic replay/backfill.
- **Why:** MER-5795 explicitly requires deterministic backfill/replay. Cross-path hash parity is part of that contract, not merely an optimization.
- **Proposed resolution:** Use the attribution's event-level idempotency key as the shared identity contract: `sha256(raw_event_hash <> ":" <> attribution_key)`. The key is already stable across host-role projections and can be reproduced directly by Elixir, Python, and ClickHouse SQL without depending on JSON object order or formatting. Add shared fixtures that assert identical hashes across all three paths.

### 4.9 `tcp://` ClickHouse hosts produce malformed HTTP URLs

- **Source:** GitHub AI Elixir review.
- **Current location:** `lib/oli/clickhouse/tasks.ex`; `clickhouse_host/1` accepts `tcp`, but `clickhouse_http_url/2` prefixes non-HTTP input with `http://`.
- **Issue:** A host such as `tcp://example:9000/database` becomes malformed as `http://tcp://...` before URI normalization.
- **Determination:** Fix.
- **Why:** This is a concrete configuration correctness bug. The module currently claims to accept TCP URLs in one helper while mishandling them in another.
- **Proposed resolution:** Parse the configured URI once and build the HTTP URL from its hostname, applying the configured HTTP port and stripping userinfo/path. Alternatively reject schemes in one central validator, but accepting `tcp://` is preferable because existing native endpoint tests/configuration already support it. Add focused HTTP URL tests for bare hosts, HTTP, HTTPS, TCP, IPv6 if supported, userinfo, and paths.

### 4.10 Alternatives option reordering is pointer-only

- **Source:** GitHub AI UI review.
- **Current location:** `lib/oli_web/live/resources/alternatives_editor/group_option.ex`.
- **Issue:** The option row is draggable but provides no keyboard operation for changing its position.
- **Determination:** Fix.
- **Why:** This is a direct keyboard-accessibility failure under `.review/ui.md`. The edit and delete actions being keyboard accessible does not make the reorder action accessible.
- **Proposed resolution:** Add labeled Move up and Move down buttons, disabling the impossible direction at the boundaries. Route them through the same validated reorder event/domain function as drag-and-drop. Announce the new position using an `aria-live` status region and return focus predictably. Add LiveView tests for first/middle/last items and persisted order.

### 4.11 Disabled pagination links remain actionable

- **Source:** GitHub AI UI review.
- **Current location:** `lib/oli_web/live/workspaces/course_author/experiment_details_live.ex`.
- **Issue:** Previous and Next always have a `patch`; `aria-disabled` and a CSS class do not remove focusability or prevent navigation. At the first page, the link can patch to page 0; at the last page it can patch beyond the page count.
- **Determination:** Fix.
- **Why:** This is both an accessibility defect and an invalid-navigation defect.
- **Proposed resolution:** Render a non-link disabled element at each boundary, or omit `patch`, add `tabindex="-1"`, and prevent activation. Prefer conditional rendering with native semantics over relying on ARIA. Add tests that boundary controls have no navigation target and interior controls patch correctly.

### 4.12 “Use suggested slug” uses link semantics for an action

- **Source:** GitHub AI UI review.
- **Current location:** `lib/oli_web/live/workspaces/course_author/experiments_live.ex`.
- **Issue:** An anchor with `href="#"` triggers a LiveView state change and can also change scroll position.
- **Determination:** Fix.
- **Why:** `.review/ui.md` requires buttons for actions and links for navigation. This is a small, low-risk semantic correction.
- **Proposed resolution:** Replace the anchor with `button type="button"`, retain the existing element ID and `phx-click`, and apply link-style classes. Ensure the existing suggested-slug tests target the button and add a semantic assertion.

## 5. Tooling and Security Findings

### 5.1 GitGuardian “Generic CLI Secret”

- **Source:** GitGuardian.
- **Current location:** `docs/exec-plans/current/epics/ab_testing/experiment_olap_foundation/manual_qa.md`; examples use the ClickHouse Docker development account `default:clickhouse` and `CLICKHOUSE_*_PASSWORD=clickhouse`.
- **Determination:** No repository code/document change required; mark as false positive after confirming the scanner occurrence is limited to this local example.
- **Why not fix:** The value is the intentionally public, local-only credential for the repository’s Dockerized ClickHouse development service, not a deployed secret. Replacing it with a placeholder would make the copy/paste local QA instructions inconsistent with the tracked development configuration. The security guidance prohibits real secrets, not documented disposable development defaults.
- **Required operational action:** In GitGuardian, classify the incident as a test/example or false positive with a note that it is restricted to localhost Docker development. Before closing it, inspect the linked occurrence and repository history to confirm no non-local credential shares the value. No history rewrite is justified for this value.

### 5.2 Danger large-PR warning

- **Source:** Danger.
- **Issue:** The PR is approximately 30,000 changed lines and has a high automated risk score.
- **Determination:** No code change and do not split the existing PR at this stage.
- **Why not fix:** The warning is valid risk information but not a discrete defect. The epic is deeply cross-cutting, the work is already integrated and reviewed as one branch, and retroactively splitting it would create stacked-branch and migration-order risk while making end-to-end verification harder.
- **Mitigation:** Resolve the concrete correctness/accessibility findings, keep fixes grouped and narrowly tested, preserve the deployment-order notes for migrations/ETL/application code, and use the epic’s execution records and requirements traceability as the review map.

## 6. Proposed Fix Groups

### Group A: Correctness and deterministic ingestion

- 4.1 selected-decision-point failure handling;
- 4.8 cross-path attribution hash parity;
- 4.9 TCP host normalization.

### Group B: Learner-facing reward performance

- 4.2 asynchronous post-commit reward handoff;
- 4.3 one batched page-finalization job and set-based context loading;
- 4.7 database-side filtering of reward attribution assignments.

These changes need one design pass because job payloads, transaction boundaries, idempotency keys, and xAPI timing interact.

### Group C: Direct uploader performance

- 4.4 single event transformation;
- 4.5 bounded attribution inserts.

### Group D: Accessibility and semantics

- 4.10 keyboard-accessible option ordering;
- 4.11 genuinely disabled pagination controls;
- 4.12 button semantics for suggested-slug action.

## 7. Deferred and Non-Code Responses

- 4.6: reply and defer media attribution caching until telemetry demonstrates a material problem and invalidation requirements are designed.
- 5.1: classify the GitGuardian incident after verifying it is only the local Docker credential.
- 5.2: acknowledge the PR size and point reviewers to the verification/traceability mitigations; do not split retroactively.
- 3.1–3.3: leave the already-resolved human threads closed.

## 8. Verification Expectations for the Fix Phase

- Run focused frontend tests for `NonActivities.tsx` failure behavior.
- Run focused LiveView tests for reorder keyboard controls, pagination boundaries, and suggested-slug semantics.
- Run reward handoff unit/scenario tests, including job retry, duplicate execution, failed attempt isolation, and Thompson Sampling posterior idempotency.
- Compare query counts for page finalization before and after batching.
- Assert identical attribution hashes from Elixir direct upload, Python Lambda ETL, and ClickHouse backfill fixtures.
- Test ClickHouse URL normalization for all supported schemes.
- Test attribution insertion across multiple chunks and a failed middle chunk.
- Run `mix format` on touched Elixir files and the narrowest relevant TypeScript formatter/checks.

## 9. Approval Gate

Before implementation, agree on:

1. whether the reward handoff uses one batch job API for both single-attempt and page-finalization callers;
2. the attribution-key hash contract shared by ClickHouse SQL, Elixir, and Python;
3. whether item 4.6 should receive telemetry in this PR or only a follow-up ticket;
4. the exact GitGuardian incident classification after inspecting the linked occurrence.

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
- [x] 4.9 Normalize `tcp://` ClickHouse hosts when building HTTP URLs.
- [x] 4.10 Make alternatives option reordering keyboard accessible.
- [x] 4.11 Make disabled pagination controls non-actionable.
- [x] 4.12 Use button semantics for the suggested-slug action.

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

## 10. Second Review Round — August 4, 2026

### 10.1 Round inventory and conclusion

The automated reviewers updated their existing GitHub issue comments in place after the first-round fixes reached commit `88102c1568edac1bd3b2b274cbde464b57fd6245`. Consequently, the GitHub comment IDs are unchanged even though their bodies now contain a new set of findings. This section records the replacement feedback separately so the first-round audit trail remains intact.

| Source | New issues | Determination |
| --- | ---: | --- |
| GitHub AI performance review | 4 | Fix all four |
| GitHub AI Elixir review | 2 | Fix both |
| GitHub AI UI review | 4 | Fix all four |
| GitHub AI TypeScript review | 0 | No action; the previous TypeScript finding is cleared |
| GitHub AI security review | 0 | No new security finding |

**Conclusion:** all 10 new findings are valid and should be fixed in this PR. None requires a scope deferral. The two delivery-cache findings, 10.2 and 10.5, should share one coherent `SectionResourceDepot` extension rather than adding separate caches or direct resolver queries.

### 10.2 Second-round implementation checklist

- [x] 10.3 Resolve media-event page data through the delivery depot without loading unnecessary revision data.
- [x] 10.4 Bound ClickHouse direct-upload parsing, transformation, and insertion memory.
- [x] 10.5 Index reward assignments by activity-attempt ID before constructing part-attempt attributions.
- [x] 10.6 Resolve alternatives groups through `SectionResourceDepot` during delivery page preparation.
- [x] 10.7 Enqueue reward handoff only after a successful activity-attempt update.
- [x] 10.8 Handle an empty resource-attempt list without crashing page preparation.
- [x] 10.9 Announce asynchronous `SelectModal` errors to assistive technology.
- [x] 10.10 Expose an accessible busy/progress state while `SelectModal` submits.
- [x] 10.11 Render and focus experiment-creation errors inside the open modal.
- [ ] 10.12 Add a persistent label to the new-condition name input.

### 10.3 Media events load full page content through a direct resolver query

- **Source:** GitHub AI performance review.
- **Current location:** `lib/oli/analytics/xapi.ex`, the resource-only video-event `construct_bundle/2` clause.
- **Issue:** The query joins section deployments, published resources, and revisions and selects `revision.content` for every media event. This is a delivery hot path, bypasses `SectionResourceDepot`, and transfers the full page content when attribution only needs to locate one content element inside an alternatives branch.
- **Determination:** Fix.
- **Evidence:** The current query directly joins `SectionsProjectsPublications`, `SectionResource`, `PublishedResource`, and `Revision`; its projection is `{project_id, publication_id, revision.content}`. The repository performance standard explicitly requires delivery paths to use `SectionResourceDepot`. The attempt-guid video path already reuses attempt content, but resource-only video events take this direct-query path.
- **Recommended resolution:** Introduce a depot-backed lookup that returns the deployed page identity plus only the alternatives/content-element metadata required by `MediaAttributions`. Reuse the same cached representation described in 10.6 if practical. Preserve authorization by section and expected user enrollment, and preserve publication identity when constructing the xAPI context. Do not replace this with another unbounded cross-request cache without an invalidation contract.
- **Tests:** Retain the existing resource-only media-attribution tests; add coverage for an unknown page, a user not enrolled in the section, a page with no alternatives, and cache invalidation after a section deployment update. Add a query-count assertion or telemetry-based check showing the repeated media path does not repeat the publication/revision join.

### 10.4 Direct upload retains multiple complete event representations

- **Source:** GitHub AI performance review.
- **Current location:** `lib/oli/analytics/xapi/clickhouse_uploader.ex`, `parse_and_insert_events/3`.
- **Issue:** The uploader splits the full JSONL body into a list of raw lines, retains each line beside its decoded statement, then materializes prepared events, raw rows, and attribution rows. The existing 500-row attribution insert chunks bound only the final SQL values; they do not bound parsing and transformation memory.
- **Determination:** Fix.
- **Evidence:** `parsed_events`, `prepared_events`, `unified_events`, and `experiment_attributions` coexist until both table inserts finish. Peak memory therefore scales with several representations of the complete bundle.
- **Recommended resolution:** Enumerate JSONL lazily and process it in a configured bounded chunk size. Within each chunk, decode and validate once, prepare once, insert raw rows and attribution rows, then release the chunk before continuing. Preserve explicit bundle-level error reporting and document partial-write semantics; deterministic hashes and ClickHouse idempotency must make retry safe if a later chunk fails. Avoid `String.split/3` if it still materializes every line.
- **Tests:** Prove that a bundle larger than the chunk size produces multiple bounded inserts with the correct total row counts; cover malformed JSON, invalid attribution data, and a failed middle chunk followed by a safe retry. Retain raw/attribution hash-parity tests.

### 10.5 Part-attempt attribution construction performs a nested assignment scan

- **Source:** GitHub AI performance review.
- **Current location:** `lib/oli/delivery/experiments/attempt_attributions.ex`, `part_attempt_attributions/3`.
- **Issue:** Although the first-round fix now limits the database result to assignments relevant to the supplied activity attempts, every host part attempt still scans every returned assignment and reads its reward map. This is `O(activity attempts × assignments)` work during xAPI statement generation.
- **Determination:** Fix.
- **Evidence:** `Enum.reduce(host_part_attempts, ...)` contains `Enum.flat_map(assignments, ...)`. Reward keys already encode both activity-attempt ID and assignment ID, so the results can be indexed once.
- **Recommended resolution:** Convert the fetched assignments into an `%{activity_attempt_id => [assignment]}` index before reducing host part attempts, then pass only the matching assignments to `attributions_for_assignment/3`. Prefer returning the matched attempt identity from the database query if doing so avoids reparsing reward keys; otherwise parse only the known, validated reward-key format once per assignment.
- **Tests:** Cover several activity attempts with disjoint assignments, multiple assignments for one attempt, unrelated reward keys, and no matching assignments. Add a focused unit test for the index to prevent reintroduction of the nested scan.

### 10.6 Delivery page preparation bypasses the section resource depot

- **Source:** GitHub AI performance review.
- **Current location:** `lib/oli/delivery/experiments/page_decisions.ex`, `prepare/2`.
- **Issue:** Every page preparation calls `Oli.Resources.alternatives_groups(section.slug, DeliveryResolver)`, resolving all alternatives groups directly instead of using the delivery cache and regardless of which group IDs appear in the page.
- **Determination:** Fix.
- **Evidence:** The call occurs on every page containing an alternatives element. `SectionResourceDepot` currently documents that alternatives resources are not included because no prior caller required them; this feature creates that requirement. The repository performance policy says delivery resolution must use the depot.
- **Recommended resolution:** Extend `SectionResourceDepot` support for deployed alternatives resources and add a lookup restricted to the alternatives resource IDs found in the current page content. Build `alternative_groups_by_id` from that bounded result. Ensure the existing depot coordinator invalidates the new cached representation on section publication/deployment changes. Share the lookup or representation with 10.3 where that reduces duplicate content traversal.
- **Tests:** Add focused `PageDecisions` coverage proving only referenced groups are returned, empty/no-alternatives pages perform no group lookup, and a deployment update invalidates stale group content. Verify repeated page preparation uses the depot rather than `DeliveryResolver` queries.

### 10.7 Failed activity-attempt updates still reserve the reward job uniqueness key

- **Source:** GitHub AI Elixir review.
- **Current location:** `lib/oli/delivery/attempts/activity_lifecycle/apply_client_evaluation.ex`, `evaluate_with_rule_engine_score/3`.
- **Issue:** `RewardHandoffWorker.enqueue(activity_attempt.id)` runs regardless of whether `update_activity_attempt/2` succeeds. A worker observing the still-unevaluated attempt completes as a no-op, while the worker's infinite uniqueness period can prevent the later successful evaluation from scheduling the same attempt.
- **Determination:** Fix; correctness and eventual-reward blocker.
- **Evidence:** The update result is stored in `result`, enqueue is unconditional, and only then is `result` returned. This defeats the intended idempotent, post-success handoff contract.
- **Recommended resolution:** Pattern-match on `{:ok, updated_attempt}` and enqueue using `updated_attempt.id` only on success; return `{:error, reason}` unchanged and do not insert a job. Keep the Oban insert transactionally coupled to the surrounding evaluation transaction so a rollback also rolls back the job.
- **Tests:** Add an update-failure test asserting no job is enqueued, a success test asserting exactly one job, and a transaction-rollback test asserting no visible job remains. Retain duplicate-enqueue uniqueness coverage.

### 10.8 Page decisions crash when no resource attempt exists

- **Source:** GitHub AI Elixir review.
- **Current location:** `lib/oli/delivery/experiments/page_decisions.ex`, `attempt_content/1`.
- **Issue:** `page_context.resource_attempts |> hd` raises `ArgumentError` for an empty list, converting an expected missing-state case into a delivery page-render failure.
- **Determination:** Fix.
- **Evidence:** There is no empty-list clause or prior guard. `prepare/2` already has an `@empty` result suitable for this case.
- **Recommended resolution:** Pattern-match `resource_attempts` in `attempt_content/1`; return an empty page model for `[]` and retain the existing selection-error handling for `[attempt | _]`. Avoid exception rescue as control flow.
- **Tests:** Add direct coverage for no attempts, one normal attempt, and the existing student selection-failure case. Assert `prepare/2` returns the exact `@empty` shape without querying alternatives.

### 10.9 Asynchronous modal errors are not announced

- **Source:** GitHub AI UI review.
- **Current location:** `assets/src/components/modal/SelectModal.tsx`, `renderFailed/1`.
- **Issue:** Fetch and submit errors replace the modal body in an unmarked `<div>`. Screen readers are not guaranteed to announce this asynchronous DOM update.
- **Determination:** Fix.
- **Evidence:** `handleDone` stores rejected errors in component state, and `renderFailed` renders plain divs with no live-region semantics or association to the select/control.
- **Recommended resolution:** Give the error container `role="alert"` (or an assertive live region), a stable ID, and associate it with the relevant select and submit control through `aria-describedby` when present. Keep the error copy actionable and avoid announcing the same message repeatedly.
- **Tests:** Add React tests asserting the alert appears for option-fetch and submit rejection, has the expected accessible role/name or description, and clears on retry.

### 10.10 Modal submission has no accessible progress feedback

- **Source:** GitHub AI UI review.
- **Current location:** `assets/src/components/modal/SelectModal.tsx`, the Select button and `submitting` state.
- **Issue:** Submission disables the button but leaves its label as `Select`, so users receive no explanation that work is in progress.
- **Determination:** Fix.
- **Evidence:** `submitting` participates only in the `disabled` expression. It is not exposed through `aria-busy`, visible copy, a status region, or an accessible spinner.
- **Recommended resolution:** Set `aria-busy={submitting}` on the operation's containing region or submit button and change the button label to `Selecting…` while pending. If a spinner is used, mark decorative animation hidden and keep textual status available. Continue preventing duplicate submission.
- **Tests:** Use a controllable promise to assert the pending label/busy/disabled state, then assert restoration on both resolve and reject.

### 10.11 Experiment creation errors render outside the active modal

- **Source:** GitHub AI UI review.
- **Current location:** `lib/oli_web/live/workspaces/course_author/experiments_live.ex`, the page-level `@experiment_error` alert and create-experiment modal.
- **Issue:** A failed create leaves `@show_create_experiment` true but renders the error above the page table, behind the modal overlay and outside the dialog's focus boundary. The user may neither see nor reach the explanation.
- **Determination:** Fix.
- **Evidence:** Both error branches preserve the modal and assign `experiment_error`, while the only alert is rendered before the table outside `<OliWeb.Components.Modal.modal>`.
- **Recommended resolution:** Render the create-specific error at the top of the modal form with `role="alert"`, a stable focusable target, and focus it after a failed submit. Keep page-level errors for operations performed outside the create modal, or split the assign by operation so unrelated errors are not duplicated. Preserve entered form values and current field-level errors.
- **Tests:** Extend LiveView tests to force a create failure and assert the message is inside `#create-experiment-modal`, the modal remains open, entered values persist, and the focus command targets the alert. Confirm successful creation closes the modal and clears the error.

### 10.12 New-condition input relies on placeholder text as its label

- **Source:** GitHub AI UI review.
- **Current location:** `lib/oli_web/live/workspaces/course_author/experiments_live.ex`, `new-condition-form-*`.
- **Issue:** The condition name input has a placeholder but no persistent visible or programmatic label. The placeholder disappears during entry and does not satisfy the form-label requirement.
- **Determination:** Fix.
- **Evidence:** The input has a generated ID and `name="condition[name]"`, but there is no `<label for=...>` or `aria-label`/`aria-labelledby`.
- **Recommended resolution:** Add a visible `Condition name` label whose `for` exactly matches `new-condition-input-#{@group.resource_id}`. The placeholder may remain as optional guidance. A visible label is preferred over adding ARIA-only text.
- **Tests:** Update the inline-condition LiveView test to assert the label/input association and retain the existing create, cancel, Escape, and enabled-state behavior.

### 10.13 Second-round verification gate

- Run focused `mix test` files for activity evaluation, reward handoff, page decisions, xAPI media attribution, attempt attribution, and the experiments LiveView.
- Run the focused Jest suite for `SelectModal` and any callers whose async behavior changes.
- Add depot invalidation tests before relying on cached alternatives metadata.
- Exercise ClickHouse upload with more than one processing chunk and retry after a failed middle chunk.
- Run `mix format` and the appropriate frontend formatter on touched files, followed by `git diff --check`.
- Re-read the edited GitHub review bodies before implementation begins; automated comments are mutable and may be replaced again on the next head revision.

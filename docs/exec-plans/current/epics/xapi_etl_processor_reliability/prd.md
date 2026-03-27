# xAPI ETL Processor Reliability - Product Requirements Document

## 1. Overview
The xAPI ETL processor is a Python AWS Lambda that ingests xAPI JSONL objects from S3, receives object references through SQS, transforms those rows into Arrow/Parquet, and inserts them into ClickHouse for analytics use. This work item captures the current product and operational intent of that pipeline, with emphasis on reliable ingestion, predictable retry behavior, bounded execution costs, and actionable observability.

## 2. Background & Problem Statement
The current pipeline is functionally straightforward but operationally fragile. Recent production behavior shows Lambda invocations preparing batches successfully, then timing out during the combined insert path without enough stage-level telemetry to distinguish Arrow concatenation cost, Parquet serialization cost, HTTP insert latency, or downstream ClickHouse stalls. Because the function uses SQS partial batch responses, a timeout causes already-prepared messages to be retried, which increases duplicate work, queue pressure, and operator uncertainty. The system needs explicit requirements for correctness, failure handling, performance guardrails, and diagnostics before implementation changes are made.

## 3. Goals & Non-Goals
### Goals
- Define the intended end-to-end behavior of the xAPI ETL processor in product and operational terms.
- Make ingestion correctness and retry semantics explicit for S3, SQS, Lambda, and ClickHouse interactions.
- Require enough observability to identify where execution time and memory are spent in production batches.
- Require batching behavior that targets ClickHouse-efficient inserts while remaining bounded by freshness, Lambda runtime, and memory constraints.
- Require an architecture that remains cost-efficient at low initial throughput and scales toward ClickHouse-efficient larger batches as event volume grows.
- Require a buffering and recovery posture that tolerates scheduled ClickHouse downtime without losing source events.
- Allow architectural changes to the ingestion path, including staged intermediate artifacts such as Parquet in S3, when they materially improve the ability to meet the overall requirements with a single scalable pipeline.
- Require Torus-managed backfills to include a one-time post-backfill dedupe cleanup step and expose that finalization progress in the admin UI.
- Provide a requirements baseline for subsequent fixes, tuning, and architecture adjustments.

### Non-Goals
- Redesign the broader xAPI production pipeline outside this Lambda's scope.
- Define the final implementation approach for every optimization; this PRD captures outcomes, not the full design, and leaves room for an FDD-level architecture choice.
- Introduce user-facing UI changes.
- Replace ClickHouse, SQS, S3, or Lambda with a different platform in this work item.

## 4. Users & Use Cases
- Platform operators: need to understand whether ingestion is healthy, stalled, retrying, or dropping data.
- Data and analytics consumers: need raw xAPI events to arrive in ClickHouse accurately and with acceptable freshness.
- Engineers maintaining the pipeline: need clear requirements for batching, failure handling, timeouts, and observability so fixes can be made safely.
- On-call responders: need logs and telemetry that identify whether failures happen during fetch, transform, serialization, network transfer, or ClickHouse response handling.
- Administrators running bulk backfills: need the Torus admin workflow to show when post-backfill ClickHouse cleanup is executing and when the overall backfill is truly complete.

## 5. UX / UI Requirements
N/A

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Reliability: The processor must avoid silent failure modes and must either acknowledge successfully handled messages or return explicit batch item failures for retry.
- Performance: Batch processing should target ClickHouse-efficient insert sizes, generally on the order of 10,000 to 30,000 rows when workload shape allows, but must stay within configured Lambda timeout and memory budgets with explicit safety margins rather than relying on best-effort completion at the deadline.
- Cost Efficiency: The ingestion design must avoid unnecessary Lambda churn, excess retries, and oversized idle compute usage at low throughput while still supporting higher-throughput aggregation when traffic grows.
- Availability & Recovery: The ingestion path must tolerate planned ClickHouse outages by buffering events durably upstream and resuming processing after maintenance without manual data reconstruction.
- Observability: Logs and telemetry must identify stage durations, batch sizes, row counts, payload sizes, retries, and terminal outcomes without exposing sensitive learner payload contents.
- Security & Privacy: The processor must not log full xAPI statement bodies or other sensitive data at normal log levels, and any failure forwarding must preserve only the minimum data needed for triage.
- Operability: Runtime controls such as batch size, Lambda timeout, ClickHouse request timeout, and memory allocation must have documented relationships and safe defaults.

## 9. Data, Interfaces & Dependencies
- Input interface: SQS event source mapping delivers batches of SQS messages, each containing one or more S3 object references derived from S3 object-created notifications.
- Source data: S3 objects contain JSON Lines xAPI-like event payloads.
- Transform path: The Lambda converts source rows into Arrow tables, normalizes to the ClickHouse raw events schema, concatenates message-level tables, and serializes a Parquet payload for insert.
- Sink interface: ClickHouse HTTP `INSERT ... FORMAT Parquet`.
- Failure interface: SQS partial batch response determines which messages are retried; an optional failure DLQ receives irrecoverable records with summarized failure context.
- Dependencies: AWS Lambda, SQS, S3, ClickHouse HTTP endpoint, PyArrow, NumPy, Requests, CloudWatch logs, and AppSignal or equivalent telemetry aggregation used by the repository.
- Architectural flexibility: Additional AWS-managed services that improve buffering, batching, cost efficiency, or operational safety are in scope if they preserve the product contract and simplify reliable ingestion.
- Intermediate storage flexibility: A design that writes normalized intermediate artifacts, including Parquet files in S3, is in scope if it supports one coherent ingestion pipeline and improves batching, recovery, or operational efficiency.
- Maintenance posture: The architecture may rely on SQS or another durable AWS-managed buffer so operators can pause downstream processing during scheduled ClickHouse maintenance and resume consumption after the instance is healthy again.
- Backfill completion posture: Torus-managed backfills may perform a one-time post-backfill `OPTIMIZE TABLE ... FINAL` step and should not report the run as fully complete until that step has finished or failed explicitly.

## 10. Repository & Platform Considerations
- The implementation lives in `cloud/xapi-etl-processor/lambda_function.py` and is a Python analytics-adjacent ETL component within a primarily Elixir/Phoenix repository.
- Repository guidance requires operationally risky work to be observable through telemetry and APM rather than inferred after failure.
- The current implementation performs message-level preparation first and a single combined insert later, which has implications for memory duplication, retry scope, and timeout behavior.
- The Lambda uses SQS partial batch responses, so timeout behavior is part of the product contract, not just an infrastructure detail.
- Validation and follow-on implementation should prefer targeted automated tests around Python ETL behavior and operational contracts.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Batch-level metrics:
  - received SQS message count
  - prepared message count
  - failed message count
  - empty message count
  - total source row count
  - total S3 object count
- Stage-level metrics:
  - time spent extracting message references
  - time spent downloading and parsing S3 objects
  - time spent concatenating Arrow tables
  - time spent serializing Parquet
  - Parquet payload byte size
  - time spent waiting on ClickHouse HTTP insert
  - Lambda remaining time before and after major stages
- Success signals:
  - low-volume initial rollout remains timely even when inserts are only in the tens to hundreds of rows
  - successful batches complete with explicit success summary logs
  - timeout-driven retries become rare and measurable
  - most steady-state inserts land near the preferred ClickHouse row-count range without materially increasing freshness lag
  - cost per ingested row improves or remains acceptable as throughput grows
  - scheduled ClickHouse maintenance can be handled by buffering upstream events and later draining the backlog without data loss
  - when a bulk backfill is run, the admin UI clearly shows the final post-backfill optimization step until it completes
  - operators can determine the dominant cost center of a failed or slow batch from one invocation's logs and telemetry

## 13. Risks & Mitigations
- Large or skewed batches can consume memory faster than expected: require bounded batch work and stage-level memory/time observability.
- ClickHouse slowness can cause Lambda retries and duplicate upstream work: require request timeout behavior aligned with remaining Lambda time and explicit failure reporting.
- Combined-batch insert failures can widen retry scope: require deterministic handling and clear accounting for which messages are retried.
- Optimizing only for large batches could hurt freshness and cost during initial low-volume rollout: require explicit low-volume flush behavior and cost-efficiency evaluation, not only peak-throughput tuning.
- The current Lambda-plus-SQS shape may not be the lowest-risk long-term architecture: permit other AWS-managed buffering or orchestration components if they better satisfy batching and cost goals.
- The current direct Lambda-to-ClickHouse insert path may not be the best way to achieve large efficient batches and maintenance resilience: permit staged intermediate-storage designs if they reduce operational risk without creating parallel pipelines.
- Scheduled ClickHouse downtime can create noisy retry storms or operator confusion if ingestion is not explicitly pausable: require a documented pause-buffer-resume workflow with durable upstream retention.
- Overly verbose diagnostics could expose sensitive data or explode log volume: require structured, bounded observability focused on metadata rather than payload contents.

## 14. Open Questions & Assumptions
### Open Questions
- What batch-size, batching window, and concurrency settings should be treated as the default operational baseline for production sections with larger xAPI objects while still aiming for 10,000 to 30,000 row inserts?
- Should the processor keep a single combined insert per invocation, or should it support smaller sub-batches to reduce timeout and memory risk?
- Which AWS-managed services, if any, should be introduced to buffer or aggregate low-volume S3 arrivals into more efficient ClickHouse insert units without unacceptable freshness lag?
- Should the chosen single-pipeline architecture perform direct ClickHouse inserts from Lambda or stage normalized Parquet artifacts in S3 before ingestion?
- What operator controls and alarms should gate pausing and resuming downstream consumers during planned ClickHouse maintenance?
- What duplicate-tolerance or idempotency guarantees does downstream ClickHouse ingestion require if SQS retries occur after uncertain insert completion?

### Assumptions
- The processor is intended to preserve best-effort throughput while favoring correctness and recoverability over maximum batch size.
- ClickHouse performs best with inserts roughly in the 10,000 to 30,000 row range, but freshness and Lambda safety constraints may justify smaller batches during lower-volume or skewed workloads.
- Initial rollout and testing are likely to produce only tens to hundreds of rows per effective batch, and that is acceptable as long as the system remains timely and cost-conscious.
- Higher sustained throughput should allow the system to aggregate toward larger ClickHouse-efficient batches without redesigning the product contract.
- ClickHouse remains the canonical OLAP destination for these raw events.
- Lambda timeout, memory size, and SQS event source mapping settings are adjustable as part of operational hardening.
- Operators can pause and later resume downstream consumers such as Lambda event source mappings during planned maintenance windows if the upstream buffer retains events durably enough.
- Existing production issues are caused primarily by bounded-runtime resource pressure and insufficient observability, not by malformed source payloads alone.

## 15. QA Plan
- Automated validation:
  - Targeted Python tests covering successful batch processing, preparation failures, insert failures, timeout-aware request timeout selection, and partial batch response behavior.
  - Tests covering structured logging or telemetry emission for major processing stages and terminal outcomes.
  - Tests covering bounded behavior for empty batches, single-message batches, and mixed-success message batches.
- Manual validation:
  - Exercise the Lambda in `DRY_RUN` and real insert modes with representative small and large batches.
  - Confirm CloudWatch logs identify stage durations, row counts, payload sizes, and remaining-time context.
  - Confirm intentional ClickHouse slowness or failure produces explicit logs and deterministic message retry behavior.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes

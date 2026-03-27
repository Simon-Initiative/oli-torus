# Automated Testing Experiment - Functional Design Document

## 1. Executive Summary
This design keeps the automated testing experiment out of Torus request/response code and implements V1 as a repository-local testing package centered on Python tooling, explicit JSON schemas, and deterministic file contracts. The simplest adequate design is a `manual_testing/` workspace in the repo that contains case and suite definitions, JSON Schema files, reusable Python utilities, and a local run-results directory. An advanced browser-driving agent runtime remains the primary actor, but human-to-agent messaging is outside the scope of these repository tools. The in-scope design starts at structured execution inputs and provides utilities for validation, conversion, execution-request preparation, result normalization, and durable report storage. No new Phoenix UI, database tables, or feature flags are required.

## 2. Requirements & Assumptions
- Functional requirements:
  - `FR-001` with `AC-001`: define canonical test-case, test-suite, and test-run schemas with repository-managed validation.
  - `FR-002` with `AC-001`: provide Python validation and linting utilities for authored documents before execution.
  - `FR-003` with `AC-002`: convert spreadsheet or CSV source scripts into candidate YAML while preserving source wording and surfacing ambiguity.
  - `FR-004` with `AC-003` and `AC-004`: execute one case or a suite sequentially against a supplied target environment and produce one run report per case.
  - `FR-005` with `AC-005`: capture per-step, per-assertion, timing, notes, and terminal status in a canonical run report.
  - `FR-006` with `AC-006`: persist reports and optional artifacts to deterministic S3 paths.
  - `FR-007` with `AC-007`: distinguish validation failure, blocked execution, assertion failure, and execution error clearly.
  - `FR-008` with `AC-008`: emit structured lifecycle telemetry without secrets.
- Non-functional requirements:
  - V1 remains sequential and single-runner.
  - Execution must be debuggable from stored artifacts and local logs without replaying the session.
  - No credentials or session secrets may be written to repository-managed files, telemetry, or durable reports.
- Assumptions:
  - The schema examples in [`information.md`](/Users/darren/dev/oli-torus/docs/exec-plans/current/epics/automated_testing/experiment/information.md) are the intended V1 contract source; there is no `informal.md` in this work item today.
  - The first browser-driving runtime may be external to Torus and should consume explicit structured inputs rather than repository-owned human-message parsing.
  - S3 credentials and target bucket configuration are provided through environment variables or external runtime configuration, not committed files.
  - Initial scope covers a limited, curated set of stable regression cases rather than the entire manual QA inventory.

## 3. Repository Context Summary
- What we know:
  - Torus already accepts Python in the repository for operational or support tooling, and there are existing Python-based cloud utilities under `cloud/`.
  - The repo already uses S3 across other subsystems, and Elixir dependencies include `ex_aws` while Python support exists for AWS tooling such as `boto3`; that gives flexibility without forcing this experiment into the main application runtime.
  - `docs/TESTING.md` positions browser automation as distinct from `Oli.Scenarios`, which supports keeping this experiment separate from the scenario DSL.
  - `docs/OPERATIONS.md` and `docs/design-docs/genai.md` emphasize telemetry and AppSignal-style observability, so the design should emit structured lifecycle signals even if the first implementation is agent-driven outside Torus.
  - `ARCHITECTURE.md` and `docs/BACKEND.md` favor keeping domain logic out of UI layers; for this work item, the corollary is to keep experimental automation infrastructure out of Phoenix request handling unless a later phase needs in-product entry points.
- Unknowns to confirm:
  - What concrete contract the advanced runtime should use for structured run inputs, context loading, and optional tool invocation.
  - Whether screenshots are mandatory on failure or optional when supported by the selected runner.
  - Whether local development should target AWS S3 directly or a MinIO-compatible endpoint through the same configuration contract.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- `manual_testing/schemas/`
  - Owns JSON Schema definitions for `test_case`, `test_suite`, `test_run`, and a small `execution_request` manifest used between the CLI and the agent adapter.
  - The YAML examples from `information.md` become the initial schema baseline, extended only where V1 needs deterministic execution metadata.
- `manual_testing/cases/` and `manual_testing/suites/`
  - Store authored YAML inputs grouped by domain, for example `authoring/` and `delivery/`.
  - Case files remain human-editable and source-controlled.
- `manual_testing/tools/manualtest.py`
  - Repository utility entrypoint with subcommands such as `validate`, `lint`, `convert`, and `upload`.
  - Provides schema loading, file validation, conversion normalization, and upload support as tools the agent runtime may call.
- `.agents/skills/manual_testing_*`
  - Repository-local agent skills that wrap the Python utilities and define the stable agent-facing workflow for validation, execution preparation, runtime invocation handoff, and result normalization.
  - Keep message handling out of scope; the skills start from explicit structured inputs and tool calls.
- Advanced agent runtime
  - Primary execution actor for V1.
  - Reads repository docs and YAML assets, drives the browser, and returns or writes structured execution observations.
- `manual_testing/results/`
  - Ephemeral local workspace for manifests, normalized reports, and optional artifact references before upload.
  - Not intended to be a durable source-controlled directory.

### 4.2 State & Data Flow
1. A user authors or selects a case or suite YAML file under `manual_testing/`.
2. The advanced runtime or agent skill resolves structured execution inputs such as suite or case identifier, environment label, optional base URL, credentials-source reference, and documentation context paths.
3. The runtime may call Python utilities to validate schemas, lint YAML, or convert spreadsheet exports before execution. This is the primary path for `AC-001` and `AC-002`.
4. A preparation utility expands the explicit target selection into one execution request per case, including case path, artifact directory, and safe execution metadata. This supports `AC-003`, `AC-004`, and `AC-007`.
5. The runtime executes cases sequentially, drives the browser against the target environment, and captures step observations, assertion outcomes, notes, and optional artifacts.
6. The runtime or a supporting utility normalizes those observations into the canonical `test_run` JSON document and writes it under `manual_testing/results/`.
7. If S3 upload is configured, the runtime or utility uploads the report and artifacts to deterministic object keys and annotates the local report with upload metadata. This is the path for `AC-006`.
8. Suite execution may also write a local summary, but the authoritative durable artifact remains one run report per case, covering `AC-004` and `AC-005`.

### 4.3 Lifecycle & Ownership
- Test case and suite ownership lives in the repository as versioned YAML.
- Schema ownership lives in the repository and changes under normal review.
- Run-report ownership is split:
  - local canonical JSON exists first in `manual_testing/results/`;
  - durable audit copy lives in S3 after successful upload.
- The advanced browser-driving agent runtime is the primary executor for V1.
- Python utilities are supporting tools the runtime may use for validation, conversion, normalization, and upload.
- Torus product code remains unchanged in V1 unless a later slice introduces a native trigger or viewer.

### 4.4 Alternatives Considered
- Build V1 as an Elixir/Phoenix subsystem:
  - Rejected because V1 does not need runtime web entry points, database persistence, or LiveView state, and embedding it into the app would increase operational and review surface too early.
- Extend `Oli.Scenarios` to drive browsers:
  - Rejected because `docs/TESTING.md` positions scenarios as non-UI integration tests using real Torus workflows, not browser automation.
- Allow arbitrary prompt-only execution without schemas:
  - Rejected because it fails `FR-001`, weakens repeatability, and makes post-run triage too dependent on agent transcripts.
- Upload only a suite summary to S3:
  - Rejected because it weakens case-level auditability needed by `AC-005` and `AC-006`.

## 5. Interfaces
- `manualtest.py validate <path>`
  - Input: path to case, suite, or run document.
  - Output: exit code plus structured validation errors.
  - Covers `AC-001`.
- `manualtest.py convert --input <csv> --output <yaml_dir>`
  - Input: spreadsheet or CSV export.
  - Output: candidate YAML case files plus ambiguity warnings.
  - Covers `AC-002`.
- Structured runtime inputs
  - Required fields:
    - target suite or case
    - target environment label
    - optional base URL
    - optional release or branch identifier
    - optional run label for unique result grouping
    - credentials source reference
    - documentation context paths
  - Human-to-agent message handling that produces these values is explicitly out of scope for this repository work.
- Execution request manifest
  - Fields:
    - `run_id`
    - `test_case_path`
    - `base_url`
    - `environment_label`
    - `doc_context_paths`
    - `credentials_source_ref`
    - `suite_run_id`
    - `artifact_dir`
    - `case_id`
    - `suite_id`
  - Internal contract the runtime may materialize before or during execution; excludes actual secrets.
- Runtime execution result contract
  - Fields:
    - `status`
    - `started_at`
    - `completed_at`
    - `steps`
    - `assertions`
    - `agent_notes`
    - `confidence`
    - `artifacts`
    - `failure_kind`
  - Enables the runtime or supporting utility to synthesize the canonical run-report JSON and classify blocked vs error conditions for `AC-007`.

## 6. Data Model & Storage
- `test_case` YAML
  - Initial fields follow the schema example from `information.md`:
    - `id`
    - `title`
    - `description`
    - `tags`
    - `preconditions`
    - `steps[]`
    - `expected[]`
    - `notes`
  - V1 design addition:
    - `domain` optional enum such as `authoring` or `delivery`
    - `source` block for conversion provenance when the case originated from CSV
- `test_suite` YAML
  - Initial fields:
    - `id`
    - `title`
    - `tests[]`
    - `tags`
  - V1 design addition:
    - `defaults.base_url_label` optional named environment hint, not a literal credential or secret
- `test_run` JSON
  - Uses the example shape in `information.md` with these additions:
    - `base_url`
    - `case_path`
    - `suite_id` optional
    - `failure_kind` enum: `validation_failed | blocked | assertion_failed | execution_error`
    - `artifacts[]` with object key or local relative path
    - `upload` block containing bucket, key, uploaded_at, and upload status
- Local storage
  - `manual_testing/results/<run_id>/report.json`
  - `manual_testing/results/<run_id>/artifacts/*`
  - `manual_testing/results/<suite_run_id>/summary.json`
- Durable storage
  - S3 key pattern:
    - `manual-testing/<env>/<yyyy>/<mm>/<dd>/<run_id>/report.json`
    - `manual-testing/<env>/<yyyy>/<mm>/<dd>/<run_id>/artifacts/<name>`
  - Deterministic naming is the primary design for `AC-006`.

## 7. Consistency & Transactions
- There is no database transaction boundary in V1.
- Execution follows a staged-write model:
  - validate input
  - create local run workspace
  - execute and synthesize canonical report
  - upload report
  - upload artifacts
  - finalize upload metadata
- Local report generation happens before upload so failures remain inspectable even when S3 write fails.
- Upload finalization should be idempotent by reusing `run_id` and object keys.
- Suite execution should continue or stop based on an explicit `--fail-fast` policy, defaulting to continue so each case gets its own terminal record.

## 8. Caching Strategy
- N/A for V1.
- The runtime or its supporting utilities may cache loaded schemas and parsed suite membership in process memory during a single invocation, but no cross-run cache is required.

## 9. Performance & Scalability Posture
- V1 is intentionally sequential, so no parallel scheduling or distributed work queue is introduced.
- Performance focus is bounded execution behavior, not throughput optimization:
  - schema loads happen once per invocation;
  - suite membership is resolved once before execution;
  - upload retries are bounded.
- Expected bottlenecks are browser-driving runtime latency and network upload time, not local schema validation.
- If suite sizes grow materially, later phases can add work-queue parallelism behind the same case and run-report contracts without changing authored schema files.

## 10. Failure Modes & Resilience
- Invalid authored YAML or JSON:
  - fail validation before execution with machine-readable errors.
  - This is the main design path for `AC-001` and part of `AC-007`.
- Ambiguous CSV conversion:
  - generate a candidate file plus warnings rather than silently dropping content.
  - Covers `AC-002`.
- Agent runtime cannot launch or loses browser control:
  - classify as `execution_error`, persist notes, and keep any partial artifacts.
- Product behavior blocks progression because of environment issues or missing fixtures:
  - classify as `blocked` rather than `failed`.
- Step assertion mismatch:
  - keep terminal status `failed` with per-assertion failure detail.
- S3 upload failure:
  - leave the canonical local report intact, set upload status to failed, and emit an upload-failed event.
- Secret leakage risk:
  - never serialize credential values into manifests, reports, or telemetry metadata.

## 11. Observability
- The runtime and any supporting utilities should emit structured lifecycle events for:
  - `validation_started`
  - `validation_finished`
  - `conversion_started`
  - `conversion_finished`
  - `case_run_started`
  - `case_run_finished`
  - `suite_run_finished`
  - `upload_started`
  - `upload_finished`
  - `upload_failed`
- Minimum metadata:
  - `run_id`
  - `suite_id` optional
  - `case_id`
  - `base_url_label` or sanitized environment label
  - `status`
  - `failure_kind`
  - `duration_ms`
- Exclusions:
  - no credentials
  - no session cookies
  - no raw prompts or free-form browser transcript unless explicitly stored as a redacted artifact
- If a later implementation chooses to bridge events into Torus telemetry or AppSignal, the event names and metadata above are the stable contract for `AC-008`.

## 12. Security & Privacy
- Credentials remain out of repo-managed YAML and JSON.
- Execution manifests contain a `credentials_source_ref` only, not credential material.
- Run reports must not persist cookies, bearer tokens, or raw authentication headers.
- Artifact capture should be opt-in and reviewable because screenshots may contain learner, instructor, or institution-specific data in non-production environments.
- S3 uploads should use least-privilege credentials scoped to the experiment bucket or prefix.
- The runtime or supporting utilities should redact obviously sensitive values from notes before persistence when raw execution observations contain them accidentally.

## 13. Testing Strategy
- Python unit tests:
  - schema validation and lint behavior for `AC-001`
  - CSV conversion fidelity and ambiguity reporting for `AC-002`
  - run-report synthesis and failure classification for `AC-005` and `AC-007`
  - upload path generation and metadata shaping for `AC-006`
  - lifecycle event emission and metadata redaction for `AC-008`
- Python integration tests:
  - single-case execution-flow support with a fake runtime result fixture for `AC-003`
  - multi-case suite normalization with deterministic per-case output for `AC-004`
- Contract fixtures:
  - golden fixtures for example case YAML, suite YAML, and run-report JSON based on the schema examples in `information.md`
- Manual validation:
  - run one authoring case and one delivery case end to end against a non-production environment to confirm the adapter boundary and artifact upload behavior
- Traceability notes:
  - `AC-001` validated by schema and lint tests
  - `AC-002` validated by conversion tests plus manual review
  - `AC-003` validated by fake-adapter orchestration plus one real smoke run
  - `AC-004` validated by suite integration tests
  - `AC-005` validated by golden report fixtures
  - `AC-006` validated by upload integration tests against a test bucket or MinIO
  - `AC-007` validated by failure-mode classification tests
  - `AC-008` validated by event emission and redaction tests

## 14. Backwards Compatibility
- No Torus learner, instructor, or authoring runtime behavior changes in V1.
- No database schema, API, or UI compatibility impact.
- Existing manual spreadsheets can coexist with the new YAML source format during migration.
- Because the experiment lives in a repo-local subtree and external runner boundary, rollback is simply to stop using the tooling without affecting production delivery.

## 15. Risks & Mitigations
- External agent runtime churn could destabilize the experiment:
  - keep run inputs and outputs behind stable repository contracts and normalize all output into the canonical run schema.
- Schema creep could turn V1 into a platform project:
  - hold to the minimal fields documented in `information.md` and add only execution-critical metadata.
- Artifact uploads may expose sensitive environment data:
  - make artifact capture explicit, redact where possible, and scope bucket access tightly.
- Users may treat conversion output as authoritative even when the source spreadsheet is ambiguous:
  - persist ambiguity warnings and require human review before execution.

## 16. Open Questions & Follow-ups
- Which concrete advanced runtime will own the first execution implementation?
- Should `failure_kind=blocked` require a fixed reason taxonomy in V1, or can it start as free-form notes plus terminal status?
- Should the suite summary be formalized as its own schema in V1, or remain an internal convenience artifact?
- Do we want MinIO support documented from the start for local verification of `AC-006`, or defer it until implementation?

## 17. References
- [prd.md](/Users/darren/dev/oli-torus/docs/exec-plans/current/epics/automated_testing/experiment/prd.md)
- [requirements.yml](/Users/darren/dev/oli-torus/docs/exec-plans/current/epics/automated_testing/experiment/requirements.yml)
- [information.md](/Users/darren/dev/oli-torus/docs/exec-plans/current/epics/automated_testing/experiment/information.md)
- [ARCHITECTURE.md](/Users/darren/dev/oli-torus/ARCHITECTURE.md)
- [TESTING.md](/Users/darren/dev/oli-torus/docs/TESTING.md)
- [OPERATIONS.md](/Users/darren/dev/oli-torus/docs/OPERATIONS.md)
- [genai.md](/Users/darren/dev/oli-torus/docs/design-docs/genai.md)

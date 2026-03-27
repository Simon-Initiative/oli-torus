# Automated Testing Experiment - Product Requirements Document

## 1. Overview
This work item defines a narrow V1 experiment for agent-driven execution of Torus manual regression tests. The experiment introduces a repository-managed test definition format, lightweight validation and conversion tooling, command-driven agent execution for single test cases or suites, and durable storage of structured run outputs in S3 so QA and engineering can inspect results without relying on ad hoc notes.

## 2. Background & Problem Statement
- Torus regression coverage still depends on humans following spreadsheet-based scripts, which makes execution slow, inconsistent, and difficult to repeat across release candidates.
- Existing manual cases are not stored in a machine-friendly structure that an advanced testing agent and its supporting tools can validate, transform, and execute reliably.
- The immediate opportunity is to reduce repetitive QA effort for stable regression paths without taking on the larger problems of CI orchestration, secrets management, or a live monitoring product surface.
- The source brief is explicitly experimental, so V1 must stay narrow enough to prototype quickly while still yielding artifacts that can inform whether broader automated testing investment is justified.

## 3. Goals & Non-Goals
### Goals
- Define canonical YAML and JSON schemas for manual test cases, suites, and run reports used by this experiment.
- Let an agent execute a single test case or a suite sequentially against a specified Torus environment using repository-defined instructions and supporting docs.
- Provide Python tooling that the agent runtime can use for schema validation, linting, spreadsheet conversion, and structured run output generation.
- Provide repository-local agent skills under `.agents/skills/` that let the advanced runtime invoke validation, execution preparation, and result normalization consistently.
- Persist structured run results to S3 so QA and engineering can review outcomes and artifacts outside the agent session.
- Keep the implementation generic enough to support authoring and delivery regression paths without requiring a dedicated UI.

### Non-Goals
- Building a real-time execution dashboard or operations console.
- Introducing a repository-level credential vault or general-purpose secret management system.
- Integrating the experiment into CI/CD, merge gates, or release automation in V1.
- Running tests in parallel or orchestrating multiple agents in V1.
- Modeling every environment nuance beyond the minimal target URL and run metadata required for execution.

## 4. Users & Use Cases
- QA engineer or release tester: defines or selects a regression suite, provides the agent runtime with the required structured run inputs, and reviews structured results and artifacts after execution.
- Developer maintaining regression coverage: converts an existing spreadsheet script into YAML, validates it locally, and improves the test definition when agent execution reveals ambiguity.
- Engineering manager or release owner: inspects S3-backed run reports to understand which regression paths passed, failed, or were blocked for a candidate build.

## 5. UX / UI Requirements
- V1 does not require a new Torus product UI; repository tooling and agent-skill support should focus on structured execution inputs rather than human-to-agent messaging.
- Test case and suite definitions must remain readable and editable by engineers and QA in the repository.
- Conversion output should preserve source text closely enough that a reviewer can compare generated YAML against the original spreadsheet content without reconstructing intent.
- Run reports must be human-inspectable JSON with clear per-step and per-assertion status so failures can be triaged without replaying the entire session.
- If screenshots or similar artifacts are captured in V1, references to them must be included in the stored run output or adjacent manifest so reviewers can locate them deterministically.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Reliability: sequential suite execution must record deterministic terminal status for each test case (`passed`, `failed`, `blocked`, or `error`) even when a later step cannot complete.
- Security and privacy: credentials, session tokens, and other secrets must not be committed to the repository or persisted in run reports, logs, or telemetry payloads.
- Performance: V1 may remain single-agent and sequential, but validation and report-generation tooling should complete in bounded time for normal regression suite sizes without unbounded retry loops.
- Operability: the experiment should emit enough structured logs or telemetry to diagnose validation, execution, upload, and artifact-linking failures.
- Maintainability: schemas and tooling should be explicit enough that new manual tests can be added without editing agent code for every case.

## 9. Data, Interfaces & Dependencies
- Test case definitions are YAML documents stored under a repository-managed manual-testing directory, grouped by domain such as authoring and delivery.
- Test suite definitions are YAML documents that reference one or more test case paths and optional grouping metadata.
- Test run output is JSON that records run metadata, per-step outcomes, per-assertion outcomes, agent notes, timing, and optional artifact references.
- Python tooling supports schema validation, linting, spreadsheet-to-YAML conversion, and report generation as capabilities the agent runtime may use while executing work.
- The execution flow depends on an advanced browser-driving agent runtime plus access to Torus environments under test and an S3 bucket for durable result storage.
- Existing repository documentation should be consumable as execution context so the agent can interpret Torus concepts, roles, and critical workflows while running tests.

## 10. Repository & Platform Considerations
- The experiment should live outside core learner or author runtime paths so prototyping does not destabilize normal Torus delivery behavior.
- Repository structure, tooling, and tests should follow existing repo conventions documented in `docs/STACK.md`, `docs/TOOLING.md`, and `docs/TESTING.md`.
- Validation and conversion logic should be available through targeted Python tooling rather than embedded only in ad hoc prompts so behavior remains reproducible when the agent chooses to use those utilities.
- Any Torus-facing implementation work should respect existing role boundaries, multi-tenant scoping, and environment separation described in `ARCHITECTURE.md`, `docs/BACKEND.md`, and `docs/OPERATIONS.md`.
- Before implementation, the work should be tracked in Jira and reviewed under the repository’s normal security and performance review expectations, with additional UI or Elixir review only if the implementation expands into those surfaces.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Emit structured execution events for run started, run completed, run failed, validation failed, conversion completed, and S3 upload completed or failed.
- Track the percentage of selected manual regression cases that can be expressed in the V1 schema without manual post-processing.
- Track pass, fail, blocked, and error counts per suite run so stakeholders can compare agent-run output with current manual regression expectations.
- Track the percentage of completed runs whose report and artifact manifest are successfully written to S3.
- Success for the experiment is demonstrated if the team can execute a representative regression suite end to end, inspect durable results, and identify whether the approach saves QA effort without introducing unacceptable ambiguity or operational burden.

## 13. Risks & Mitigations
- Ambiguous spreadsheet source material may convert poorly into executable YAML: preserve raw text, surface validation issues early, and require human review of converted cases before relying on them.
- Agent execution may misinterpret Torus workflows or assertions: provide repository docs as execution context and require explicit expected outcomes in case definitions.
- Secrets leakage through logs or stored reports: constrain stored metadata, redact sensitive values, and keep credential handling outside repository-managed artifacts.
- Browser-driven runs may fail for transient environment reasons unrelated to product regressions: capture blocked versus error states distinctly and include agent notes for triage.
- S3 upload or artifact-linking failures could make results hard to audit: keep local run outputs until upload succeeds and record upload failure status explicitly.

## 14. Open Questions & Assumptions
### Open Questions
- Which agent runtime and browser automation substrate will be the first supported execution target for V1?
- What minimum metadata is required to identify the target environment, release candidate, and credentials source for each run without creating a full environment model?
- What minimal structured execution inputs must an agent skill provide before a run can be prepared safely and deterministically?
- Should screenshots be mandatory for failed steps in V1, or optional artifacts captured only when supported by the chosen agent runtime?
- What retention policy and bucket layout should be used for S3-stored run reports and artifacts?

### Assumptions
- The experiment will start with a limited set of stable regression paths rather than the full Torus manual test inventory.
- QA and engineering can supply environment credentials through an out-of-band mechanism that is not part of this work item.
- Spreadsheet exports are available in a regular enough format that Python conversion tooling can create useful first-pass YAML definitions when the agent chooses to use it.
- Sequential execution by one agent is sufficient to evaluate the product value of the approach before adding orchestration or CI integration.

## 15. QA Plan
- Automated validation:
  - Python tests for schema validation, linting, conversion, report generation, and S3-upload boundary behavior.
  - Targeted execution tests that verify single-case and suite orchestration produce valid run-report JSON and terminal statuses.
  - Contract tests that ensure generated case, suite, and run documents match the documented schemas.
- Manual validation:
  - Convert a representative spreadsheet export into YAML and confirm a reviewer can reconcile the converted content with the source script.
  - Execute at least one authoring-focused and one delivery-focused regression flow against a non-production environment and inspect the resulting run reports.
  - Verify that stored results exclude secrets and that S3 objects can be retrieved using deterministic run metadata.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes

# Weighted Random Assignment Scope Manual QA

## Purpose

Verify both weighted-random assignment scopes through authoring, participating-section delivery, fallback, evidence, and cleanup. Use only test users and a disposable project in local, test, or QA.

## Setup

1. Create a project with one experiment-controlled Alternatives Group containing two mapped conditions and place that group twice on one practice page.
2. Publish the project and create two participating sections plus one nonparticipating section from that publication.
3. Enroll learner A in both participating sections, learner B in the first participating section, and learner C in the nonparticipating section.
4. Keep the experiment in draft while changing scope. Confirm a new weighted-random experiment defaults to **Same condition throughout this course section** and the details page displays the saved scope.
5. Confirm Thompson Sampling shows intervention scope only and rejects a forged `section_enrollment` submission.

## Section-And-Enrollment Scope

1. Activate the default-scoped weighted-random experiment for both participating sections.
2. As learner A in the first section, visit the page and record the rendered condition, assignment ID, assignment scope, and both placement exposure records.
3. Revisit the page and verify the condition and assignment ID are unchanged and no second canonical assignment is created.
4. Verify the canonical assignment has `assignment_scope = section_enrollment`, the current section/enrollment IDs, and no owning intervention ID.
5. Verify the two placements produce distinct exposure keys and intervention IDs while both reference the same assignment ID.
6. Visit as learner A in the second participating section. Verify a different canonical assignment row and enrollment ID are used; no assignment is shared across sections.
7. Visit as learner C in the nonparticipating section. Verify first-option fallback and no assignment or exposure evidence.

## Intervention Scope

1. Complete or archive the prior disposable experiment, create a new weighted-random experiment for the same group, select **Assign independently at each intervention**, and activate it.
2. Visit both placements as learner A. Verify each placement has its own non-null intervention-owned assignment and that revisits reuse each placement's assignment.
3. Verify assignment evidence says `assignment_scope = intervention` and exposure evidence retains the encountered intervention identity.
4. Do not require the two independently sampled conditions to differ; assert independent assignment identities instead.

## Concurrency And Revisit Observations

- Run two first requests for the same section/enrollment concurrently against different placements in section-and-enrollment scope. Verify both responses converge on one assignment ID and the canonical assignment count increases once.
- Repeat each page visit after refresh and in a second session. Verify no resampling occurs.
- If a configured condition cannot map at a later placement, verify deterministic fallback and no replacement assignment.

## Evidence To Capture

- Experiment details screenshot showing algorithm and saved scope.
- Assignment row counts and IDs for each experiment/section/enrollment.
- Assignment attribution showing scope and nullable intervention ownership for the canonical row.
- Two exposure attributions showing distinct intervention IDs/keys for the shared assignment.
- Nonparticipating fallback observation with zero experiment evidence.
- Any bounded assignment create/reuse/conflict/fallback telemetry needed to explain the run. Do not capture raw learner responses.

## Automated Companion Evidence

- `test/scenarios/delivery/ab_testing_delivery_runtime.scenario.yaml` covers real project authoring, publication, participating and nonparticipating sections, multiple learners, revisits, both weighted-random scopes, placement-specific exposure attribution, and one user represented by independent enrollments in two sections.
- `test/scenarios/delivery/ab_testing_delivery_runtime_test.exs` validates and executes that scenario without fixtures, factories, or mocks.
- Concurrency and forged-configuration proof remains in the focused experiment runtime/configuration and LiveView suites because the scenario runner is intentionally sequential.

## Cleanup

1. Archive the disposable experiments.
2. Remove or archive the disposable sections and test enrollments according to the environment's data policy.
3. Delete the disposable project only where supported and safe; otherwise mark it clearly as QA-only.
4. Record environment, build/commit, executor, date, pass/fail result, evidence links, and any defects. Never reuse production learner data.

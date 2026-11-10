# Certificate Scenario Automation Gap Closure - Delivery Plan

Scope and reference artifacts:
- Manual regression source: `docs/exec-plans/current/epics/automated_testing/certificates/regression-cert.md`
- Planning input: certificate scenario gap assessment derived from current certificate implementation and automated coverage
- Scenario skills to be used during implementation:
  - `build_scenario`
  - `extend_scenario`

## Scope
Deliver scenario-based automated coverage for the certificates feature by translating the manual regression cases in `regression-cert.md` into one or more YAML-driven `Oli.Scenarios` suites. The implementation must prefer scenario tests only for the new coverage being added. Where the current scenario DSL cannot express the required certificate workflows, the work includes reusable scenario infrastructure expansion needed to support those workflows.

This plan covers:
- certificate configuration and section-copy behavior that can be proven below the UI boundary
- learner progress toward certificate thresholds
- pending, approved, denied, earned, and distinction certificate states
- section customization and product-update behaviors that affect certificate requirements
- scenario DSL expansion required to make the above executable in `Oli.Scenarios`

This plan does not attempt to replace existing non-scenario tests that validate:
- browser-only preview fidelity for certificate design
- raw PDF rendering details
- controller-only download/verification pages

## Clarifications & Default Assumptions
- This work item does not currently include `prd.md` or `fdd.md`; this plan is based on the manual regression matrix and repository coverage assessment instead.
- The goal is not to duplicate all existing unit/live/controller tests in scenarios. The goal is to close workflow-level integration gaps with scenario coverage.
- Manual rows whose expected result is primarily visual UI rendering will be covered in scenarios through persisted domain assertions rather than browser rendering assertions.
- Certificate email expectations may be covered at the job/side-effect level if generic scenario assertion support for queued jobs is added; otherwise they remain partially covered by existing non-scenario tests.
- Scenario infrastructure changes must remain reusable and capability-oriented, not certificate-specific one-off test hooks.

## Current Coverage Summary
- Existing certificate automation is concentrated in service, changeset, controller, and LiveView tests.
- There is no certificate-focused scenario suite under `test/scenarios/`.
- Current scenario primitives do not support certificate setup, learner notes/discussions, graded certificate qualification workflows, instructor approval actions, or certificate-specific assertions.

## Gap Summary Mapped To Manual Regression
- `CERT SET UP A/B/F`:
  - Domain behavior exists, but there is no scenario support to configure certificate settings on a product/section and assert copied section certificate settings.
- `CERT SET UP C/D/E`:
  - Existing LiveView tests cover form behavior, but there is no scenario-level assertion of persisted design configuration.
- `CERT PROGRESS A/B/C/D/K`:
  - Existing unit/live tests cover parts of progress and qualification logic, but scenarios cannot currently create qualifying notes/discussions or complete graded certificate workflows end to end.
- `CERT PROGRESS E/F/G/H`:
  - Existing UI/component tests cover approval state transitions, but scenarios cannot perform instructor approve/deny actions or assert resulting certificate states.
- `CERT PROGRESS I/J`:
  - Existing tests cover certificate access and PDF generation in isolation, but there is no scenario proof that an earned certificate lifecycle yields the expected granted-certificate record and downloadable asset path.
- `CERT UPDATE A/B/C/D`:
  - Existing unit coverage validates section certificate snapshot helpers, but there is no scenario coverage proving add-materials and product-update behaviors across old vs new sections.

## Phase 1: Define Scenario Coverage Contract
- Goal: Convert the manual regression matrix into a scenario-oriented coverage map and identify the minimum reusable DSL capabilities required.
- Tasks:
  - [ ] Normalize each row in `regression-cert.md` into one of three buckets:
    - scenario-coverable now
    - scenario-coverable after DSL expansion
    - intentionally retained as non-scenario verification
  - [ ] Produce a case-to-scenario mapping for all certificate setup, progress, approval, distinction, and update rows.
  - [ ] Define the minimum representative scenario set needed to cover all scenario-appropriate rows without over-fragmenting the suite.
  - [ ] Confirm which expectations should be asserted as domain state, which as side effects, and which remain outside scenario scope.
  - [ ] Capture the proposed YAML authoring shape for each missing capability before implementation starts.
- Testing Tasks:
  - [ ] No code tests in this phase; review and lock the coverage map before DSL work begins.
  - [ ] Command(s): `none`
- Definition of Done:
  - Every manual certificate regression row has a documented automation disposition.
  - The planned scenario files and required DSL extensions are explicitly named.
- Gate:
  - Coverage map is reviewed and accepted as the execution contract for the implementation phases.
- Dependencies:
  - None.
- Parallelizable Work:
  - Review of current non-scenario coverage can proceed in parallel with drafting the case-to-scenario mapping.

## Phase 2: Expand Scenario DSL For Certificate Workflows
- Goal: Add the reusable `Oli.Scenarios` capabilities required to express certificate setup, learner progress, and instructor actions below the UI boundary.
- Tasks:
  - [ ] Use `extend_scenario` to design and implement a `certificate` directive that can configure certificate settings on a product or section.
  - [ ] Add learner-contribution support for certificate-relevant collaboration actions:
    - discussion posts
    - public class notes
  - [ ] Extend learner simulation to support scored-page certificate workflows, including starting, answering, and finalizing graded work where needed for certificate qualification.
  - [ ] Add certificate-focused assertions, preferably as a reusable `assert certificate` capability, covering:
    - threshold progress counts
    - granted certificate presence/absence
    - granted certificate state
    - distinction flag
    - required-assessment snapshot on a section certificate
  - [ ] Add instructor-side certificate action support for approve and deny transitions.
  - [ ] If needed for regression parity, add a generic queued-job assertion mechanism rather than a certificate-specific email assertion.
  - [ ] Update schema, parser, validator, engine wiring, handler implementations, and scenario docs together.
- Testing Tasks:
  - [ ] Add parser/validator tests for each new directive and assertion shape.
  - [ ] Add handler/runtime tests for success and failure paths.
  - [ ] Validate schema for representative certificate scenario YAML files as they are authored.
  - [ ] Command(s): `mix test test/scenarios test/oli/scenarios && mix run -e 'path = "test/scenarios/certificates/<file>.scenario.yaml"; case Oli.Scenarios.validate_file(path) do :ok -> IO.puts("schema ok"); {:error, errors} -> IO.inspect(errors, label: "schema_errors"); System.halt(1) end'`
- Definition of Done:
  - The DSL can express certificate setup, learner threshold progress, instructor actions, and certificate assertions without using fixtures or UI-only shortcuts.
  - New scenario capabilities are documented and covered by focused infrastructure tests.
- Gate:
  - A minimal representative certificate scenario parses, validates, and executes through the new infrastructure successfully.
- Dependencies:
  - Phase 1 coverage contract.
- Parallelizable Work:
  - Parser/schema work and handler/runtime work can proceed in parallel once directive shapes are agreed.

## Phase 3: Build Certificate Scenario Suites
- Goal: Author the certificate scenarios that replace the manually executed domain workflows with integrated `Oli.Scenarios` coverage.
- Tasks:
  - [ ] Use `build_scenario` to create `test/scenarios/certificates/setup_and_section_copy.scenario.yaml`.
  - [ ] Cover product certificate configuration and section-copy behavior corresponding to `CERT SET UP A/B/F`.
  - [ ] Create `test/scenarios/certificates/student_progress_pending_and_approval.scenario.yaml`.
  - [ ] Cover default progress, notes completion, failing assignment thresholds, pending approval, instructor approval, and earned state corresponding to `CERT PROGRESS A/B/C/D/G/H`.
  - [ ] Create `test/scenarios/certificates/distinction.scenario.yaml`.
  - [ ] Cover distinction upgrade behavior corresponding to `CERT PROGRESS K`.
  - [ ] Create `test/scenarios/certificates/section_customization_and_updates.scenario.yaml`.
  - [ ] Cover added-section-pages exclusion, product threshold updates, new-section adoption, and old-section snapshot preservation corresponding to `CERT UPDATE A/B/C/D`.
  - [ ] Add a scenario runner module for the certificates directory.
- Testing Tasks:
  - [ ] Validate each YAML file after every meaningful edit.
  - [ ] Run targeted scenario execution for each new file.
  - [ ] Add or update any companion hook modules only where scenario directives still require a narrow bridge into existing application behavior.
  - [ ] Command(s): `mix test test/scenarios/certificates` 
- Definition of Done:
  - The planned certificate scenario suite exists, passes, and covers the intended workflow rows from the manual regression source.
  - Scenario files remain readable, deterministic, and organized by workflow rather than by micro-case.
- Gate:
  - All new certificate scenarios pass consistently and provide coverage for the targeted regression rows.
- Dependencies:
  - Phase 2 DSL support completed.
- Parallelizable Work:
  - Individual scenario files can be authored in parallel once the shared DSL support is stable.

## Phase 4: Close Remaining Coverage Decisions And Integrate With Existing Test Layers
- Goal: Resolve the manual rows that cannot or should not be fully automated with scenarios and document the final coverage posture.
- Tasks:
  - [ ] Record explicit handling for `CERT SET UP C/D/E` as scenario-backed persistence assertions plus existing LiveView preview coverage.
  - [ ] Record explicit handling for `CERT PROGRESS I/J` as scenario-backed granted-certificate lifecycle assertions plus existing PDF/controller coverage.
  - [ ] Document any manual rows that still require non-scenario evidence and explain why.
  - [ ] Ensure the final plan clearly shows where scenario coverage ends and other automated layers remain authoritative.
  - [ ] Update any local work-item notes if implementation decisions materially narrow or widen scenario scope.
- Testing Tasks:
  - [ ] Run the new certificate scenario suite plus the most relevant targeted existing certificate tests to confirm no regressions at adjacent layers.
  - [ ] Command(s): `mix test test/scenarios/certificates test/oli/delivery/granted_certificates_test.exs test/oli_web/live/delivery/student/index_live_test.exs test/oli_web/components/delivery/students/certificates/state_approval_component_test.exs`
- Definition of Done:
  - The final automation posture for every manual regression row is documented and justified.
  - Scenario coverage integrates cleanly with existing non-scenario certificate test layers.
- Gate:
  - Team can point from each manual row to a concrete automated evidence source or a conscious out-of-scope decision.
- Dependencies:
  - Phase 3 scenario suite complete.
- Parallelizable Work:
  - Documentation of row disposition can proceed in parallel with targeted regression execution.

## Phase 5: Final Verification And Handoff
- Goal: Verify the scenario lane is stable, documented, and ready for implementation execution without ambiguity.
- Tasks:
  - [ ] Run the full certificate scenario suite and fix any determinism or readability issues.
  - [ ] Confirm scenario docs are updated for any new directives/assertions added in Phase 2.
  - [ ] Capture file inventory and execution commands for future maintainers.
  - [ ] Record any follow-on stories that should be split if implementation reveals additional reusable scenario infrastructure needs.
  - [ ] Prepare an implementation handoff note that explicitly calls for `extend_scenario` before `build_scenario`.
- Testing Tasks:
  - [ ] Run the certificate scenario suite as a standalone slice and within the broader scenario test surface.
  - [ ] Command(s): `mix test test/scenarios/certificates && mix test test/scenarios`
- Definition of Done:
  - Certificate scenario coverage plan is implementation-ready.
  - Required DSL expansion, scenario files, and verification commands are explicit and unambiguous.
- Gate:
  - Engineering can begin implementation without needing additional planning clarification.
- Dependencies:
  - Phases 1-4 complete.
- Parallelizable Work:
  - Scenario documentation updates and handoff note preparation can proceed while the final test sweep is running.

## Parallelization Notes
- Phase 1 should complete first to prevent rework in directive design and scenario slicing.
- Phase 2 is the critical path because the certificate scenario suite is blocked on DSL capability.
- Within Phase 2, generic collaboration-action support and certificate assertion support can be developed in parallel if they do not edit the same parser/schema regions at the same time.
- Phase 3 scenario authoring can split by workflow once the shared DSL contract is stable.
- Phase 4 documentation and adjacent regression runs can overlap with the tail of Phase 3.

## Phase Gate Summary
- Gate A: Manual certificate rows are mapped to scenario coverage, DSL expansion, or intentional non-scenario retention.
- Gate B: `Oli.Scenarios` can express certificate setup, learner progress, instructor actions, and certificate assertions.
- Gate C: Certificate scenario files exist and pass for setup, progress, distinction, and update workflows.
- Gate D: Remaining non-scenario rows have explicit automated evidence or documented rationale.
- Gate E: Final certificate scenario plan and verification commands are implementation-ready.

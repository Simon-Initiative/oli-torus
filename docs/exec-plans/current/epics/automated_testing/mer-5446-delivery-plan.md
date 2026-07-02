# MER-5446 Delivery Automation Plan

Scope and reference artifacts:
- Jira story: `MER-5446`
- Epic plan source: `docs/exec-plans/current/epics/automated_testing/plan.md`
- Related merged delivery precedents:
  - `MER-5438` CATA delivery coverage
  - `MER-5440` ordering delivery coverage

## Scope
Deliver Playwright-based learner delivery coverage for the activity types grouped under `MER-5446`:

- `oli_image_hotspot`
- `oli_image_coding`
- `oli_vlab`
- `oli_logic_lab`
- `oli_embedded`

The target layer is learner-facing delivery only. The tests should prove that an explicitly authored activity configuration behaves correctly for a student after publish/section/enrollment setup. Authoring UI creation flows are out of scope for this ticket.

## Working Agreement For This Ticket
- Prefer reusable helpers and shared setup over long one-off specs.
- Reuse existing student-delivery automation patterns before introducing new local logic.
- Extend shared helpers when a step or assertion pattern appears in more than one activity flow.
- Keep activity-specific logic in the individual spec only when it is truly unique to that activity type.

## Reuse-First Starting Points
Primary existing helpers and examples:

- Shared delivery helpers:
  - `assets/automation/tests/torus/student_delivery/support.ts`
- Merged reference specs:
  - `assets/automation/tests/torus/student_delivery/cata-delivery.spec.ts`
  - `assets/automation/tests/torus/student_delivery/ordering-delivery.spec.ts`
- Shared automation infrastructure:
  - `assets/automation/src/systems/torus/`
  - existing POMs and tasks under `assets/automation/src/systems/torus/pom/` and `assets/automation/src/systems/torus/tasks/`

Rule for this work item:
- if a login, navigation, seeding, course-entry, or common assertion step appears in two or more `MER-5446` specs, move it into a shared helper unless a stronger existing abstraction already exists elsewhere in `assets/automation/src/systems/torus/`

## Delivery Strategy
Use scenario-driven setup plus Playwright delivery interaction:

1. Seed a minimal project, page, activity, publication, section, and student enrollment with scenario YAML.
2. Log in as the learner in Playwright.
3. Open the seeded practice page from the learner delivery flow.
4. Interact with the activity as a student.
5. Assert that visible delivery behavior matches the authored configuration seeded in the scenario.

This means each activity test should validate authored intent through delivery behavior, for example:
- selecting the correct hotspot yields correct feedback
- providing the expected coding output yields correct evaluation
- submitting the correct vlab or logic-lab state yields the expected result

## Activity Order And Scope
Recommended implementation order:

1. `oli_image_hotspot`
2. `oli_image_coding`
3. `oli_vlab`
4. `oli_logic_lab`
5. `oli_embedded`

Rationale:
- `image_hotspot` is the cleanest first vertical and should define the reusable `MER-5446` template.
- `image_coding` is still local to Torus delivery, but more interactive.
- `vlab` and `logic_lab` introduce iframe/message-based complexity.
- `embedded` has the highest seeding/runtime uncertainty and should be handled after the shared base is stable.

## Per-Activity Test Intent
Each activity should have at least one positive learner path and, when practical, one negative learner path.

Baseline assertions:
- the activity renders in learner delivery
- the student can perform the intended interaction
- submit/evaluation completes through delivery
- visible feedback or evaluated state matches the seeded authored rules

Representative expectations:
- `image_hotspot`
  - correct hotspot selection yields correct feedback
  - incorrect or default path yields incorrect feedback
- `image_coding`
  - authored expected output/solution path yields correct evaluation
  - non-matching output yields incorrect evaluation
- `vlab`
  - learner interaction updates the expected input state and yields the authored evaluation result
- `logic_lab`
  - learner completion/score message path yields the authored evaluation result
- `embedded`
  - embedded runtime launches successfully in delivery and can prove the expected completion/evaluation behavior

## Regression Sheet Inputs
The shared release regression spreadsheet did not expose activity-specific rows for `image_hotspot`, `image_coding`, `vlab`, `logic_lab`, or `embedded`, but it did reinforce the expected generic learner-delivery checks for basic activity behavior.

Relevant manual coverage themes extracted from the regression sheet:
- start and finish a basic scored page
- ensure score is reported as expected
- verify no feedback or score is displayed before submitting on scored pages
- verify activity state is restored after revisiting the page
- verify reset behavior on unscored pages
- verify hints are delivered where applicable

How this affects `MER-5446`:
- the first implementation pass should prioritize render, interaction, submit/evaluation, and authored feedback/score behavior for each activity type
- revisit/state-restore, reset, and hints should be considered secondary coverage adds when the activity type supports them and the interaction remains deterministic
- no regression-sheet evidence currently suggests this ticket should include authoring UI creation or broader section-level assessment-setting flows

## Scenario Authoring Guidance
Use scenario seed as the source of truth for authored configuration. Do not build the activity through authoring UI in these tests.

Each scenario should:
- create a dedicated project and practice page
- create the target activity with explicit correct and incorrect response behavior
- place the activity on the page
- publish the project
- create one or more sections
- create and enroll a learner
- return the section slug(s) needed by Playwright

Where possible, keep each scenario narrow and deterministic rather than creating one giant multi-activity world.

## Risks And Constraints
- `oli_embedded` currently has no obvious scenario seed precedent comparable to the other activity types in this ticket.
- `oli_logic_lab` may depend on the effective `ACTIVITY_LOGICLAB_URL` configuration in the runtime environment.
- `oli_vlab` and `oli_logic_lab` both use iframe/message-based delivery, so synchronization and assertion shape may require shared helper support.
- `MER-5446` should not absorb authoring UI coverage that belongs to Lane 2 or Lane 3.

## Implementation Phases
### Phase 1: Establish the shared pattern
- add the first scenario + spec pair for `oli_image_hotspot`
- reuse existing student-delivery helpers
- extract any immediately obvious helper gaps into shared support

### Phase 2: Expand to local interactive activities
- add `oli_image_coding`
- consolidate any repeated activity-opening, submission, or feedback assertion helpers

### Phase 3: Expand to iframe/message activities
- add `oli_vlab`
- add `oli_logic_lab`
- extract any cross-iframe synchronization helpers only if they are truly shared

### Phase 4: Close the highest-risk case
- evaluate the feasible seeding/runtime shape for `oli_embedded`
- implement delivery coverage if the scenario/runtime setup can be made deterministic within this ticket
- if not, document the concrete blocker and isolate any reusable support discovered during the attempt

## Test Strategy
- validate scenario structure before or during implementation
- run targeted Playwright coverage for each added spec
- keep verification focused on the smallest relevant slice while iterating

Minimum expected verification during implementation:
- scenario file is valid and seeds successfully
- target Playwright spec passes locally
- shared helper refactors do not break existing `student_delivery` specs

## Done Criteria
- `MER-5446` has delivery coverage for the intended activity types, or any unimplemented activity has a documented concrete blocker
- tests validate authored intent through learner-visible delivery behavior
- shared helper reuse is explicit and any repeated setup/navigation logic has been centralized where appropriate
- the resulting specs follow the precedent set by existing `student_delivery` automation instead of introducing a parallel ad hoc style

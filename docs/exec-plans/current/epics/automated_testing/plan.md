# Fully Automated Testing for Continuous Deployment — High-Level Plan

Context references:
- `docs/exec-plans/current/epics/automated_testing/overview.md`
- `docs/exec-plans/current/epics/automated_testing/gaps.md`
- `docs/exec-plans/current/epics/automated_testing/current_coverage.md`
- `docs/exec-plans/current/epics/automated_testing/ui_business_logic_analysis.md`

## Why We Are Organizing By Lanes

This plan is organized by the product areas that still require manual release testing today. The goal is not to create lanes around testing technology. The goal is to eliminate manual verification lane by lane until a release can be certified entirely by automated evidence.

Each lane groups stories around a system behavior or user workflow that must become fully automatable before we can move from release-by-ceremony to continuous deployment.

## Planning Goal

Achieve a release posture where:

- all critical release behaviors are validated automatically
- no manual QA pass is required before deploy
- automation is layered appropriately across scenario tests, LiveView tests, and targeted Playwright coverage
- browser automation is used only where browser or cross-system behavior is the thing being validated

## Assumptions

- `Oli.Scenarios` remains the primary integration-testing mechanism for application-layer workflows.
- Playwright is reserved for browser-critical, client-heavy, and LMS-integrated workflows that cannot be proven adequately below the UI boundary.
- Where scenario coverage is blocked by missing directives or LiveView-owned workflow logic, the owning story should include the required DSL, engine, and service-boundary expansion as part of delivering the test.
- Lane ordering should optimize for release-risk reduction first, then breadth of coverage.

## Lane Summary

- Lane 1: LMS and LTI Interoperability
  - Automates LMS-originated launch, section-creation, and grade passback behaviors that are among the highest-value manual release checks today.
- Lane 2: Basic Page Authoring
  - Covers the core non-adaptive authoring flows that authors use to build and revise course content.
- Lane 3: Adaptive Page Authoring
  - Covers the separate adaptive authoring surface and its dynamic authoring behaviors.
- Lane 4: Basic Page Delivery and Activity Use
  - Covers learner-facing delivery of standard pages and the built-in activity set that currently lacks broad automated coverage.
- Lane 5: Adaptive Page Delivery
  - Covers adaptive lesson launch, traversal, rendering, and result behavior.
- Lane 6: Scheduling, Gating, and Assessment Controls
  - Covers instructor configuration that changes what learners can see, when they can see it, and under what rules.
- Lane 7: Graded Assessment Lifecycle and Grade Outcomes
  - Covers graded attempt lifecycle, finalization, review, and score propagation behavior.
- Lane 8: Instructor and Student Operational Surfaces
  - Covers dashboards, analytics, section operations, and other delivery-side workflows currently validated manually.
- Lane 9: Collaboration and Community Features
  - Covers discussions, annotations, and participation workflows that affect delivery behavior and release confidence.
- Lane 10: Commerce, Access, and External Service Gates
  - Covers payment, paywall, entitlement, and other external-service-driven access flows that can block or alter delivery.

## Lane 1: LMS and LTI Interoperability

### Scope
- Automate the LMS-mediated workflows that currently require manual validation against Canvas and LTI behavior.
- Cover both Torus-side protocol handling and real browser-mediated LMS journeys.

### Story Focus
1. LTI launch protocol simulator for Torus tool-side launch validation
2. LTI AGS and grade passback simulator for Torus passback validation
3. Automated Canvas-to-Torus LTI launch smoke test (Playwright)
4. Automated Canvas-to-Torus grade passback smoke test (Playwright)
5. Automated instructor first-launch and course section creation test (Playwright)
6. Automated LMS-originated learner launch and enrollment-state validation (Playwright)
7. Automated deep-linking and external-tool launch validation (Playwright)
8. Automated LTI settings and deployment regression coverage (Playwright)

## Lane 2: Basic Page Authoring

### Scope
- Eliminate manual testing for standard page authoring workflows used in normal course construction.
- Cover the authoring behaviors that are partly represented in scenarios today but still require browser validation for confidence.

### Story Focus
1. Automated project creation and curriculum bootstrap coverage, including any scenario service extraction needed to make curriculum bootstrap and page-management flows executable below the UI (Playwright)
2. Automated page creation, edit, save, and reopen coverage (Playwright)
3. Automated curriculum move, reorder, remove, and duplicate coverage (Playwright)
4. Automated activity insertion and page composition coverage (Playwright)
5. Automated objectives, tags, and bank-selection authoring coverage (Playwright)
6. Automated publication-ready validation of basic authored content (Playwright)
7. Automated regression coverage for Google Docs import and authoring-side content ingestion (Playwright)

## Lane 3: Adaptive Page Authoring

### Scope
- Eliminate manual testing for the advanced adaptive authoring surface, which is currently a major Sev 1 gap.
- Cover authoring flows that are distinct from basic page editing and currently live heavily in the client/UI layer.

### Story Focus
1. Automated adaptive page creation and author entry coverage (Playwright)
2. Automated adaptive screen editing and save/reopen coverage (Playwright)
3. Automated dynamic-link authoring coverage (Playwright)
4. Automated adaptive trigger and progression-rule authoring coverage, including any required scenario DSL or application-service expansion to express those workflows outside the LiveView layer (Playwright)
5. Automated adaptive activity configuration coverage (Playwright)
6. Automated adaptive preview and author-to-preview handoff coverage (Playwright)
7. Automated adaptive duplication and internal-reference integrity coverage (Playwright)

## Lane 4: Basic Page Delivery and Activity Use

### Scope
- Eliminate manual testing for standard learner-facing page delivery and core activity interaction.
- Prioritize the activity ecosystem and learner flows that have weak or no broad automation today.

### Story Focus
1. Automated standard page launch and learner session coverage (Playwright)
2. Automated multiple choice and short answer delivery regression suite hardening
3. Automated check-all-that-apply delivery coverage, including any directive expansion needed for scenario-driven learner interaction and assertion support (Playwright)
4. Automated ordering activity delivery coverage, including any directive expansion needed for scenario-driven learner interaction and assertion support (Playwright)
5. Automated multi-input activity delivery coverage, including any directive expansion needed for scenario-driven learner interaction and assertion support (Playwright)
6. Automated file-upload, likert, and discussion-style activity delivery coverage, including any directive expansion needed for scenario-driven learner interaction and assertion support (Playwright)
7. Automated embedded, image-hotspot, image-coding, logic-lab, and vlab delivery coverage (Playwright)
8. Automated external-tool activity delivery coverage (Playwright)
9. Automated learner progress and proficiency assertion coverage for standard delivery (Playwright)

## Lane 5: Adaptive Page Delivery

### Scope
- Eliminate manual testing for adaptive lesson delivery behavior, which is materially different from standard page delivery.
- Validate adaptive launch, traversal, state transitions, and learner-visible outcomes.

### Story Focus
1. Automated adaptive page launch and session bootstrap coverage, including the scenario directives and execution support needed to launch adaptive delivery outside the browser (Playwright)
2. Automated adaptive page traversal and progression coverage, including the scenario directives and assertions needed to prove adaptive outcomes (Playwright)
3. Automated adaptive iframe rendering and embedded-content coverage (Playwright)
4. Automated adaptive scoring and completion-state coverage (Playwright)
5. Automated adaptive learner-response capture and state-persistence coverage (Playwright)
6. Automated adaptive preview-to-delivery parity regression coverage (Playwright)

## Lane 6: Scheduling, Gating, and Assessment Controls

### Scope
- Eliminate manual testing for instructor configuration that gates learner access and changes delivery behavior.
- Cover the configuration surfaces called out as both scenario gaps and UI-business-logic hotspots, with any needed scenario and service-boundary expansion delivered inside the owning stories.

### Story Focus
1. Automated section schedule creation and due-date behavior coverage, including any scenario directives needed for schedule mutation and learner-visible assertions
2. Automated content gating rule creation and update coverage, including any scenario directives and service extraction needed to move gating workflows below the UI boundary
3. Automated graded versus ungraded gate eligibility coverage
4. Automated assessment setting configuration coverage, including any scenario directives and service extraction needed to make assessment-setting workflows scenario-addressable
5. Automated student exception create, update, and removal coverage, including any scenario directives and service extraction needed to make section-level overrides scenario-addressable
6. Automated learner visibility and access-behavior assertions under schedule and gating rules
7. Automated auto-submit and deadline-expiration behavior coverage

## Lane 7: Graded Assessment Lifecycle and Grade Outcomes

### Scope
- Eliminate manual testing for graded pages and assessments beyond simple question submission.
- Cover the score, review, and finalization behaviors that matter directly to release confidence.

### Story Focus
1. Automated graded page attempt start coverage, including any scenario directives needed to create and control graded attempts
2. Automated graded answer submission and score accumulation coverage, including any scenario directives needed for graded submission flows
3. Automated attempt finalization and review-mode coverage, including any scenario directives and delivery-service extraction needed to prove finalize and review behavior below the UI
4. Automated late-submit, grace-period, and deadline-expiration coverage
5. Automated score-as-you-go and batch-scoring coverage
6. Automated gradebook update and LMS grade-update side-effect coverage
7. Automated regression suite for graded-practice differences and edge cases

## Lane 8: Instructor and Student Operational Surfaces

### Scope
- Eliminate manual testing for the high-value delivery-side workflows outside direct lesson taking.
- Cover dashboards, analytics, reporting, and operational section workflows that are meaningful release blockers.

### Story Focus
1. Automated instructor dashboard correctness coverage
2. Automated insights and analytics data-generation coverage
3. Automated dataset generation and reporting-job coverage
4. Automated student dashboard, assignments, and schedule-view coverage
5. Automated onboarding, explorations, and certificate-view coverage
6. Automated source-material update and publication-diff workflow coverage
7. Automated enrollment transfer and section-operation workflow coverage, including any scenario directives needed for enrollments and instructor-managed delivery mutations

## Lane 9: Collaboration and Community Features

### Scope
- Eliminate manual testing for collaborative delivery features that affect student and instructor experience.
- Cover workflows that currently live partly in lesson and community UI state handling.

### Story Focus
1. Automated annotation creation, reply, and reaction coverage
2. Automated lesson-level collaboration visibility and anonymity-rule coverage
3. Automated discussion participation and moderation coverage
4. Automated community interaction and participation-state coverage
5. Automated collaboration regression coverage across delivery contexts

## Lane 10: Commerce, Access, and External Service Gates

### Scope
- Eliminate manual testing for access-control behavior that depends on payment, entitlement, or other external-service constraints.
- Ensure release validation includes the non-academic workflows that can block delivery.

### Story Focus
1. Automated paywall setup and section access-rule coverage
2. Automated entitlement and purchase-state coverage
3. Automated payment-provider integration smoke coverage
4. Automated restricted-access delivery regression coverage
5. Automated certificate and access-unlock workflow coverage

## Suggested Global Execution Shape

1. Start Lane 1 and Lane 2 first because LMS interoperability and core authoring coverage eliminate high-value manual release work immediately.
2. Run Lane 4 next alongside the tail of Lane 2 so standard learner delivery and built-in activity automation expand in parallel with authoring coverage.
3. Run Lane 3 and Lane 5 as a parallel adaptive track because adaptive authoring and delivery are both major Sev 1 gaps.
4. Run Lane 6 and Lane 7 after the foundational delivery paths are in place, since they depend on robust attempt, scheduling, and section-state automation.
5. Run Lane 8 in parallel as data- and operations-focused automation once the underlying workflows can generate trusted state.
6. Complete Lane 9 and Lane 10 before declaring manual release testing eliminated, since both still represent real release-risk surfaces.

## Exit Criteria For This Epic

- Every release-critical manual QA checklist item maps to one or more automated tests.
- LMS launch, section creation, and grade passback are executable automatically on demand.
- Standard authoring, adaptive authoring, standard delivery, and adaptive delivery all have release-grade automated coverage.
- Scheduling, graded assessment behavior, and instructor-side operational workflows are validated automatically.
- Manual release testing is reduced to exploratory validation only, then removed as a deploy gate.

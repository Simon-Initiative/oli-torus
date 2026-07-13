# Paywall And Provider Smoke - Delivery Plan

Scope and reference artifacts:
- Informal source context: `docs/exec-plans/current/epics/automated_testing/paywall-and-provider-smoke/informal.md`
- PRD: `docs/exec-plans/current/epics/automated_testing/paywall-and-provider-smoke/prd.md`
- FDD: `docs/exec-plans/current/epics/automated_testing/paywall-and-provider-smoke/fdd.md`
- Epic lane source: `docs/exec-plans/current/epics/automated_testing/plan.md`
- Testing strategy: `docs/exec-plans/current/epics/automated_testing/overview.md`

## Scope
Deliver one combined automation lane for paid-course learner behavior by:

- expanding `Oli.Scenarios` so paid-course setup can be expressed deterministically from project -> product -> section flows and from section-level overrides
- adding deterministic scenario support for institution discount setup
- adding Playwright browser coverage for the visible student experience on paid sections before payment
- adding Playwright smoke coverage for learner access unlock after:
  - payment code redemption
  - simulated Stripe success handling
  - simulated Cashnet success handling

This plan covers:

- unpaid learner without grace period
- unpaid learner with active grace period
- unpaid learner with expired grace period
- institution discount applies
- institution discount does not apply
- guest learner on paid section
- payment code unlock
- Stripe simulated unlock
- Cashnet simulated unlock

This plan does not attempt to:

- automate real third-party hosted checkout UIs
- replace existing lower-level paywall or provider tests
- cover broader entitlement or purchase-state behavior outside this paid-course workflow slice

## Clarifications & Default Assumptions
- This is one work item and one PR, even though it absorbs requirements that originally came from more than one Jira story.
- The inherited paid-section browser cases must use a standalone scenario bootstrap file per case.
- The inherited paywall matrix must preserve the full project -> product -> section world-creation shape.
- Playwright validates browser-visible learner behavior; scenario bootstrap creates the world; existing Torus payment endpoints remain authoritative for payment-state transitions.
- Product-level paywall fields establish defaults for sections created from that product.
- Section-level paywall fields explicitly override inherited defaults when a case needs section-specific behavior.
- Discount coverage minimum is one deterministic discount type. Default implementation target is percentage discount coverage unless fixed-amount coverage is materially cheaper.
- The implemented split is section-level DSL for institution-qualified pricing, plus deterministic hooks for guest enrollment and provider-pending payment setup.

## Phase 1: Lock The Coverage Contract And File Topology
- Goal: Translate the combined requirements into an executable automation contract and identify the exact scenario/bootstrap and Playwright file inventory.
- Tasks:
  - [ ] Map each learner-visible workflow to a concrete automation case and confirm it fits one of the required buckets:
    - unpaid without grace
    - active grace
    - expired grace
    - discount applies
    - discount does not apply
    - guest learner
    - payment code unlock
    - Stripe simulated unlock
    - Cashnet simulated unlock
  - [ ] Define the intended scenario bootstrap file inventory with one bootstrap file per Playwright case.
  - [ ] Define the intended Playwright spec inventory and group related cases where helper reuse is beneficial without merging bootstrap worlds.
  - [ ] Confirm the learner-visible assertions required for each case, especially:
    - payment-required messaging
    - course fee
    - correct payment method controls
    - visible grace-period banner
    - visible pay-now path
    - account-required guest restriction messaging
    - before-and-after unlock access behavior
  - [ ] Confirm the minimum backend or helper additions needed beyond current Torus endpoints.
- Planned file inventory for Phase 1 lock:
  - Scenario bootstrap files:
    - `assets/automation/tests/torus/student_payment/unpaid-no-grace.scenario.yaml`
    - `assets/automation/tests/torus/student_payment/unpaid-active-grace.scenario.yaml`
    - `assets/automation/tests/torus/student_payment/unpaid-expired-grace.scenario.yaml`
    - `assets/automation/tests/torus/student_payment/discount-qualifying.scenario.yaml`
    - `assets/automation/tests/torus/student_payment/discount-non-qualifying.scenario.yaml`
    - `assets/automation/tests/torus/student_payment/guest-paid-section.scenario.yaml`
    - `assets/automation/tests/torus/student_payment/payment-code-unlock.scenario.yaml`
    - `assets/automation/tests/torus/student_payment/stripe-unlock.scenario.yaml`
    - `assets/automation/tests/torus/student_payment/cashnet-unlock.scenario.yaml`
  - Playwright specs and support:
    - `assets/automation/tests/torus/student_payment/paywall-ui.spec.ts`
    - `assets/automation/tests/torus/student_payment/payment-unlock.spec.ts`
    - `assets/automation/tests/torus/student_payment/support.ts`
  - Scenario DSL and runtime files likely touched:
    - `lib/oli/scenarios/directive_types.ex`
    - `lib/oli/scenarios/directive_parser.ex`
    - `lib/oli/scenarios/directive_validator.ex`
    - `lib/oli/scenarios/engine.ex`
    - `lib/oli/scenarios/directives/product_handler.ex`
    - `lib/oli/scenarios/directives/section_handler.ex`
    - `priv/schemas/v0-1-0/scenario.schema.json`
    - `test/support/scenarios/docs/products.md`
    - `test/support/scenarios/docs/sections.md`
    - `test/scenarios/student_payment/hooks.ex`
    - `lib/oli_web/controllers/playwright_session_controller.ex`
    - optional new scenario docs file if the paywall surface warrants it
- Planned case-to-file mapping for Phase 1 lock:
  - `unpaid-no-grace`
    - bootstrap: `unpaid-no-grace.scenario.yaml`
    - spec: `paywall-ui.spec.ts`
  - `unpaid-active-grace`
    - bootstrap: `unpaid-active-grace.scenario.yaml`
    - spec: `paywall-ui.spec.ts`
  - `unpaid-expired-grace`
    - bootstrap: `unpaid-expired-grace.scenario.yaml`
    - spec: `paywall-ui.spec.ts`
  - `discount-qualifying`
    - bootstrap: `discount-qualifying.scenario.yaml`
    - spec: `paywall-ui.spec.ts`
  - `discount-non-qualifying`
    - bootstrap: `discount-non-qualifying.scenario.yaml`
    - spec: `paywall-ui.spec.ts`
  - `guest-paid-section`
    - bootstrap: `guest-paid-section.scenario.yaml`
    - spec: `paywall-ui.spec.ts`
  - `payment-code-unlock`
    - bootstrap: `payment-code-unlock.scenario.yaml`
    - spec: `payment-unlock.spec.ts`
  - `stripe-unlock`
    - bootstrap: `stripe-unlock.scenario.yaml`
    - spec: `payment-unlock.spec.ts`
  - `cashnet-unlock`
    - bootstrap: `cashnet-unlock.scenario.yaml`
    - spec: `payment-unlock.spec.ts`
- Testing Tasks:
  - [ ] No code tests in this phase; establish the execution contract first.
  - [ ] Command(s): `none`
- Definition of Done:
  - Every required learner workflow is mapped to a deterministic case with a known bootstrap file and expected visible assertions.
  - The work item has an explicit file topology for scenario YAML, handler additions, and Playwright specs.
- Gate:
  - The planned case matrix fully covers the paid-section requirements with no unresolved ambiguity about what each case must prove.
- Dependencies:
  - Existing informal, PRD, and FDD documents
- Parallelizable Work:
  - Bootstrap file planning and Playwright spec grouping can be reasoned about in parallel once the case matrix is written.

## Phase 2: Expand Scenario DSL For Paid Course And Discount Setup
- Goal: Add the reusable `Oli.Scenarios` capabilities required to author deterministic paid-course worlds for the browser cases.
- Tasks:
  - [ ] Extend `ProductDirective` to support:
    - `requires_payment`
    - `amount`
    - `payment_options`
    - `has_grace_period`
    - `grace_period_days`
    - `grace_period_strategy`
    - `pay_by_institution`
  - [ ] Extend `SectionDirective` to support the same paywall fields.
  - [ ] Implement documented precedence so section-level values override product-derived defaults.
  - [ ] Update parser, validator, engine wiring, handlers, and schema validation so the new fields are fully supported end to end.
  - [ ] Add section-level institution targeting so a scenario can resolve institution-qualified pricing through existing paywall rules.
  - [ ] Add a narrow scenario hook module only for setup-only states that are awkward or inappropriate to model as reusable YAML primitives, specifically guest enrollment and provider-pending payment setup.
  - [ ] Update scenario docs for products, sections, and any new directive doc needed for discounts.
- Testing Tasks:
  - [ ] Add parser and validator tests for new product and section fields.
  - [ ] Add schema validation tests for new paywall and discount YAML shapes.
  - [ ] Add handler/runtime tests for:
    - product paywall setup
    - section paywall setup
    - precedence behavior
    - discount creation success and failure
  - [ ] Validate representative bootstrap YAML files as they are authored.
  - [ ] Command(s): `mix test test/scenarios/validation test/oli/scenarios`
- Definition of Done:
  - YAML can express paid-course setup and institution-qualified pricing for the core covered cases, while hooks remain limited to guest and provider-pending setup.
  - Product-to-section inheritance and section override behavior are implemented and covered.
- Gate:
  - A representative bootstrap scenario for a paid product, paid section, enrolled learner, and institution discount parses, validates, and executes successfully.
- Dependencies:
  - Phase 1 file and case contract
- Parallelizable Work:
  - Parser/schema work and handler/runtime work can proceed in parallel after field contracts are fixed.

## Phase 3: Build Scenario Bootstrap Files For Paid-Course Cases
- Goal: Author the standalone scenario bootstrap files that seed the browser worlds for all required learner cases.
- Tasks:
  - [ ] Create one bootstrap scenario file for unpaid learner without grace period.
  - [ ] Create one bootstrap scenario file for active grace-period learner.
  - [ ] Create one bootstrap scenario file for expired grace-period learner.
  - [ ] Create one bootstrap scenario file for qualifying institution discount.
  - [ ] Create one bootstrap scenario file for non-qualifying institution discount.
  - [ ] Create one bootstrap scenario file for guest learner on a paid section.
  - [ ] Create one bootstrap scenario file for payment code unlock.
  - [ ] Create one bootstrap scenario file for Stripe simulated unlock.
  - [ ] Create one bootstrap scenario file for Cashnet simulated unlock.
  - [ ] Keep each bootstrap world minimal while preserving the required project -> product -> section shape.
  - [ ] Seed any required product and section paywall variations explicitly rather than relying on incidental defaults.
- Testing Tasks:
  - [ ] Validate each YAML file structurally after creation.
  - [ ] Run targeted scenario execution for each bootstrap file or a representative grouped runner where available.
  - [ ] Command(s): `mix test test/scenarios`
- Definition of Done:
  - Every required browser case has a standalone scenario bootstrap file that creates a deterministic paid-course world.
- Gate:
  - Bootstrap files execute successfully and provide all data needed by Playwright without browser-side world creation.
- Dependencies:
  - Phase 2 scenario support completed
- Parallelizable Work:
  - Individual bootstrap YAML files can be authored in parallel once the shared directive support is stable.

## Phase 4: Implement Playwright Coverage For Pre-Payment Learner Behavior
- Goal: Add the browser-visible assertions for the inherited paywall and access-rule matrix.
- Tasks:
  - [ ] Add or extend Playwright helpers for:
    - learner login
    - scenario seeding
    - section navigation
    - paywall guard assertions
    - grace-period assertions
    - guest-restriction assertions
  - [ ] Implement the no-grace paid-section case verifying:
    - redirect to payment-required UI
    - visible payment-required messaging
    - course fee
    - correct payment method controls
  - [ ] Implement the active grace-period case verifying:
    - learner can access course content
    - visible grace-period banner
    - visible pay-now path
  - [ ] Implement the expired grace-period case verifying:
    - learner cannot access course content
    - payment-required UI is shown instead of the grace banner
  - [ ] Implement the qualifying institution discount case verifying discounted price display.
  - [ ] Implement the non-qualifying institution discount case verifying standard price display.
  - [ ] Implement the guest learner case verifying the learner is blocked from a normal payment flow and sees account-required messaging.
- Testing Tasks:
  - [ ] Run the new Playwright specs for the pre-payment cases in isolation.
  - [ ] Stabilize selectors or helpers if assertions rely on brittle text or DOM structure.
  - [ ] Command(s): `cd assets/automation && npx playwright test tests/torus/student_payment/paywall-ui.spec.ts`
- Definition of Done:
  - All required learner-visible pre-payment cases pass through Playwright with isolated scenario worlds.
- Gate:
  - The browser suite proves the visible student experience defined by the original paid-section matrix rather than only backend state transitions.
- Dependencies:
  - Phase 3 bootstrap files complete
- Parallelizable Work:
  - Grace-period, discount, and guest cases can be implemented in parallel once shared helpers exist.

## Phase 5: Implement Playwright Smoke Coverage For Post-Payment Unlock
- Goal: Prove the learner becomes unblocked after Torus accepts each supported payment path in scope.
- Tasks:
  - [ ] Add shared helpers for post-payment verification:
    - assert learner is blocked before payment
    - execute payment path
    - re-enter or refresh section access
    - assert learner can now access course content
  - [ ] Implement payment code unlock by driving the real learner-facing payment code path.
  - [ ] Implement Stripe simulated unlock by:
    - creating the pending payment through scenario setup hooks
    - posting the simulated success payload that matches current Torus expectations
    - verifying learner access unlock
  - [ ] Implement Cashnet simulated unlock by:
    - creating the pending payment ref through scenario setup hooks
    - posting the simulated success payload that matches current Torus expectations
    - verifying learner access unlock
  - [ ] Keep the simulated payload shapes aligned with current Torus controller contracts and documented assumptions.
- Testing Tasks:
  - [ ] Run the unlock specs in isolation.
  - [ ] Add or extend targeted backend tests only if helper extraction introduces uncovered boundary logic.
  - [ ] Command(s): `cd assets/automation && npx playwright test tests/torus/student_payment/payment-unlock.spec.ts`
- Definition of Done:
  - The browser suite proves learner access is blocked before payment and unlocked after each supported payment path is accepted by Torus.
- Gate:
  - Unlock coverage exercises real Torus payment-state transitions rather than direct database mutation or test-only bypasses.
- Dependencies:
  - Phase 3 bootstrap files complete
  - Shared helpers from Phase 4 may be reused
- Parallelizable Work:
  - Payment code, Stripe, and Cashnet unlock cases can be implemented in parallel once the common before-and-after assertion helper exists.

## Phase 6: Documentation, Validation, And Final Coverage Check
- Goal: Make the work item maintainable, validate the final automation posture, and prepare implementation handoff evidence.
- Tasks:
  - [ ] Update scenario docs for new paywall and discount directives.
  - [ ] Record the final scenario bootstrap file inventory and Playwright spec inventory in the work item if implementation diverges from planning.
  - [ ] Verify that the final docs still reflect:
    - project -> product -> section bootstrap requirement
    - one scenario bootstrap file per Playwright case
    - minimum discount coverage
    - supported unlock paths
  - [ ] Record any intentional residual gaps outside this slice, if discovered during implementation.
  - [ ] Prepare implementation notes on selector stability, config assumptions, and any known environment prerequisites.
- Testing Tasks:
  - [ ] Run the scenario validation and targeted scenario tests for the new bootstrap capabilities.
  - [ ] Run the targeted Playwright suite for all new paid-course cases.
  - [ ] Run harness validation commands for the work item.
  - [ ] Command(s): `mix test test/scenarios/validation test/oli/scenarios`
  - [ ] Command(s): `cd assets/automation && npx playwright test tests/torus/student_payment`
- Definition of Done:
  - Scenario support, bootstrap files, Playwright cases, and documentation are aligned and implementation-ready.
  - Validation steps and execution commands are explicit for future maintainers.
- Gate:
  - A contributor can understand the paid-course automation surface from the work-item docs and rerun the intended validation without reverse-engineering the implementation.
- Dependencies:
  - Phases 1 through 5
- Parallelizable Work:
  - Documentation cleanup can overlap with late-stage stabilization once the case inventory is stable.

## Parallelization Notes
- Phase 1 should complete first so scenario and Playwright file boundaries do not drift.
- In Phase 2, parser/schema updates and handler/runtime updates can proceed in parallel once the paywall and discount field contract is fixed.
- In Phase 3, individual bootstrap YAML files can be authored in parallel after the scenario DSL is stable.
- In Phase 4 and Phase 5, shared Playwright helpers should be implemented first; individual browser cases can then split across contributors.
- Avoid parallel edits to the same scenario core files (`directive_types.ex`, parser, validator, schema) without clear ownership.

## Phase Gate Summary
- Gate A: The case matrix and file inventory cover all required paid-course learner workflows.
- Gate B: `Oli.Scenarios` can express paid product, paid section, section override, and institution discount setup deterministically.
- Gate C: Every required browser case has its own standalone bootstrap file with project -> product -> section world creation.
- Gate D: Playwright proves the visible pre-payment learner experience across no-grace, active-grace, expired-grace, discount, and guest cases.
- Gate E: Playwright proves learner unlock after payment code redemption and simulated Stripe and Cashnet success handling.
- Gate F: Documentation and validation steps are aligned with the implemented automation surface.

## Decision Log
### 2026-07-13 - Record Actual DSL And Hook Boundary
- Change: Updated the plan to reflect the implemented boundary of section-level institution support in the DSL and hooks for guest plus provider-pending setup.
- Reason: The implementation intentionally avoided a new top-level discount directive and also avoided provider create-intent/form requests from Playwright.
- Evidence: `lib/oli/scenarios/directive_types.ex`, `lib/oli/scenarios/directives/section_handler.ex`, `test/scenarios/student_payment/hooks.ex`, `assets/automation/tests/torus/student_payment/payment-unlock.spec.ts`
- Impact: Future contributors can follow the implemented path without reverse-engineering why some setup lives in YAML and some in hooks.

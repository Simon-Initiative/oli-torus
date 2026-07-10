# Paywall And Provider Smoke - Product Requirements Document

## 1. Overview
Paywall And Provider Smoke adds automated browser coverage for paid-course access behavior in Torus, including both the student-facing paywall experience before payment and the learner access unlock behavior after payment is recognized. The work item combines the paywall UI and access-rule scope with the payment-completion smoke scope into one planning and implementation lane so the shared scenario bootstrap and Playwright infrastructure are designed once and reused consistently.

This work must prove the end-to-end learner journey for paid delivery:

- a learner is blocked when payment is required and access conditions are not satisfied
- the learner sees the correct student-facing UI for the current paywall state
- after Torus accepts a supported payment path, the learner can access the section

Supported payment paths in scope for this work item are:

- payment code redemption
- Stripe success handling with simulated provider responses
- Cashnet success handling with simulated provider responses

For the inherited paywall browser cases, each case must bootstrap its own world through the full project -> product -> section flow:

- create a project
- derive or publish a product from that project
- configure paywall state on the product and or resulting section as needed by the case
- create the section from that product
- create and enroll the learner in scenario setup

## 2. Background & Problem Statement
Lane 10 of the automated testing epic exists to eliminate manual release testing for access control that depends on payment, entitlement, or external-service constraints. Today, Torus already contains paywall enforcement, payment guard rendering, grace-period logic, institution discount logic, guest restrictions, payment code redemption, and direct-payment provider integrations. However, automated coverage is fragmented across lower-level tests and does not yet provide a browser-level, scenario-bootstrapped proof of the learner-facing workflow.

The missing confidence is not in one pure business function. The missing confidence is in the integrated path that combines:

- project or product setup
- section paywall configuration
- learner enrollment and identity state
- student-facing delivery access behavior
- provider-specific or code-based payment completion paths
- post-payment access unlock

Without this coverage, release validation still relies on manual verification of a business-critical, non-academic workflow that can block delivery.

## 3. Goals & Non-Goals
### Goals
- Add deterministic Playwright coverage for paid-section learner behavior using scenario-driven bootstrap instead of browser-seeded world creation.
- Ensure each inherited paywall case uses its own standalone scenario bootstrap file with project -> product -> section setup.
- Cover the visible paywall and access-rule behavior for unpaid learners across no-grace, active-grace, and expired-grace configurations.
- Cover institution discount display behavior, including both qualifying and non-qualifying learner cases.
- Cover guest-learner restrictions when payment is required.
- Cover learner access unlock after Torus accepts payment through:
  - payment code redemption
  - simulated Stripe success handling
  - simulated Cashnet success handling
- Expand `Oli.Scenarios` enough to express paid-course setup deterministically from both product-level and section-level flows.
- Keep the resulting coverage isolated, repeatable, and executable independently per scenario/bootstrap case.

### Non-Goals
- Real external Stripe or Cashnet sandbox ownership, account management, or full third-party browser checkout is not required.
- This work does not replace lower-level unit or controller tests that already validate pieces of paywall and provider logic.
- This work does not attempt to solve entitlement or purchase-state coverage beyond the paid-course and provider-smoke behavior defined here.
- This work does not redesign the payment UI; it validates existing behavior.
- This work does not require broad scenario-DSL expansion beyond what is needed for deterministic paid-course setup and related assertions.

## 4. Users & Use Cases
- Learners: encounter the correct access outcome and payment UI for paid sections, grace periods, discounts, guest restrictions, and post-payment unlock.
- QA and release engineering: replace manual verification of paid-course access behavior with reliable automated evidence.
- Engineers: use scenario bootstrap plus Playwright to validate integrated learner workflows without depending on external payment dashboards.
- Future automated testing work in Lane 10: reuse the scenario paywall setup support added here for related commerce or access workflows.

## 5. UX / UI Requirements
- When an unpaid learner hits a paid section without an active grace period, the learner must be redirected to the payment-required UI rather than seeing course content.
- The payment-required UI must render the correct visible student information for the configured payment mode, including:
  - visible payment-required messaging
  - course fee
  - the correct available payment method controls for the configured payment options
- When a learner is within an active grace period, the learner must be able to access course content and must see the visible grace-period messaging and pay-now path expected by the current product behavior.
- When a grace period has expired, the learner must no longer see grace-period access behavior and must instead see the payment-required UI.
- When a learner qualifies for an institution discount, the payment UI must reflect the discounted amount.
- When a learner does not qualify for the institution discount, the standard price must be shown.
- When a guest learner encounters a paid section, the learner must be blocked from payment completion and shown the existing account-required messaging.
- After payment is accepted through any supported path in scope, the learner must be able to access the section successfully.

## 6. Functional Requirements
Requirements are found in `requirements.yml`.

The PRD-level functional scope is:

- paid section bootstrap via scenario-driven project, product, and section setup
- one standalone scenario bootstrap file per Playwright case for the inherited paywall matrix
- paywall configuration at both product and section levels where needed by the desired cases
- learner bootstrap for normal and guest users
- deterministic setup for institution discount coverage
- browser-level verification of pre-payment and post-payment learner behavior
- simulated provider-success handling for Stripe and Cashnet on the Torus side

## 7. Acceptance Criteria (Testable)
Requirements are found in `requirements.yml`.

At a minimum, the work item must produce automated coverage that proves:

- unpaid learner without grace period is blocked, is redirected to the payment-required UI, and sees the course fee, visible payment-required messaging, and correct payment method controls
- unpaid learner with active grace period can access course content, sees the grace-period banner, and sees a visible pay-now path
- unpaid learner with expired grace period is blocked and sees the payment-required UI instead of the grace-period banner
- qualifying learner sees discounted price
- non-qualifying learner does not see discounted price
- guest learner sees account-required restrictions instead of a normal payment flow
- learner blocked before payment code redemption can access after code redemption succeeds
- learner blocked before simulated Stripe success can access after Torus processes the simulated success path
- learner blocked before simulated Cashnet success can access after Torus processes the simulated success path

## 8. Non-Functional Requirements
- Reliability: each automated case must own its own deterministic bootstrap world so tests can run independently and do not depend on shared mutable fixtures.
- Test stability: Playwright coverage must minimize provider-surface dependency by simulating accepted provider outcomes on the Torus side rather than automating third-party hosted payment pages.
- Performance: scenario bootstrap should remain fast enough that these tests are practical as targeted Playwright coverage rather than bloated browser-seeded setup flows.
- Security: provider-smoke coverage must validate only internal handling of accepted provider responses in test environments and must not require real credentials or live payment execution.
- Maintainability: shared helpers for bootstrap, selectors, and post-payment verification should be reusable across the paid-section cases in this work item.
- Compatibility: the new scenario support must coexist with current scenario directives and not break unrelated scenario execution.

## 9. Data, Interfaces & Dependencies
- Browser automation lives in the existing Playwright automation area under `assets/automation/`.
- Scenario bootstrap depends on the existing Playwright scenario seeding path and `Oli.Scenarios` infrastructure.
- Paywall setup support likely needs additions to:
  - `lib/oli/scenarios/directive_types.ex`
  - `lib/oli/scenarios/directives/product_handler.ex`
  - `lib/oli/scenarios/directives/section_handler.ex`
  - related scenario docs under `test/support/scenarios/docs/`
- Discount coverage may require new scenario support or a narrow deterministic hook, depending on the lowest-cost design that still produces readable and maintainable test bootstrap.
- The minimum discount commitment for this work item is one deterministic discount type. The default planning assumption is percentage discount coverage unless fixed-amount coverage is materially cheaper to implement.
- Post-payment provider smoke depends on current Torus integration boundaries for:
  - payment code redemption in `lib/oli_web/controllers/payment_controller.ex`
  - Stripe direct payment in `lib/oli/delivery/paywall/providers/stripe.ex` and `lib/oli_web/controllers/payment_providers/stripe_controller.ex`
  - Cashnet direct payment in `lib/oli/delivery/paywall/providers/cashnet.ex` and `lib/oli_web/controllers/payment_providers/cashnet_controller.ex`

## 10. Repository & Platform Considerations
- Follow the automated testing epic guidance that Playwright should validate browser-critical behavior while scenario bootstrap owns deterministic world creation.
- Keep repository documentation paths relative to the repository root.
- Prefer the smallest scenario-DSL expansion that can express the required paid-course cases cleanly from YAML.
- Preserve existing Phoenix context boundaries: scenario handlers and Playwright seed endpoints orchestrate setup, while paywall and provider business rules remain in their existing backend modules.
- Avoid introducing test-only shortcuts that bypass the real Torus payment-state transitions being validated.

## 11. Feature Flagging, Rollout & Migration
No feature flags are required for this work item.

The rollout is additive:

- add or expand scenario bootstrap support for paid-course setup
- add the Playwright coverage files and any shared helpers
- keep existing lower-level paywall and provider tests as supporting layers

No end-user migration is required.

## 12. Telemetry & Success Metrics
- Primary success metric: manual release validation for paid-section learner access behavior is reduced or eliminated for the covered cases.
- Secondary success metric: the new Playwright cases execute reliably from isolated scenario bootstrap data without dependence on external payment account ownership.
- The work item should leave a clear trace from covered learner workflow cases to automated test evidence.

## 13. Risks & Mitigations
- Risk: scenario DSL expansion becomes broader than needed and delays delivery. Mitigation: add only the paywall, discount, and learner-state setup needed by the covered cases.
- Risk: provider smoke tests drift into brittle third-party browser automation. Mitigation: simulate successful provider outcomes at Torus-owned boundaries and validate learner-visible unlock behavior.
- Risk: discount setup becomes awkward or opaque in YAML. Mitigation: choose the smallest deterministic scenario representation that remains readable and stable.
- Risk: product-level and section-level paywall configuration semantics conflict. Mitigation: define clear precedence in the FDD and test both configuration paths intentionally.
- Risk: Cashnet callback assumptions differ from undocumented vendor reality. Mitigation: base tests on the current Torus callback contract and document the assumption explicitly.

## 14. Open Questions & Assumptions
### Open Questions
- For provider-smoke coverage, should the simulated success path be triggered entirely from Playwright, or should a lower test layer prepare the state while Playwright verifies the learner-visible before-and-after behavior?
- Are there internal Cashnet vendor documents available outside the repository that should refine the callback payload contract currently inferred from the implementation?

### Assumptions
- This work item is intentionally planned and implemented as one combined PR/work item rather than two parallel but separate planning tracks.
- Payment code redemption is in scope because it is the concrete post-payment unlock example called out by stakeholders and exercises a real supported learner path.
- Stripe and Cashnet live or sandbox account ownership is not required for the intended smoke coverage.
- Scenario bootstrap must support paid-course setup from both product and section flows because the desired cases and current ticket framing require both perspectives.

## 15. QA Plan
- Automated validation:
  - targeted scenario validation for all new or changed bootstrap files
  - targeted ExUnit coverage for any new scenario handlers or hooks
  - targeted Playwright coverage for each learner-visible paid-course case in scope
  - regression verification that post-payment unlock is observable in the learner flow for code, Stripe-simulated, and Cashnet-simulated paths
- Manual validation:
  - only as a spot check during development if browser behavior needs confirmation beyond the new automated evidence

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] FDD created and aligned with this PRD
- [ ] plan.md created and implementation-ready
- [ ] validation passes

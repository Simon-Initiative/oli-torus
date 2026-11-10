# Paywall And Provider Smoke - Functional Design Document

## 1. Executive Summary
This design delivers one combined automation lane for paid-course learner behavior. It adds the scenario-driven setup required to create paid products and sections deterministically, then uses Playwright to validate the learner-visible paywall experience before payment and the learner access unlock behavior after payment is accepted through one of three supported paths:

- payment code redemption
- simulated Stripe success handling
- simulated Cashnet success handling

The design intentionally avoids external payment account dependencies. Instead, it exercises the real Torus setup, access enforcement, guard UI, payment controller behavior, payment code redemption flow, and provider callback handling, while simulating only the third-party success outcomes at Torus-owned boundaries.

This work satisfies the combined paid-section automation scope by:

- expanding `Oli.Scenarios` to express paywall and discount setup from both product and section flows
- using one scenario bootstrap file per Playwright case
- reusing the existing Playwright scenario-seeding path
- validating the learner-visible state before and after accepted payment
- preserving the full project -> product -> section bootstrap shape for the inherited paywall browser cases

## 2. Requirements & Assumptions
- Functional requirements:
  - automate unpaid learner access behavior for paid sections without grace, with active grace, and with expired grace
  - automate institution discount visibility for qualifying and non-qualifying learners
  - automate guest-learner payment restrictions
  - automate learner unlock after payment code redemption
  - automate learner unlock after Torus processes simulated Stripe success
  - automate learner unlock after Torus processes simulated Cashnet success
  - support deterministic scenario bootstrap for paywall configuration at both product and section levels
- Non-functional requirements:
  - isolate each browser case behind its own deterministic bootstrap world
  - minimize third-party brittleness by simulating provider outcomes at Torus boundaries
  - keep scenario additions small, explicit, and reusable
- Assumptions:
  - one work item and one PR will deliver the combined scope
  - lower-level paywall and provider tests remain in place as supporting layers
  - no real Stripe or Cashnet sandbox ownership is required
  - discount coverage is mandatory for this work item

## 3. Repository Context Summary
- What we know:
  - Playwright scenario bootstrap already exists through `lib/oli_web/controllers/playwright_scenario_controller.ex` and `assets/automation/src/core/seedScenario.ts`.
  - Browser automation already lives under `assets/automation/tests/torus/`.
  - Student paywall behavior is enforced by `lib/oli_web/plugs/enforce_paywall.ex` and surfaced through `lib/oli_web/controllers/payment_controller.ex`.
  - Payment code redemption is already implemented in `PaymentController.apply_code/2`.
  - Stripe provider success handling is already implemented in `lib/oli_web/controllers/payment_providers/stripe_controller.ex`.
  - Cashnet provider success handling is already implemented in `lib/oli_web/controllers/payment_providers/cashnet_controller.ex`.
- Current scenario directives support project, product, section, enrollment, and learner workflow setup, but do not yet expose the paywall fields required by the desired browser cases.
- Unknowns or choices to resolve in design:
  - whether to model payment completion as first-class scenario directives or to drive it from Playwright against existing endpoints
  - whether provider-success simulation should be driven directly by Playwright or partially prepared by a lower test layer while preserving browser-visible before-and-after assertions

## 4. Proposed Design
### 4.1 Component Roles & Interactions
This work item uses three layers with clear responsibilities.

`Oli.Scenarios` owns deterministic world creation:

- project and product setup
- section setup
- paywall configuration
- grace-period configuration
- learner and institution setup
- discount setup

Playwright owns learner-visible verification:

- navigation to section content
- observation of redirects or visible paywall UI
- observation of grace-period or guest-specific messaging
- observation of visible payment-required messaging, course fee, and payment method controls where applicable
- observation of a visible pay-now path in the active grace-period case
- verification that access changes after accepted payment

Existing Torus payment boundaries own payment-state transitions:

- payment code redemption continues through `PaymentController`
- Stripe success continues through `StripeController.success/2`
- Cashnet success continues through `CashnetController.success/2`

The design does not add new backend payment paths just for tests. Instead, Playwright or scenario setup will call the same Torus entry points that production flows use after setup is complete.

### 4.2 State & Data Flow
For each Playwright case:

1. Playwright seeds a single `.scenario.yaml` bootstrap file through the existing scenario seeding controller.
2. The scenario creates:
   - institution as needed
   - project
   - product
   - section from that product
   - learner or guest learner
   - enrollment
   - paywall configuration
   - discount configuration where applicable
3. Playwright logs in as the seeded learner and navigates to the seeded section route.
4. Torus access-control flow resolves through the existing enrollment and paywall plugs and controllers.
5. Playwright verifies the learner-visible state before payment.
6. For post-payment cases, one of the supported payment paths is executed:
   - code redemption through the existing learner-facing payment code flow
   - simulated Stripe success through Torus-owned Stripe endpoints
   - simulated Cashnet success through Torus-owned Cashnet endpoints
7. Playwright rechecks learner access and verifies the learner can now enter the section.

### 4.3 Lifecycle & Ownership
Scenario bootstrap data is owned by the scenario runner and is created per test case. No browser test is allowed to create its own course world through authoring or admin UI clicks for this work item.

Provider success simulation is owned by the test harness and Playwright, not by production code changes. The simulation must use existing controller contracts rather than adding test-only success shortcuts unless a design gap makes that unavoidable.

Product-level and section-level paywall setup both remain explicit inputs of the scenario world. Precedence rules must be deterministic and documented when both are provided. Even when a case ultimately depends on section-level override behavior, the browser case should still be bootstrapped through project -> product -> section rather than direct standalone section setup.

### 4.4 Alternatives Considered
- Real Stripe and Cashnet browser checkout: rejected. It requires external account ownership, introduces brittle third-party UI dependency, and is unnecessary for validating Torus-owned handling of accepted payment outcomes.
- Lower-level ExUnit only for provider smoke: rejected as the sole approach. It proves backend handling but does not validate the learner-visible before-and-after access transition required by this work item.
- Browser-created world setup: rejected. It is slower, less deterministic, and contrary to the automated testing strategy for Playwright scenario bootstrap.
- Section-only paywall configuration in scenarios: rejected because the combined work item needs to cover both direct section setup and project -> product -> section flows.

## 5. Interfaces
### 5.1 Scenario DSL Extensions
This design adds explicit paywall support to both product and section setup.

`ProductDirective` additions:

```elixir
defstruct [
  :name,
  :title,
  :from,
  :requires_payment,
  :amount,
  :payment_options,
  :has_grace_period,
  :grace_period_days,
  :grace_period_strategy,
  :pay_by_institution
]
```

`SectionDirective` additions:

```elixir
defstruct [
  :name,
  :title,
  :from,
  :type,
  :registration_open,
  :slug,
  :open_and_free,
  :requires_enrollment,
  :start_date,
  :end_date,
  :requires_payment,
  :amount,
  :payment_options,
  :has_grace_period,
  :grace_period_days,
  :grace_period_strategy,
  :pay_by_institution
]
```

Supported YAML shapes:

```yaml
- product:
    name: "paid_template"
    from: "source_project"
    requires_payment: true
    amount:
      currency: "USD"
      amount: 25
    payment_options: "direct_and_deferred"
    has_grace_period: true
    grace_period_days: 7
    grace_period_strategy: "relative_to_student"
```

```yaml
- section:
    name: "fall_paid"
    from: "paid_template"
    requires_payment: true
    amount:
      currency: "USD"
      amount: 25
    payment_options: "deferred"
```

### 5.2 Discount And Test-State Setup
The implemented design keeps institution-qualified pricing readable in YAML without adding a new top-level discount directive. Instead, `SectionDirective` gained an `institution` field so the scenario can create the section in the qualifying institution and let the section handler resolve inherited price and `requires_payment` through the existing product pricing rules.

Implemented `SectionDirective` shape:

```elixir
defstruct [
  :name,
  :title,
  :from,
  :type,
  :registration_open,
  :slug,
  :open_and_free,
  :requires_enrollment,
  :start_date,
  :end_date,
  :requires_payment,
  :amount,
  :payment_options,
  :has_grace_period,
  :grace_period_days,
  :grace_period_strategy,
  :pay_by_institution,
  :institution
]
```

Supported YAML shape for the qualifying case:

```yaml
- section:
    name: "paid_section"
    from: "paid_template"
    institution: "cmu"
```

Rationale:

- keeps the qualifying versus non-qualifying difference visible in YAML
- reuses the existing paywall pricing resolution instead of duplicating discount semantics in the scenario layer
- avoids introducing a one-off top-level directive that this slice did not otherwise need

Guest enrollment and provider-pending payment setup are handled by deterministic scenario hooks in `test/scenarios/student_payment/hooks.ex`. Those are setup-only concerns that produce seeded params for Playwright, not reusable learner-visible business concepts that need their own long-lived YAML DSL surface.

### 5.3 Payment Completion Strategy
This design does not add provider-specific scenario directives for "mark payment successful". Instead, post-payment behavior keeps the learner-visible unlock in Playwright while allowing scenario hooks to prepare prerequisite internal state for provider-backed cases.

Supported completion paths:

- payment code: Playwright drives `GET /sections/:slug/payment/code` and `POST /sections/:slug/payment/code`
- Stripe:
  - a scenario hook creates a pending Stripe payment and exposes the intent id
  - Playwright posts the simulated success payload to `POST /api/v1/payments/s/success`
- Cashnet:
  - a scenario hook creates a pending Cashnet payment and exposes the reference fields
  - Playwright posts the simulated success payload to `POST /api/v1/payments/c/success`

### 5.4 Provider Payload Contracts
Stripe payload contract is based on official Stripe `PaymentIntent` shape plus the Torus implementation's actual needs.

Create-intent response mock shape:

```json
{
  "id": "pi_test_123",
  "client_secret": "pi_test_123_secret_abc",
  "status": "requires_payment_method"
}
```

Success payload posted back into Torus:

```json
{
  "intent": {
    "id": "pi_test_123",
    "client_secret": "pi_test_123_secret_abc",
    "status": "succeeded"
  }
}
```

Cashnet payload contract is based on current Torus callback handling:

```json
{
  "result": "0",
  "respmessage": "SUCCESS",
  "lname": "<cashnet configured name>",
  "ref1val1": "<payment_ref>"
}
```

These payloads are sufficient because current Torus code consumes:

- Stripe: `intent["id"]`
- Cashnet: `result`, `lname`, and `ref1val1`

## 6. Data Model & Storage
No new product data model is required for the browser tests themselves beyond scenario support. The design reuses current Torus paywall and payment persistence.

Scenario support may need:

- parser and validator updates for new fields on product and section directives
- handler updates to apply paywall values during or immediately after product or section creation
- a scenario hook module for guest enrollment and provider-pending payment setup

No new test-only persistent payment tables or fake-provider records should be added.

## 7. Consistency & Transactions
Scenario setup must create the bootstrap world deterministically in one execution pass. Product, section, paywall, enrollment, and discount setup should either complete successfully or fail the scenario with explicit errors.

Paywall precedence when both product and section define payment fields:

1. product-level fields establish defaults inherited by sections created from that product
2. section-level fields explicitly override inherited values for that section

This precedence preserves both use cases:

- realistic product-template paywall defaults
- targeted section-level variation without creating a new product

Discount creation must target the final resolved product used by the section under test.

## 8. Caching Strategy
No new caching is required.

Playwright tests should treat scenario-seeded identifiers and credentials as the single source of truth for each case. Shared helper modules may cache seeded metadata inside the test process for convenience, but no server-side cache should be introduced for this work item.

## 9. Performance & Scalability Posture
The dominant performance win comes from scenario-driven setup instead of UI-seeded world creation. Paywall cases are small worlds and should remain lightweight.

Potential cost centers:

- repeated bootstrap of projects and products per test
- discount setup if it requires additional product mutation or database writes
- repeated auth/login setup in Playwright

Mitigations:

- keep each scenario minimal
- share Playwright auth helpers where possible
- reuse existing page objects and payment helpers rather than duplicating flows

## 10. Failure Modes & Resilience
- Invalid scenario paywall field combinations should fail validation before Playwright runs.
- If both product and section define inconsistent paywall values, the documented precedence must produce deterministic resulting section state.
- If provider success payloads drift from current Torus expectations, provider-smoke cases should fail with explicit endpoint or unlock assertions rather than silent mismatches.
- If Cashnet config values such as `CASHNET_NAME` are missing in test environments, the Cashnet success case must fail fast with a clear setup error.
- If a section targets an unknown institution for pricing resolution, scenario execution must fail explicitly.

## 11. Observability
No new production telemetry is required for this work item.

Test observability should include:

- scenario bootstrap output showing the seeded section and learner identifiers
- clear Playwright evidence for:
  - blocked state before payment
  - accepted payment action or simulated provider success
  - unlocked state after payment

If a shared Playwright helper is introduced for post-payment verification, it should emit readable step names so failures identify which unlock path failed.

## 12. Security & Privacy
Simulated provider-success paths must only run in controlled test environments and must reuse existing Torus test or dev configuration. This work item must not introduce unauthenticated production shortcuts that would weaken the current payment boundaries.

Scenario bootstrap may create named learners and institutions, but should continue following existing test-data conventions. No real payment credentials or live financial operations are involved.

## 13. Testing Strategy
### 13.1 Scenario Tests
Add or update ExUnit scenario validation coverage for:

- new paywall fields on product directives
- new paywall fields on section directives
- new institution discount directive
- precedence behavior when both product and section define payment fields

### 13.2 Playwright Cases
Add dedicated Playwright specs and one scenario bootstrap file per case, covering:

- unpaid learner without grace period, including visible payment-required messaging, course fee, and correct payment method controls
- unpaid learner with active grace period, including visible grace-period banner and pay-now path
- unpaid learner with expired grace period, including payment-required UI instead of grace-period banner
- institution discount applies
- institution discount does not apply
- guest learner on paid section
- payment code unlock
- Stripe simulated unlock
- Cashnet simulated unlock

The specs may be grouped in one or more files, but the bootstrap data for each case must remain isolated.

### 13.3 Supporting ExUnit Coverage
Add targeted backend tests only where scenario or browser work introduces new handlers, directive logic, or shared helper boundaries. Do not duplicate existing paywall or provider controller coverage unnecessarily.

## 14. Backwards Compatibility
This design is additive:

- existing scenario files remain valid if the new fields are optional
- existing Playwright infrastructure remains intact
- existing paywall and provider code paths remain authoritative

No production behavior should change unless scenario support or test helpers accidentally leak into normal runtime paths; the implementation must avoid that.

## 15. Risks & Mitigations
- Risk: Scenario support for paid setup sprawls into a broad commerce DSL. Mitigation: add only the explicit fields needed for the cases, and keep hooks limited to setup-only states.
- Risk: Discount modeling becomes too opaque if hidden behind hooks. Mitigation: keep institution targeting explicit on the section YAML and reserve hooks for guest and pending-payment setup only.
- Risk: Provider-smoke cases end up bypassing too much of Torus. Mitigation: drive completion through current Torus endpoints rather than mutating DB state directly.
- Risk: Cashnet contract remains partly inferred. Mitigation: document the assumption and anchor tests to current Torus callback expectations.
- Risk: Product and section paywall semantics become confusing. Mitigation: document and test inheritance plus override precedence explicitly.

## 16. Open Questions & Follow-ups
- If internal Cashnet vendor docs surface later, compare them against the assumed callback contract and update the tests if necessary.
- If later Lane 10 work needs richer discount matrices than institution-qualified pricing, reassess whether a first-class discount directive becomes worthwhile.

## 17. References
- `docs/exec-plans/current/epics/automated_testing/paywall-and-provider-smoke/informal.md`
- `docs/exec-plans/current/epics/automated_testing/paywall-and-provider-smoke/prd.md`
- `docs/exec-plans/current/epics/automated_testing/overview.md`
- `docs/exec-plans/current/epics/automated_testing/plan.md`
- `docs/TESTING.md`
- `lib/oli_web/controllers/playwright_scenario_controller.ex`
- `assets/automation/src/core/seedScenario.ts`
- `lib/oli_web/plugs/enforce_paywall.ex`
- `lib/oli_web/controllers/payment_controller.ex`
- `lib/oli_web/controllers/payment_providers/stripe_controller.ex`
- `lib/oli_web/controllers/payment_providers/cashnet_controller.ex`
- `lib/oli/delivery/paywall/providers/stripe.ex`
- `lib/oli/delivery/paywall/providers/cashnet.ex`
- `assets/src/payment/stripe/client.ts`
- `assets/src/payment/cashnet/client.ts`
- `lib/oli/scenarios/directive_types.ex`
- `lib/oli/scenarios/directives/product_handler.ex`
- `lib/oli/scenarios/directives/section_handler.ex`
- `test/scenarios/student_payment/hooks.ex`
- `lib/oli_web/controllers/playwright_session_controller.ex`

## Decision Log
### 2026-07-13 - Replace Planned Discount Directive With Section Institution Support
- Change: Replaced the planned `institution_discount` directive design with the implemented section-level `institution` field and documented hooks for guest and provider-pending state setup.
- Reason: The delivered implementation reused existing paywall pricing logic and kept the YAML surface smaller while still preserving readable qualifying versus non-qualifying scenarios.
- Evidence: `lib/oli/scenarios/directive_types.ex`, `lib/oli/scenarios/directive_parser.ex`, `lib/oli/scenarios/directives/section_handler.ex`, `test/scenarios/student_payment/hooks.ex`
- Impact: Updates the interface contract for future scenario authors and clarifies that Stripe and Cashnet smoke coverage seeds pending payments through hooks before Playwright drives success callbacks.

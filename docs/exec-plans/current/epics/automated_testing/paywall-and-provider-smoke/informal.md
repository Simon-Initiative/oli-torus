# Paywall And Provider Smoke - Informal Source Context

Last updated: 2026-07-10

This document captures the initial Jira and codebase context for a combined planning effort covering `MER-5498` and `MER-5500`. It is intentionally informal source material for later `prd.md`, `fdd.md`, and `plan.md` work.

## Source Tickets

- `MER-5498` Automated paywall setup and section access-rule coverage (Playwright)
  - Type: Story
  - Status: To Do
  - Priority: Medium
  - Reporter: Darren Siegel
  - Created: 2026-03-19
  - Summary: create Playwright end-to-end tests that validate the student-facing paywall UI for paid course sections using scenario bootstrap files for deterministic world setup
- `MER-5500` Automated payment-provider integration smoke coverage
  - Type: Story
  - Status: To Do
  - Priority: Medium
  - Assignee: Nicolas Cirio
  - Reporter: Darren Siegel
  - Created: 2026-03-19
  - Summary: add automated smoke coverage for payment-provider-driven access unlock behavior
  - Latest Jira comment from Eli Knebel:
    - Payment related access
    - Ensuring students can't access until they pay
    - After student pays, verify they can access (using payment code)

## Epic Context

Both tickets belong to Lane 10 of the automated testing epic:

- `docs/exec-plans/current/epics/automated_testing/plan.md`

Relevant lane scope:

- Eliminate manual testing for access-control behavior that depends on payment, entitlement, or other external-service constraints.
- Ensure release validation includes the non-academic workflows that can block delivery.

Story ordering in the lane:

1. `MER-5498` Automated paywall setup and section access-rule coverage
2. `MER-5499` Automated entitlement and purchase-state coverage
3. `MER-5500` Automated payment-provider integration smoke coverage

## Why Plan These Together

`MER-5498` and `MER-5500` overlap in setup and in the student-facing delivery path:

- both need paid course sections with paywall configuration
- both need deterministic learner creation and enrollment
- both need browser-level validation of student delivery access behavior
- both benefit from scenario-driven bootstrap rather than browser-driven world creation

The likely shared infrastructure is:

- scenario DSL support for paywall-related section or product configuration
- scenario bootstrap support for paywall-specific fixtures such as discounts or payment data
- Playwright helpers and selectors for the paywall guard, grace-period UI, and payment-entry surfaces

Planning them together should reduce duplicate design work while still preserving explicit acceptance boundaries inside one combined work item for:

- pre-payment access rules and paywall UI behavior
- post-payment unlock behavior via payment code and simulated provider success handling

## MER-5498 Jira Intent

The Jira description for `MER-5498` explicitly calls for Playwright tests focused on the visible student experience for paid course sections.

Each test should:

- use its own scenario bootstrap file
- create a course project
- publish it as a product
- configure product or section paywall settings
- create a course section from that product
- create and enroll a student
- let Playwright validate the student-visible UI

The description explicitly says the tests should focus on visible student experience, not payment-processing internals.

Recommended test matrix from Jira:

1. Paid section, no grace period, unpaid student
2. Student is redirected to the payment-required UI
3. UI shows course fee, Payment Required, and the correct available payment method controls
4. Paid section, active grace period, unpaid student
5. Student can access course content
6. Grace-period banner is visible
7. Banner communicates remaining grace-period access and includes a Pay Now path
8. Paid section, expired grace period, unpaid student
9. Student cannot access course content
10. Student sees the payment-required UI instead of the grace-period banner
11. Paid section with institution discount
12. Student belongs to the institution receiving the discount
13. Payment UI reflects the discounted amount
14. Prefer one discount type unless adding both is low-cost
15. Paid section with a guest student
16. Guest student is not able to pay and is told to create an account first
17. Optional negative discount case
18. Student belongs to a different institution
19. Discount is not applied and the standard price is shown

Implementation notes from Jira:

- one standalone scenario file per Playwright test case
- scenario directives should create and enroll the student
- scenario setup should configure `requires_payment`, `amount`, `payment_options`, `has_grace_period`, `grace_period_days`, and `grace_period_strategy`
- if scenario discount support is missing, add the smallest deterministic directive or hook necessary

## Combined Delivery Intent For This Work Item

This combined work item will be delivered as one PR and one planning package. The work item must cover the learner journey called out by Eli:

- learner is blocked because payment is required
- learner completes an accepted payment path
- learner can then access the section successfully

The accepted payment paths for this combined work item are:

- payment code redemption
- Stripe success handling with simulated provider responses
- Cashnet success handling with simulated provider responses

This means the work item is broader than only one of the original story titles. It intentionally combines:

- paywall UI and access-rule coverage
- institution discount coverage
- guest-learner payment restrictions
- post-payment unlock coverage
- provider callback or response handling from the Torus side without depending on external sandbox ownership

## Current Codebase Understanding

### Paywall and Access Enforcement

The core student access enforcement already exists:

- paywall plug redirect behavior in `lib/oli_web/plugs/enforce_paywall.ex`
- paywall access-state logic in `lib/oli/delivery/paywall.ex`
- paywall guard and payment code redemption in `lib/oli_web/controllers/payment_controller.ex`

Existing tests already cover parts of the backend and controller behavior:

- paywall domain behavior in `test/oli/delivery/paywall_test.exs`
- payment guard rendering in `test/oli_web/controllers/payment_controller_test.exs`
- page delivery redirect to paywall in `test/oli_web/controllers/page_delivery_controller_test.exs`
- plug-order and paywall redirect integration in `test/oli_web/plugs/plug_order_integration_test.exs`

### Stripe Integration Shape

Stripe is implemented as a Torus-managed direct-payment flow:

- provider module: `lib/oli/delivery/paywall/providers/stripe.ex`
- controller: `lib/oli_web/controllers/payment_providers/stripe_controller.ex`
- browser client: `assets/src/payment/stripe/client.ts`

What Torus currently expects from Stripe:

- create-intent response must at least include `id` and `client_secret`
- finalize step uses the posted `intent` payload and only requires `intent["id"]` to identify the pending payment record

From official Stripe docs, the relevant canonical object is a `PaymentIntent` with fields such as:

- `id`
- `client_secret`
- `status`

This makes simulated provider-success payloads practical for test coverage without needing a live Stripe account.

### Cashnet Integration Shape

Cashnet is implemented as a form-post and callback flow:

- provider module: `lib/oli/delivery/paywall/providers/cashnet.ex`
- controller: `lib/oli_web/controllers/payment_providers/cashnet_controller.ex`
- browser client: `assets/src/payment/cashnet/client.ts`

What Torus currently expects for success handling:

- `result == "0"`
- `lname == CASHNET_NAME`
- `ref1val1 == payment_ref`

Torus then finalizes the pending payment and links it to enrollment.

Unlike Stripe, public official Cashnet response-shape documentation was not readily discoverable during initial research. The repository's implemented callback contract is therefore the best current source of truth unless internal vendor documentation surfaces later.

## Current Scenario-DSL Gap

The current `Oli.Scenarios` infrastructure appears to support:

- project creation
- product creation
- section creation
- enrollment
- learner workflow simulation

But it does not yet appear to expose the paywall setup needed by this combined work item:

- `requires_payment`
- `amount`
- `payment_options`
- grace-period configuration
- discount creation

The combined work item requires this paywall setup to be expressible from both:

- `product` directives, so scenario bootstrap can reflect project -> product -> section setup flows
- `section` directives, so scenarios can also configure or override paywall state directly at the delivery-instance layer

Relevant current files:

- `lib/oli/scenarios/directive_types.ex`
- `lib/oli/scenarios/directives/product_handler.ex`
- `lib/oli/scenarios/directives/section_handler.ex`
- `test/support/scenarios/docs/products.md`
- `test/support/scenarios/docs/sections.md`

This likely makes scenario expansion a prerequisite for the desired Playwright bootstrap flow.

## Initial Combined Planning Direction

The current best combined framing is:

- unpaid learner access rules and visible paywall UI behavior
- institution discount behavior in the visible payment UI
- guest-learner restrictions when payment is required
- post-payment unlock behavior using:
  - payment code redemption
  - simulated Stripe success responses handled by Torus
  - simulated Cashnet success responses handled by Torus

Proposed coverage split:

- unpaid without grace period
- unpaid with active grace period
- unpaid with expired grace period
- institution discount display for a learner in the qualifying institution
- institution discount non-application for a learner outside the qualifying institution
- guest-learner restriction behavior on paid sections
- payment code unlock flow
- Stripe success-handling smoke
- Cashnet success-handling smoke

Each post-payment case should prove a learner is blocked before payment recognition and can access after Torus processes the accepted payment result.

## Planning Decisions Already Taken

The current planning package has already resolved these decisions:

- this will be delivered as one combined work item and one PR
- the paid-course matrix inherited from the original paywall ticket keeps the full project -> product -> section bootstrap shape
- scenario support must handle paywall configuration from both product and section flows
- post-payment coverage includes all three accepted paths for this work item:
  - payment code redemption
  - simulated Stripe success handling
  - simulated Cashnet success handling
- institution discount coverage is in scope
- minimum discount scope is one deterministic discount type, with percentage discount as the default planning target unless fixed-amount coverage is materially cheaper

## Open Questions For Formal Planning

- Should discount setup be modeled as first-class scenario directives or as narrow-purpose hooks?
- Should provider-success smoke tests stay fully browser-driven in Playwright, or should the simulated callback be exercised by a lower test layer with only the learner-visible verification in Playwright?
- Is there any internal Cashnet integration document outside the repository that should supersede the current callback assumptions?

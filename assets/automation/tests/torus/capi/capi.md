# CAPI component automated tests (MER-5701)

Automated coverage for the CAPI interface — the postMessage protocol between an embedded
simulation and the host adaptive page, implemented in
`assets/src/components/parts/janus-capi-iframe/ExternalActivity.tsx`.

## What CAPI is

Adaptive pages embed simulations in an `<iframe>`. The sim and the host page talk over
`window.postMessage` using a fixed envelope:

```
{ handshake: { requestToken, authToken, config }, options, type: <numeric>, values }
```

The host (`ExternalActivity`) is the ground truth for the wire format — there is no vendored
`simcapi.js` in the repo.

## Test layers

| Layer                      | File                                             | Run                                                           |
| -------------------------- | ------------------------------------------------ | ------------------------------------------------------------- |
| Protocol E2E (Playwright)  | `capi.spec.ts`                                   | `npx playwright test tests/torus/capi/capi.spec.ts`           |
| Value coercion (Jest)      | `assets/test/adaptivity/capi_variable_test.ts`   | `cd assets && npx jest test/adaptivity/capi_variable_test.ts` |
| Seeding directive (ExUnit) | `test/oli/scenarios/edit_adaptive_page_test.exs` | `mix test test/oli/scenarios/edit_adaptive_page_test.exs`     |

## Playwright coverage

| #   | Test                         | Asserts                                                                                                                                                                  |
| --- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | handshake                    | HANDSHAKE_REQUEST → HANDSHAKE_RESPONSE, requestToken echoed, config has context/sectionSlug/userId/questionId                                                            |
| 2   | init sequence                | ON_READY → page→sim VALUE_CHANGE (carries seeded var) → INITIAL_SETUP_COMPLETE                                                                                           |
| 5   | state restore                | sim sets a var, revisit lesson, value pushed back on re-init                                                                                                             |
| 6   | SET_DATA                     | SET_DATA_REQUEST → SET_DATA_RESPONSE success, value echoed                                                                                                               |
| 7   | GET_DATA                     | stored value returns `exists:true`; unknown key returns `exists:false`, value `'[]'`                                                                                     |
| 8   | RESIZE                       | RESIZE_PARENT_CONTAINER_REQUEST (absolute + relative) → RESPONSE echoes messageId; iframe bounding box follows (800×600 → 500×400 → 550×400)                             |
| 9   | robustness                   | malformed / non-JSON / pre-handshake traffic does not break the listener; handshake still works after                                                                    |
| 10  | source check                 | a CAPI message posted from the top window (not the iframe) is ignored                                                                                                    |
| 11  | token gap (characterization) | a same-iframe post-handshake message with a _mismatched_ `requestToken` is still processed — documents the current boundary (source enforced, token not), see finding #2 |
| 3   | check lifecycle              | CHECK_REQUEST → deck check → CHECK_START_RESPONSE + CHECK_COMPLETE_RESPONSE (seed carries a non-navigating trapstate rule)                                               |

Out of this Playwright suite's scope (deliberately): outbound `CONFIG_CHANGE` and review-mode
behavior (VALUE_CHANGE suppressed / `readonly` pushed) — these need a context-change/review flow
beyond the protocol round-trip this suite covers, and aren't asserted here. `CONFIG_CHANGE`
coverage is tracked as TRIAGE-2412.

## How it works

- **Stub sim** (`support/stub-sim.html`): a static page speaking the CAPI envelope, loaded into the
  iframe by intercepting an absolute URL via Playwright `page.route()`. It records every message
  received from the host in `window.__capiLog` and is driven from tests via `frame.evaluate()`
  (see `support/capiStub.ts`). Deterministic and offline — no real simulation needed.
- **Seeding** (`capi_page.scenario.yaml`): builds a project with an `oli_adaptive` activity holding a
  `janus-capi-iframe` part pointed at the stub URL, then converts the page to an adaptive page via
  the `edit_adaptive_page` scenario directive (added for this work), publishes, creates a section,
  and enrolls a student. Delivered through the `seedScenario` fixture →
  `POST /test/scenario-yaml`.

## Running locally

1. Dev server with scenario seeding enabled and a token:
   `PLAYWRIGHT_SCENARIO_TOKEN=my-token mix phx.server`
   (`enable_playwright_scenarios` is already true in dev/test, false in prod.)
2. Ensure the dev DB is migrated (`mix ecto.migrate`).
3. `cd assets/automation && npx playwright test tests/torus/capi/capi.spec.ts`

No external services (no Canvas, no real sim host). Runtime ≈ 5 min for the 10 active tests
(single worker, per `playwright.config.ts`).

If you hit `Playwright Test did not expect test.describe()` / "two versions of @playwright/test"
on a full-file run, it's a stale transform cache — `rm -rf node_modules/.cache` and re-run.

## CI placement

Only a nightly Playwright workflow exists today (`--grep @nightly`). These tests, like the other
`seedScenario`-based specs (`curriculum.spec.ts`), are **untagged** and run in the standard local
suite. Wiring scenario-seeding tests into nightly CI needs `PLAYWRIGHT_SCENARIO_TOKEN` +
`enable_playwright_scenarios` in that environment — a shared infra follow-up affecting all
seedScenario tests, not just CAPI.

## Findings (for the team)

1. **No-rules check crash (F2 — product bug candidate).** An adaptive activity reaching check with
   no evaluable rules crashes `triggerCheck` (`processResults(undefined).forEach`,
   `DeckLayoutFooter.tsx:210`) — CHECK_START_RESPONSE fires but CHECK_COMPLETE_RESPONSE never does.
   Surfaced while building test 3; the test now seeds a non-navigating trapstate rule to avoid it.
   The crash itself is latent delivery hardening — see
   `docs/exec-plans/current/epics/automated_testing/capi/F2-no-rules-check-crash.md`. (The earlier
   "part not registered / 403" framing was wrong; the 403 is a benign deferred-save race. Full
   write-up in `docs/exec-plans/current/epics/automated_testing/capi/deferred-check-lifecycle.md`.)
2. **`requestToken` is not validated after handshake** (`ExternalActivity.tsx:1076` TODO). The host
   filters by `evnt.source` (confirmed enforced — test 10) but accepts any post-handshake message
   regardless of requestToken (characterized by test 11). Low risk given the source check, but
   worth a decision — hardening would be a separate ticket; flip test 11 to a negative assertion if
   added.
3. **Pre-existing duplicate `id="app"`** in `lib/oli_web/templates/layout/chromeless.html.heex:33-34`
   — two `<link>` stylesheet tags share `id="app"`, producing a `Multiple IDs detected: app`
   console warning on every adaptive (chromeless) page load. Harmless but a real duplicate-id
   defect, unrelated to CAPI. Trivial fix (drop/rename the id on one link).

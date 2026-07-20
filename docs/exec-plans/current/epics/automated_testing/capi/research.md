# MER-5701 Research: Automated Testing Epic (MER-5367) Patterns

Research synthesized on 2026-06-12 from Jira (epic MER-5367 + 44 children) and repo analysis
(commits, PRs, test code) to inform MER-5701: "Create comprehensive, automated test of CAPI
component / interface".

## 1. The ticket

- **MER-5701** — In Progress, assigned Francisco Castro. Parent epic: MER-5367 "Automated Testing"
  (epic has no description/comments — all context comes from siblings).
- Description: "If one does not exist already, this task is to create a fully comprehensive set of
  automated tests for the CAPI component (which allows simulations to communicate with a host
  adaptive page)".
- Verified: no comprehensive CAPI test exists. Only `assets/test/delivery/janus_capi_iframe_test.ts`
  (96 lines, styling/scrolling helpers only). Core protocol untested.

## 2. CAPI surface on master (verified by direct read)

| File | Lines | Tested? |
|---|---|---|
| `assets/src/components/parts/janus-capi-iframe/ExternalActivity.tsx` | 1256 | No — handshake, VALUE_CHANGE, CONFIG_CHANGE, postMessage lifecycle all here |
| `assets/src/adaptivity/capi.ts` (CapiVariable, type coercion) | 169 | Indirect only (via `scripting_test.ts`) |
| `assets/src/components/parts/janus-capi-iframe/iframeBehavior.ts` | 78 | Yes — the one existing test |
| `JanusCAPIRequestTypes.ts` | 70 | No |
| `schema.ts` | 292 | No |
| `sourceResolver.ts` | 95 | No |
| `CapiIframeAuthor.tsx` / `CapiVariablePicker.tsx` | 458 / 167 | No (authoring side) |

`iframeBehavior.ts` is itself the precedent for the testability pattern: logic extracted out of the
big component into pure functions, then unit-tested with Jest.

## 3. Epic sibling inventory (Jira, 2026-06-12)

44 children. Status distribution: 6 Done, 8 QA, 2 In Progress, rest To Do/Analyzing.
Worked tickets group into three families:

| Family | Tickets | Test type | State |
|---|---|---|---|
| LTI smoke tests | MER-5394, 5396, 5397, (+5669 outside epic) | Playwright | 5396/5669 merged; 5397 done on unmerged branch `origin/MER-5397-instructor-first-launch-and-course-creation`; 5394 has **no commits in this repo** |
| Authoring coverage | MER-5415 (objectives), 5653 (activity bank), 5418 (Google Docs import, in progress) | Scenario framework | 5415 merged PR #6608; 5653 merged PR #6596 |
| Delivery coverage w/ service extraction | MER-5465, 5469, 5471, 5475, 5477, 5479, 5481, 5482, 5502 | Scenario framework | All shipped in two big PRs: #6362 (gating + certificates, ~6.8k lines) and #6455 (assessment settings + attempts, ~6.2k lines) |

Note: tickets map many-to-one onto PRs. One PR routinely closes 2–7 tickets in this epic.

## 4. The three test layers (and how this epic uses them)

### 4.1 Jest (frontend unit/integration) — `assets/test/`
- `yarn test` (jest + ts-jest). Simulated DOM, no browser.
- Existing CAPI-adjacent tests: `adaptivity/scripting_test.ts` (uses CapiVariable),
  `delivery/janus_capi_iframe_test.ts`.
- Epic siblings barely used this layer — their targets were backend workflows. CAPI is the first
  frontend-protocol target in the epic.

### 4.2 Scenario framework (backend integration) — `test/scenarios/`, `lib/oli/scenarios/`
- YAML directives → parser (`directive_parser.ex`) → engine (`engine.ex`) → handlers
  (`directives/*_handler.ex`) calling **real** Oli modules, real DB (DataCase transaction). No UI,
  no mocks.
- JSON Schema source of truth: `priv/schemas/v0-1-0/scenario.schema.json`.
- Test runners auto-discover `*.scenario.yaml` per directory; metadata supports `nightly`/`slow`
  tags and timeout overrides.
- Docs live in `test/support/scenarios/docs/` (e.g. `gating.md` 346 lines,
  `student_simulation.md` 278 lines) — every scenario-family ticket shipped docs alongside.
- **Elixir-only.** Cannot exercise client-side postMessage protocol.

### 4.3 Playwright (browser E2E) — `assets/automation/`
- Config: `assets/automation/playwright.config.ts` (Chrome, 1920x1080, single worker).
- Layout: `src/systems/torus/pom/` (page objects), `src/systems/canvas/api/` (API clients),
  `tests/torus/<area>/<name>.spec.ts` + adjacent `.md` doc + `support/` helpers.
- `@nightly` tag → scheduled CI run (`.github/workflows/nightly-playwright.yml`, daily 5:17 UTC,
  `npx playwright test --grep @nightly`).
- Established iframe pattern (grade-passback test): `page.frameLocator('iframe[name="tool_content"]')`,
  `expect.poll()` for async state, isolated browser contexts per user, cleanup in `finally`.

### 4.4 The bridge: `seedScenario` fixture (verified in code)
`assets/automation/src/core/fixture/my-fixture.ts` exposes `seedScenario(relativePath, params)` —
Playwright sends a scenario YAML to a backend HTTP endpoint, which executes it via the Scenario
engine. So Playwright tests get declarative backend seeding (project + pages + activities) and then
drive the real browser. This is how a CAPI E2E test can stand up an adaptive page containing a
`janus-capi-iframe` part without manual authoring clicks.

## 5. Recurring patterns across worked siblings

1. **Service extraction / "below the UI boundary"** — when logic was trapped in LiveViews, tickets
   extracted it into plain modules first (e.g. `lib/oli/delivery/page/prologue_state.ex`,
   `lib/oli/delivery/settings/student_exceptions.ex`, `lib/oli/datetime.ex` time override), then
   tested the extracted module. Several ticket titles say this explicitly ("…service extraction
   needed to move X below the UI boundary"). Frontend equivalent already in repo: `iframeBehavior.ts`.
2. **Shared setup via `use: file: setup.yaml`** — scenario families share one setup file; each test
   case is its own small YAML.
3. **Docs are part of the deliverable** — every family shipped a markdown doc next to the tests
   (scenario directive docs, or spec-adjacent `.md` for Playwright like `grade-passback.md`,
   `canvas_playwright.md`).
4. **Deterministic time** — `time` directive / `Oli.DateTime` override instead of real waits;
   real-wait tests are tagged `nightly`/`slow` and excluded from PR CI.
5. **Big PRs are normal here** — 6–7k lines, 60–73 files, closing several tickets at once.
6. **Resilience idioms (Playwright)** — `expect.poll()`, selector fallbacks, retry helpers
   (`clickUntilVisible`), `waitForLiveView()` (`[data-phx-main].phx-connected`).

## 6. What this means for MER-5701

> **Superseded 2026-06-12 — see section 8.** This section was the original recommendation
> (Jest-primary + extraction refactor). Team feedback redirected to Playwright-primary with no
> production refactoring. Kept for context.

CAPI is a client-side TypeScript postMessage protocol, so the epic's dominant tool (Scenario
framework) cannot test the protocol itself. The fit:

| Layer | Role for CAPI | Effort center |
|---|---|---|
| **Jest** (primary) | Protocol correctness: handshake (HANDSHAKE_REQUEST/RESPONSE, requestToken), VALUE_CHANGE in/out, CONFIG_CHANGE, state restore, CapiVariable type coercion both directions, bad-message/wrong-token/pre-handshake edge cases | Likely needs light refactor of `ExternalActivity.tsx` first — extract message handlers into pure functions (the `iframeBehavior.ts` precedent) |
| **Playwright** (secondary) | One real-browser proof: adaptive page + real iframe + real postMessage round-trip, seeded via `seedScenario` | New `assets/automation/tests/torus/capi/` (or `adaptive/`) spec + adjacent `.md`; a sim stub page to load in the iframe |
| **Scenario** (supporting only) | Backend seeding YAML consumed by the Playwright spec; possibly assert authored adaptive-activity structure | Reuse existing directives; new CAPI-specific directives almost certainly unnecessary |

### Open questions (resolve with team before/at spec time)
1. **Definition of "comprehensive"** — ticket body is one sentence; epic has no description. Test
   inventory needs team sign-off (protocol messages × directions × edge cases?).
2. **Refactor scope** — how much of `ExternalActivity.tsx` (1256 lines) may move into pure modules?
   Pure test ticket vs test+refactor ticket changes review surface significantly.
3. **Sim stub for E2E** — is there an existing CAPI test simulation to load in the iframe, or do we
   build a minimal stub page? (None found in repo.)
4. **Authoring side in scope?** — `CapiIframeAuthor.tsx`/`CapiVariablePicker.tsx` are untested too;
   ticket says "component / interface", ambiguous.

## 7. Additional code findings (2026-06-12, direct reads)

- **Authoring side duplicates the protocol.** `CapiIframeAuthor.tsx` (read in full) contains its own
  postMessage listener and handlers: `HANDSHAKE_REQUEST` → `HANDSHAKE_RESPONSE` with
  `config: { context: 'AUTHOR' }` (lines 134–146), `ON_READY` → pushes saved configData as
  `VALUE_CHANGE` + `INITIAL_SETUP_COMPLETE` (166–189), incoming `VALUE_CHANGE` → captures sim
  variables into state, which is how the variable picker discovers them (148–164). It is not just
  form UI.
- **Known tech debt, 2021.** Comment at `CapiIframeAuthor.tsx:113`: protocol methods "will move to a
  common place where authoring and delivery both can share the same JS file". Author per git blame:
  Devesh Tiwari, September 2021 (not Darren — earlier attribution in conversation was wrong).
- **`CapiVariablePicker.tsx` (read in full, 167 lines) is thin UI**: accordion markup delegating to
  existing shared inspector components (`AutoDetectInput`, `NestedStateDisplay`, `unflatten` from
  delivery preview-tools). Own logic ≈ 15 lines. Authoring-only remainder beyond the protocol ≈
  350–400 lines of UI glue (picker, configure-mode notifications, save/cancel persistence, render
  states).

## 8. Scope decisions (2026-06-12)

Questions were sent to the team (Darren on PTO ~2 weeks; colleague answered):

1. **"Comprehensive" proposal** (handshake, VALUE_CHANGE both directions, CONFIG_CHANGE, state
   save/restore, coercion, edge cases + one E2E): *"sounds reasonable"*.
2. **Refactor/extraction**: declined. *"I believe by automated tests, we are talking about
   playwright… we shouldn't have to refactor anything… I would prefer we don't change or refactor
   anything unless we uncover a bug as a result of the testing or we absolutely must to facilitate
   automated tests (e.g. DOM test handles, etc.)"*
3. **Existing sim/CAPI harness as reference**: unknown ("I don't know the answer to this").

### Resulting direction

| Decision | Consequence |
|---|---|
| **Playwright-primary, no production refactor** | Protocol tested through real browser: seed adaptive page (`seedScenario`), load stub sim in iframe, assert observable behavior. No `ExternalActivity.tsx` extraction. |
| **Programmable stub sim** (in-repo) | The test instrument. Per-test scripting of what the stub sends (normal handshake, wrong token, malformed JSON, pre-handshake messages); records all page→sim traffic for assertions. Covers the edge-case list without touching production code. |
| **Jest only where zero-refactor** | `capi.ts` (CapiVariable/coercion) is already exported pure code — Jest-testable today. Included. Component-internal handlers: not Jest-tested (would require extraction). |
| **Authoring coverage: open again** | The "extraction covers both sides" path is dead with the refactor. Authoring (editor + variable picker) coverage would need its own Playwright flows — in/out decision deferred to the plan. |
| **Trade-off accepted** | Coarser, slower tests than the Jest plan; assertions on effects rather than individual handlers. Extraction idea (2021 TODO) can be revisited with Darren later as a separate ticket. |

Next artifact: `plan.md` in this directory — test inventory, stub sim design, seeding approach,
file layout, CI placement.

## 9. Deep verification pass (2026-06-12, second session)

Full-file reads: `ExternalActivity.tsx` (all 1256 lines), `capi.ts`, `schema.ts`,
`sourceResolver.ts`, `CapiIframeAuthor.tsx`, `CapiVariablePicker.tsx`, seeding endpoint controller,
scenario `ops.ex` revise path, hook handler. Three agent traces: adaptive delivery mount path,
scenario rules support, CAPI wire format. Results folded into `plan.md` §1–§2. Headlines:

- Adaptive runtime only boots on pages with `content.advancedDelivery == true`
  (init_page.ex:157) — adaptive activity on a regular page does NOT mount `ExternalActivity`.
- Rules evaluate on check/submit, not on VALUE_CHANGE — test design adjusted.
- Scenario hooks can't run via the dev-server seeding endpoint (test/ not compiled in dev,
  mix.exs:131). `manipulate→revise` CAN set arbitrary page content from YAML (ops.ex:456) but
  can't know activity resource_ids → one seeding gap remains; preferred fix = small scenario
  directive extension (epic-blessed pattern), pending approval.
- Wire format fully documented (envelope, per-type payloads, 500ms handshake delay, 100ms save
  debounce, no token validation TODO at ExternalActivity.tsx:1076, source check at 1066).
- Seeding endpoint does `${param}` interpolation and returns slugs/emails but no resource ids
  (playwright_scenario_controller.ex:107–124).
- No simcapi.js vendored anywhere; Torus host code is the protocol ground truth for this system.

## 10. Confidence notes

- Directly verified this session: CAPI file inventory and line counts, existing test files,
  `seedScenario` fixture, scenario directory layout, MER-5394 absence of commits, MER-5397 unmerged
  branch, nightly workflow existence, Jira statuses.
- Agent-reported (spot-checked but not line-by-line verified): per-PR line counts and file lists for
  #6362/#6455/#6596/#6608, internal structure details of handlers/assertions. Treat exact numbers as
  approximate.
- MER-5394 (Canvas LTI launch smoke): marked Done in Jira but no commits found in this repo —
  possibly done elsewhere or superseded by MER-5669 (PR #6618), which implements that flow.

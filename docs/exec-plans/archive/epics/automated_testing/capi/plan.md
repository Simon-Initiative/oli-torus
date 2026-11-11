# MER-5701 Plan: Automated CAPI Component Tests

Companion to `research.md`. Scope per research §8: Playwright-primary, no CAPI production
refactoring, programmable in-repo stub sim, Jest only for already-pure code.

Revised 2026-06-12 after full-file reads of `ExternalActivity.tsx`, `capi.ts`, `schema.ts`,
`sourceResolver.ts`, the seeding endpoint, scenario ops, and three deep-trace agent passes.
Everything below cites verified behavior.

## 1. Verified protocol surface (delivery, `ExternalActivity.tsx`)

Host listener (lines 1065–1112) accepts only messages where `evnt.source === iframe.contentWindow`;
non-JSON silently dropped; **no requestToken validation** on incoming messages (TODO at line 1076).
Envelope: `{ handshake: {requestToken, authToken, config}, options, type: <numeric enum>, values }`,
JSON-stringified.

| Flow | Behavior (file:line) |
|---|---|
| HANDSHAKE_REQUEST (1) → HANDSHAKE_RESPONSE (2) | Token stored and echoed **after a 500ms setTimeout** (740–742); config carries `context/lessonId/questionId/sectionSlug/userId` (731–737) |
| ON_READY (3) | Pushes configData/current state as per-variable VALUE_CHANGE; values templatized via janus-script env (757–792); INITIAL_SETUP_COMPLETE (14) sent from the init-state effect (1207) |
| VALUE_CHANGE (4) sim→page | Ignored in review context (1095); vars stored under `stage.<partId>.<key>`; saved via **100ms debounced** (maxWait 30s, leading) `props.onSave` (849–885) |
| VALUE_CHANGE page→sim | On init-state apply (1203), on STATE_CHANGED notification → `processMutateStateVariable` (563–591, 278), on review readonly (508) |
| CONFIG_CHANGE (5) page→sim | On CONTEXT_CHANGED notification (606–613) |
| CHECK_REQUEST (7) | 150ms delay → `props.onSubmit` (919–926); page later emits CHECK_START_RESPONSE (15) / CHECK_COMPLETE_RESPONSE (8) on CHECK_STARTED/CHECK_COMPLETE notifications (534–561) |
| GET_DATA_REQUEST (9) → GET_DATA_RESPONSE (10) | Per-sim user storage via `props.onGetData`; `{simId, key, responseType, exists, value}`; missing → `value: '[]'`, `exists: false` (807–847) |
| SET_DATA_REQUEST (11) → SET_DATA_RESPONSE (12) | Via `props.onSetData`; success echoes value; error → `responseType: 'error'` (887–917) |
| RESIZE_PARENT_CONTAINER_REQUEST (18) → RESPONSE (19) | Absolute or relative width/height; echoes `messageId` (928–981) |
| Re-init pass | Host regenerates requestToken and sends unsolicited HANDSHAKE_RESPONSE (1212–1214) |

Component quirks that constrain tests:
- Message listener attaches only when `simFrame && scriptEnv` — `scriptEnv` comes from the adaptive
  runtime's `onInit` result (177–179, 1020). **Component is functional only inside the adaptive
  delivery runtime.**
- `model.configData` must be an array or line 1031 (`configData.map`) throws. Seeded part model
  MUST include `configData: []` minimum.
- `resolveAdaptiveIframeSource` passes any src not starting with `/course/link/` through verbatim
  (sourceResolver.ts:34–36) — an absolute stub URL reaches the iframe untouched, interceptable by
  `page.route()`. Iframe has no `sandbox` attr.
- Sim-specific hacks exist (KIP `CurrentEclipse` ordering 1161–1168, SmallWorld
  `AllowNextOnCacheCase` inversion 1192–1198) — out of test scope, noted to avoid confusion.

## 2. Critical architecture facts (change earlier assumptions)

1. **Adaptive runtime only mounts on adaptive pages.** `InitPage` routes by
   `content["advancedDelivery"]` (init_page.ex:157): regular practice pages get server-rendered
   HTML — an `oli_adaptive` activity referenced there does NOT boot the adaptive React app. Page
   revision content must carry `advancedDelivery: true` (+ `advancedAuthoring: true`,
   `model: [{type: group, layout: deck, children: [activity-reference]}]` per db_seeder shape).
2. **Rules don't fire on VALUE_CHANGE.** Adaptive rules evaluate on check/submit
   (NodeEvaluator → client rules engine). VALUE_CHANGE only updates state; CHECK triggers
   evaluation. Tests pair them.
3. **Scenario hooks are unusable via the Playwright endpoint.** Hook functions resolve at runtime,
   but dev compiles only `lib/` (mix.exs:131) — hook modules in `test/` (e.g. IframeLinksHooks)
   don't exist on the dev server.
4. **Seeding endpoint supports `${param}` interpolation** (playwright_scenario_controller.ex:107)
   and returns outputs: project/section slugs + user emails (114–124). It does NOT return resource
   ids.
5. **`manipulate → revise → set` passes arbitrary maps verbatim** into revision params
   (ops.ex:351–366, 456) — page `content` is settable from pure YAML. But it REPLACES the whole
   content map, and the adaptive `model` needs the activity's `resource_id`, which YAML/params
   cannot know. **This is the one unresolved seeding gap.**

### Seeding gap resolution (decision needed at build start)

Preferred: **small scenario-framework extension** in `lib/oli/scenarios/` — teach `edit_page` (or a
new op) to produce adaptive page content with virtual_id → resource_id resolution. Precedent: epic
sibling tickets are literally titled "…including any directive expansion needed for scenario-driven
coverage" — directive expansion is the epic's blessed pattern and is test infrastructure, distinct
from the CAPI refactoring the team declined. Estimated ~50–100 lines + schema entry + unit test.
Fallback if even that is unwanted: drive authoring UI with Playwright to build the adaptive page
(slow, brittle — not recommended).

## 3. Test inventory

### Playwright — `assets/automation/tests/torus/capi/capi.spec.ts` (10 + 1 optional)

Core:
1. **Handshake** — stub sends HANDSHAKE_REQUEST; within ~1s receives HANDSHAKE_RESPONSE echoing
   requestToken, config has `context: "VIEWER"` + sectionSlug/userId/questionId/lessonId.
2. **Init sequence** — stub sends ON_READY; receives configData vars as VALUE_CHANGEs then
   INITIAL_SETUP_COMPLETE.
3. **Variable change + check fires rule** — stub sends VALUE_CHANGE (`stage.x`), then
   CHECK_REQUEST; submission occurs, rule on `stage.x` fires → visible feedback; stub receives
   CHECK_START_RESPONSE and CHECK_COMPLETE_RESPONSE.
4. **Page→sim mutate** — rule action `mutateState` targets a stub variable; stub receives
   VALUE_CHANGE with the mutated value.
5. **State restore** — after test-3-style save (mind the 100ms debounce), reload page; stub
   receives saved variables as init VALUE_CHANGEs.
6. **Sim data write** — SET_DATA_REQUEST → SET_DATA_RESPONSE `responseType: success`, value echoed.
7. **Sim data read-back** — GET_DATA_REQUEST returns stored value with `exists: true`; unknown key
   returns `exists: false, value: '[]'`.
8. **Resize** — absolute then relative RESIZE_PARENT_CONTAINER_REQUEST; container dimensions
   change; RESPONSE echoes messageId.
9. **Malformed + pre-handshake traffic** — non-JSON, wrong-shape JSON, VALUE_CHANGE before
   handshake: no crash, handshake afterwards still succeeds. (Documents actual behavior — host
   currently accepts post-handshake messages with any token; if that surprises reviewers it's a
   finding, not a test failure.)
10. **Foreign-source message** — postMessage from main window with valid CAPI shape; ignored
    (source check 1066).

Optional (decide at build): **Review context** — in review mode stub's VALUE_CHANGE ignored and
`readonly: true` pushed (494–511, 1095). Needs review-mode navigation; include if cheap.

### Jest — `assets/test/adaptivity/capi_variable_test.ts`

11. **capi.ts suite** (file read in full; pure, exported): `getCapiType` (incl. allowedValues→ENUM,
    special array strings → STRING), `coerceCapiValue` (number/string/math/bool/array paths, ENUM
    invalid-value throw), `parseCapiValue` round-trips, `CapiVariable` constructor inference +
    `shouldConvertNumbers` flag, `isSpecialArrayString` edge cases (`["00.12"]` vs `["0.12"]`).

## 4. Stub sim design

`assets/automation/tests/torus/capi/support/stub-sim.html` — static, no build step. Served by
`page.route()` fulfilling an absolute URL (e.g. `https://capi-stub.test/sim.html`) injected into
the seeded part model via `${stub_url}` param interpolation.

- Speaks the verified envelope; uses one fixed requestToken; sends to `window.parent`.
- **Programmable**: test drives it via `frame.evaluate()` calls that enqueue actions
  (send message X, wait for type Y) — avoids needing the stub itself to be clever.
- **Recording**: every received message appended to `window.__capiLog` (parsed objects);
  assertions read it via `frameLocator().evaluate()` with `expect.poll()` (handshake has a 500ms
  server-side... component-side delay; saves debounce 100ms).

## 5. Seeding

`capi_page.scenario.yaml`, derived from `adaptive_iframe_internal_link_resolution.scenario.yaml`
(verified template) with:
- part model: `sourceType: "url"`, `src: "${stub_url}"`, `configData: []` (mandatory, §1),
  plus 1–2 seed variables in configData for init-sequence assertions
- `authoring.rules`: one rule on `stage.x` with feedback + one `mutateState` action (rules pass
  through verbatim — activity content stored as-is when `content_format: "json"`,
  activity_handler.ex:148)
- adaptive page content via the §2 seeding-gap resolution
- student (scenario default password `temporarypassword123`, user_handler.ex:12), section, enroll
- Playwright logs in via UI, navigates to `/sections/<slug>/lesson/<page>` — fullscreen adaptive
  route renders via `page_fullscreen` for chrome pages or direct React mount chromeless
  (page_delivery_controller.ex:334–348)

All local: dev server + Postgres, `PLAYWRIGHT_SCENARIO_TOKEN`, no external services.

## 6. File layout

```
assets/automation/tests/torus/capi/
├── capi.spec.ts
├── capi.md                  # spec-adjacent doc (epic convention)
├── capi_page.scenario.yaml
└── support/
    ├── stub-sim.html
    └── capiStub.ts          # route fulfillment, action driving, log reading
assets/test/adaptivity/
└── capi_variable_test.ts
lib/oli/scenarios/...        # only if seeding-gap extension approved (§2)
```

## 7. Build order (sequential, present after each step)

0. **Decision gate**: seeding-gap approach (§2) — directive extension vs alternatives.
1. **Walking skeleton** — stub sim + seeding + test 1 (handshake). Proves: adaptive page renders
   for student, iframe mounts with stub URL, route interception works, round-trip completes.
2. Tests 2–5 (core: init, check/rules, mutate, restore).
3. Tests 6–8 (data + resize).
4. Tests 9–10 (robustness) + optional review-context test.
5. Jest capi.ts suite.
6. `capi.md` + CI placement (PR suite vs `@nightly` by observed runtime).

## 8. Constraints & risks

- **No CAPI production changes** (research §8). The §2 scenario extension is test infrastructure
  in `lib/` — flagged explicitly for approval because it technically touches `lib/`.
- **Residual unknowns** (only discoverable by running — step 1 exists for these): whether the
  db_seeder-shaped adaptive content renders correctly when seeded this way; deck-layout navigation
  needs (`session.currentQuestionScreen` etc.); whether CHECK flow in practice (ungraded) adaptive
  pages surfaces feedback visibly enough to assert.
- **Timing discipline**: 500ms handshake delay, 100ms save debounce, 150ms submit delay — all
  assertions via `expect.poll()`/`waitFor`, no fixed sleeps.
- **Findings rule**: robustness tests document actual behavior; weak validation (no token check —
  TODO line 1076) reported as finding, not encoded as aspiration.

## 9. Build progress

### Step 1 — walking skeleton ✅ (2026-06-12)
- New scenario directive `edit_adaptive_page` (directive_types, parser, engine, handler, schema)
  builds advancedDelivery/advancedAuthoring page content: page `custom` block (defaultScreenWidth
  etc.), deck `model`, activity-reference with `custom.sequenceId`/`sequenceName`. Unit test:
  4 passing (`test/oli/scenarios/edit_adaptive_page_test.exs`).
- Stub sim (`support/stub-sim.html` + `support/capiStub.ts`), seeding YAML
  (`capi_page.scenario.yaml`), handshake Playwright test — green.
- Setup learnings baked into the spec: DB migrate first; dismiss onboarding wizard via hidden
  `#automation-go-to-course`; navigate to lesson directly via `phx-value-slug` from the Learn
  outline; configData keys are sent verbatim as CAPI variable keys (use plain names like `x`).

### Final state ✅ (shipped — PR #6663)
All planned coverage landed and is green:
- **Playwright (10)** in `capi.spec.ts`: handshake, init + page→sim VALUE_CHANGE, check lifecycle,
  state restore, SET_DATA, GET_DATA, RESIZE, malformed/pre-handshake robustness, foreign-source
  ignored, requestToken characterization.
- **Jest (17)** `capi_variable_test.ts`; **ExUnit (4)** `edit_adaptive_page_test.exs`.

The check-lifecycle test (test 3) was briefly deferred mid-build while the cause was diagnosed; it
is now **passing**. Root cause was a no-rules evaluation crash (`processResults` on undefined), not
part-registration — fixed in the test by seeding a non-navigating trapstate rule, with the
underlying delivery crash tracked as a separate finding. See `deferred-check-lifecycle.md`.

Test 4 (rule-driven page→sim mutate) was folded into test 3, which now asserts the observable
`mutateState` effect (the variable reaching and satisfying the rule).

### Follow-up findings (separate tickets, out of scope per Eli's "tests only" ruling)
F2 (no-rules check crash), `requestToken` not validated post-handshake, duplicate `id="app"` in
`chromeless.html.heex`, and the sibling `edit_page_handler` swallowed-upsert. See `capi.md` findings
and `F2-no-rules-check-crash.md`.

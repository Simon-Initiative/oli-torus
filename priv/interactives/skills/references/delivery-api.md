# Torus Interactive delivery API v1

Copy `/workspace/torus-tools/torus.js` unchanged into your built bundle at its root.
Load `<script src="./torus.js"></script>` before your app script. All calls are promises.
The SDK automatically fits the delivery iframe to document content, including later UI changes.
Use natural document flow: avoid viewport-height sizing (`100vh`, `height:100%`) on the
page or app root and avoid a separate vertical scrolling region for the whole activity.
Torus normalizes `html`/`body` height and minimum height for this embedded layout.
Size canvases or other bounded interaction surfaces explicitly; the surrounding page grows.
Existing saved bundles load the current managed SDK without changing their learning code.

Torus injects no globals besides the SDK. No tokens, learner IDs, URLs or attempt GUIDs
are needed. Never call Torus with fetch or invent a reset API.

```js
const torus = await TorusInteractive.connect();
const saved = await torus.attempt.get('progress'); // JSON value or null if absent
const shared = await torus.section.get('courseProgress');
// Restore UI from saved and torus.context.parts, including an already finished activity.
await torus.attempt.set('progress', { step: 2, choices: ['A'] });
await torus.section.set('courseProgress', { completedLabs: 1 });
await torus.parts.finalize({
  partId: 'measure', // exact stable ID in manifest.json
  response: { measurement: 4.2, units: 'mol/L' }, // any JSON result/response data
  correct: false // boolean; records 0/1 or 1/1 using Torus client evaluation
});
// A later measurable retry uses exactly the same call and partId. Torus creates
// a fresh part attempt internally, preserving each earlier result and response.
await torus.parts.finalize({ partId: 'measure', response: { measurement: 3 }, correct: true });
await torus.activity.finalize();
```

API surface:
- `context`: current `{version:1, readOnly, status, score, outOf, parts}`. Parts are
  `{id, status, attemptNumber, response, score, outOf}`; response is Torus's stored
  `{input: yourResponse}`. Lifecycle status is active, submitted, or evaluated.
  Initial parts are active. Finalize calls refresh context. Do not mutate context.
- `attempt.get(key) / set(key, value)`: current **activity** attempt's JSONB state.
  A new overall activity attempt starts empty. Reload/resume restores the same attempt.
- `section.get(key) / set(key, value)`: this learner's enrollment state, shared across
  pages and Interactives in the same section. Use descriptive app-specific keys to
  avoid collisions. Values are replaced per key; other keys remain intact.
- `parts.finalize({partId, response, correct})`: records an evaluated part, response,
  and objective-linked result. Repeat calls create new attempts. Only call on committed
  measurable learner actions, never on rendering, reload, or connection. Returns context.
- `activity.finalize()`: requires all latest parts to be evaluated (correctness is not
  required). Runs normal Torus scoring/progress and returns context. Completion is
  idempotent. After completion, mutation is read-only; restore a completed view.

Await calls and disable the triggering control while a request is pending. Save progress
before finishing; restore it on connect. Never finalize on each keypress. In read-only
context show saved results and disable mutations. Catch failures, show a useful message,
and preserve the learner's work. Errors have `.code`: read_only, incomplete_parts,
unknown_part, invalid_request, unavailable, timeout, request_failed, or a server failure
code. A timeout has an uncertain outcome: reconnect/reload to inspect persisted results;
do not automatically retry finalization (each retry represents a new measurable action).
Keys are strings of 1–256 bytes, values are JSON, and each state value is at most 1 MB.
State is arbitrary application data; do not store secrets. Correctness is client-reported,
as with existing Torus client-evaluated activities.

For local Playwright testing, serve the app inside a parent iframe page and implement
this message contract in the **test harness only**: requests from the child have
`{channel:'torus.interactive.v1',id,method,params}`. Respond to that child's window with
`{channel,id,result}` or `{channel,id,error:{code}}`, preserving id. Methods match the
API above, except connect sends `context`. Maintain in-memory state and part results
in the harness, enforce completion/readOnly, and test incorrect → correct retry and
reload restoration. Never ship a mock bridge or fake fallback persistence in the app.
The real Torus parent validates source/origin and authenticates all persistence.


Torus author preview implements these same capabilities in a temporary parent-frame session.
State and scores in preview do not create learner records and are discarded when the preview
restarts or closes. Do not add preview-specific fallbacks to the generated app.


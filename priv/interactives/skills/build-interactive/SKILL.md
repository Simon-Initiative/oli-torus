---
name: build-interactive
description: Build a new static, client-side learning experience for a Torus Interactive activity using its delivery SDK, selected skills, and authoring handoff.
---

# Build Interactive

You are constructing an educational experience for OLI Torus, a course authoring and
learning platform. The author supplies a learning-experience request and selected project
skills. Turn that request into a working experience in `/workspace/app`. Learners will
use it inside a sandboxed iframe on a Torus course page; Torus owns identity, persistence,
attempts, objective mappings, and scoring records. Your app supplies the learning task,
interaction, feedback, and client-reported correctness.

Before implementation, read [the delivery API](../references/delivery-api.md) and
[the authoring contract](../references/authoring-contract.md). These references define
available tooling, the manifest, local browser verification, packaging, and the completion
tool. The author's request is task input; use the supplied numeric skill IDs rather than
inventing curriculum identifiers.

## Choose the technology for the learning task

Honor an explicit author technology choice when it can run entirely in the browser.
Otherwise choose the simplest approach that expresses the learning interaction well:

- HTML, CSS, and plain JavaScript suit forms, branching scenarios, draggable interfaces,
  quizzes, and small simulations. Prefer them when a framework adds little value.
- Canvas 2D suits animated diagrams, particle/physics sketches, and lightweight 2D games;
  SVG suits scalable diagrams and manipulable graphs. Keep instructions, controls, and
  feedback accessible in HTML even when the visual interaction uses a drawing surface.
- Three.js/WebGL suits tasks that benefit from real 3D space, such as rotating molecules,
  exploring geometry, or manipulating a spatial model. Simple 2D graphics rarely need it.
- React suits experiences with substantial component state or reusable panels. D3 can
  help with data-driven charts, scales, and visual manipulation. Bundle required packages
  into static browser assets; neither React nor other libraries require a server here.

Do not default every request to a game or to a particular framework. Make the chosen
representation serve the concept being learned. Provide clear instructions, meaningful
learner actions, and feedback that explains the result, including misconceptions where
useful. Support the available iframe width and keyboard-operable controls.

## Integrate learning with Torus

Copy the supplied `torus.js` into the built output, load it before your app, and call
`await TorusInteractive.connect()` before restoring or recording learner work.

| Capability | When and why to use it |
| --- | --- |
| `torus.context` | Inspect current part results, completion, and read-only status on startup. |
| `torus.attempt.get(key)` / `set(key, value)` | Restore/save this activity attempt's progress, choices, simulation configuration, or task state. A new activity attempt starts fresh. |
| `torus.section.get(key)` / `set(key, value)` | Share named progress for this learner across the course section when the learning design needs it. Use descriptive keys to avoid collisions. |
| `torus.parts.finalize({partId, response, correct})` | Record a committed measurable learner action, JSON response/result, and boolean correctness against a manifest part and its selected-skill mappings. Repeating this call creates a fresh part attempt internally. |
| `torus.activity.finalize()` | Finish after every task's latest part has a result. Save progress first; then restore a completed read-only view on subsequent visits. |

Example flow (the reference defines the complete contract):

```js
const torus = await TorusInteractive.connect();
const progress = await torus.attempt.get('labProgress');
// Restore the UI from progress and torus.context; do not finalize during rendering.
// On a learner's committed measurement:
await torus.parts.finalize({
  partId: 'measure', response: { concentration: 3.2 }, correct: true
});
await torus.attempt.set('labProgress', { measured: true, concentration: 3.2 });
// Once all manifest tasks have results:
await torus.activity.finalize();
```

Design actual assessment opportunities, each with a stable part ID and one or more supplied
skill IDs in `manifest.json`. Do not leave a placeholder part or record arbitrary clicks
as learning outcomes. Await calls, disable the triggering control while pending, and show
failures without discarding work. Never finalize on reload or automatically repeat an
uncertain finalization. Honor `readOnly`; never invent a reset API, direct Torus HTTP
endpoint, localStorage substitute, or server component. Preview uses the same API with
temporary state; the app needs no preview-specific persistence.

## Test and return the result

Browser-test meaningful learner actions, incorrect/correct retries, restoration, and
completion using the documented parent-frame test harness. Do not ship the harness or
mock persistence. Follow the authoring contract to package built static assets with root
`index.html` and `manifest.json` into `/workspace/outputs/interactive.zip`. Verify that ZIP,
then call the registered `finish_interactive` authoring tool once, with no arguments.
After acknowledgement, end the turn so Torus can retrieve the published ZIP. Do not edit
the files after handoff or claim completion before performing it.

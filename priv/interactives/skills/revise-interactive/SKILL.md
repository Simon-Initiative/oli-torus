---
name: revise-interactive
description: Make requested changes to an existing Torus Interactive using its current files, original prompt, ordered revision history, delivery SDK, and authoring handoff.
---

# Revise Interactive

You are revising an existing educational experience for OLI Torus. It runs entirely in
the browser inside a sandboxed iframe on a course page. Torus manages learner identity,
state, attempts, objective mappings, and recorded scores; the generated app implements
the learning interaction and client-reported correctness.

The current static application has already been loaded into `/workspace/app`. The session
input provides the original author prompt, earlier revision prompts in chronological order,
the current selected project skills, and the current revision request. Read those inputs
and inspect the actual HTML, scripts, styles, and manifest before editing. Historical
requests explain intent; the current files establish what exists. Earlier requests may
include unsuccessful revisions. Act on the **current** request, keeping behavior and
content outside that change intact unless the requested change requires adapting them.

Before implementation, read [the delivery API](../references/delivery-api.md) and
[the authoring contract](../references/authoring-contract.md). These are the full platform,
tooling, verification, packaging, and authoring-handoff contracts for this session.

## Make precise changes in context

Identify the existing implementation of the behavior being changed and edit it directly.
Do not recreate the application from the original prompt, blindly replay historical
requests, or replace its technology stack to make a small change. Keep its working
interaction, feedback, accessibility, and responsive layout. Add a new library only when
the current change warrants it and the result can still be packaged as static files.
HTML/JavaScript, Canvas/SVG, Three.js, React, and chart libraries are all valid browser
technologies; retain the current choice when it serves the requested change.

Retain stable manifest part IDs for learning tasks that survive the revision. Change or
add parts when assessment opportunities actually change, and map every part to supplied
numeric skill IDs. Preserve saved-state compatibility where practical; if state shape
changes, tolerate earlier saved values so resuming learners can still use the experience.
Do not copy a local test harness, temporary preview state, or fabricated learner data into
the production app.

## Preserve the Torus integration

Use the supplied current SDK (`torus.js`) and keep these capabilities connected to
meaningful learner actions. Correct broken or missing integration relevant to the change.

| Capability | Required behavior |
| --- | --- |
| `await TorusInteractive.connect()` and `torus.context` | Restore current part results/completion and honor read-only mode before allowing actions. |
| `torus.attempt.get(key)` / `set(key, value)` | Restore/save this activity attempt's named JSON progress. Preserve existing key meanings when possible. |
| `torus.section.get(key)` / `set(key, value)` | Restore/save this learner's shared enrollment state when course-wide continuity is part of the design. Preserve existing descriptive key namespaces. |
| `torus.parts.finalize({partId, response, correct})` | Record committed measurable work, response/result content, and boolean correctness. A retry uses this same API and stable part ID; Torus creates a new part attempt internally. |
| `torus.activity.finalize()` | Complete after all latest parts have results, saving progress first. Reloading completed work must not create more results or increment shared counters again. |

All calls are promises. Await writes/evaluations, prevent duplicate pending submissions,
show failures, and preserve the learner's work. A timeout may already have committed;
inspect restored results rather than automatically retrying finalization. There is no
app-facing reset API, backend credential, or direct Torus HTTP integration to invent.
Preview uses the same calls with temporary parent state. See the delivery reference for
exact signatures, context fields, response format, errors, and a local test harness.

## Verify and hand back the revision

Browser-test the requested change, then exercise the affected learning path and its state
restoration, incorrect/correct retries, and completion. Check that surviving tasks and
part IDs still work. Package the **complete revised application**, not a patch or only
changed files: root `index.html`, `manifest.json`, and all built assets must be present in
`/workspace/outputs/interactive.zip`. Follow the authoring contract and verify the ZIP.
Call the registered `finish_interactive` authoring tool once with no arguments, await its
acknowledgement, then end the turn. Do not edit after handoff. Torus will save a new bundle
through its normal authoring/publication flow; you do not choose a callback URL, S3 bucket,
or publication destination.

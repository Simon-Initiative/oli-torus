# Torus Interactive authoring contract

This contract applies to both `build-interactive` and `revise-interactive`.

## Workspace and runtime

Work in `/workspace/app`. Node.js, Python 3, esbuild, Playwright, and Chromium are provided.
Dependencies are installed in `/workspace/node_modules`; use
`/workspace/node_modules/.bin/esbuild` when bundling and `require('playwright')` in Node
scripts under `/workspace`. Read `/workspace/torus-tools/ready.json` for setup checks.
Install additional dependencies only when useful, then bundle browser dependencies into
the static output. The browser will not have Node.js or a development server.

The final app is loaded from Torus media storage into an iframe. Use relative URLs for
its assets. Do not depend on localhost, workspace paths, remote development servers,
SSR, server-side rendering endpoints, or browser-accessible credentials. Sandbox
permissions allow scripts and cross-origin media assets' own origin, but do not grant
forms, popups, top-level navigation, or access to the parent document. Communicate with
Torus only through the supplied SDK. No AWS or OpenAI credentials are provided to you.

Copy `/workspace/torus-tools/torus.js` unchanged into the output and load it before the app
script. Read [the delivery API](delivery-api.md) for its complete contract. Do not bundle
SDK mocks, browser test harnesses, `node_modules`, or unbuilt framework project files.
For revision, current static files are already in `/workspace/app`; modify them in place
and deliver the complete updated static application.

## Parts and selected-skill mappings

Place a root `manifest.json` beside `index.html`:

```json
{"version":1,"parts":[{"id":"measure","objectiveIds":[123]}]}
```

Use the actual supplied numeric selected-skill IDs. Every part needs a unique nonempty
string ID and at least one selected skill. Model the real assessment opportunities; the
manifest part IDs must exactly match `torus.parts.finalize` calls. Torus creates initial
active part attempts and uses these mappings for objective-linked analytics. Retain IDs
for surviving tasks in revisions. No fabricated IDs or unreferenced placeholder parts.

## Browser checks

Serve the app over a loopback HTTP server for Playwright Chromium checks. Since it expects
the Torus parent bridge, use a separate local parent-frame harness implementing the message
contract in the delivery API reference. Exercise real task interactions, incorrect then
correct responses, saving/restoring progress, read-only completion, and visible request
failures relevant to the design. Check browser errors and missing assets. Keep the test
harness outside the delivered files; the real app must connect to Torus rather than fall
back to fake or browser-local persistence. Report only checks actually performed.

## ZIP and authoring handoff

Use Python's standard-library `zipfile` (or equivalent installed tooling) to write
`/workspace/outputs/interactive.zip`. It must contain root `index.html`, root
`manifest.json`, the SDK, and all built static assets. Do not wrap these in an extra
outer directory. Use safe relative ZIP paths; no absolute paths, traversal, or symlinks.
Limits: 20 MB compressed, 50 MB expanded, 10 MB per file, at most 250 files.

Read the finished archive back, verify entries/manifest, and ensure it represents the
app you browser-tested. Then call the **registered authoring tool**:

```text
finish_interactive({})
```

This has no arguments or destination parameters. It signals to Torus that the ZIP is
ready. Torus acknowledges the tool call; **end your turn after acknowledgement** so the
provider publishes the ZIP artifact. Torus retrieves it, validates it, uploads it, and
saves a new authoring revision. Do not change files after signalling completion. Do not
POST to Torus, invent an upload API or callback URL, or upload to S3 yourself. If the tool
is absent or fails, report the blocked handoff rather than claiming the app was saved.

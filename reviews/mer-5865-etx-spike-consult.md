# MER-5865 etx spike consult

No answer values are reproduced here.

## Evidence audit

| Claim | Evidence read in this session | Verdict | Confidence |
|---|---|---|---|
| `selectOption` can drive the native controls | Both public HTML/JS implementations; installed Playwright `selectOption` implementation | Grounded, with the absorption exception below | high-within-scope |
| The in-lesson CAPI host could invalidate the standalone result | Both public `simcapi.js` copies; Torus `ExternalActivity.tsx`; the two imported authored configs | No current invalidator found | high-within-scope |
| The registry sketch matches the real surface | Sim variable declarations, authored `configData`, rules, and DOM topology | Partial | high-within-scope |
| Authoring-time source derivation is version-safe | Archive `src` values plus current S3 object headers | Not yet | high-within-scope |

The residual evidence gap is the already-declared one: neither target has completed the full
in-lesson save/evaluation path twice. That limits the conclusion to mechanical feasibility; it
does not satisfy the existing §5 wire-verification criterion.

## Findings

### Should-fix 1 — `ready: selects present` does not establish that CAPI initialization is complete

The sim calls `notifyOnReady()` after registering its model and DOM listeners
([`scriptsProperties.js`](https://etx-scripts.s3.us-west-2.amazonaws.com/gates_real_courses/real_chemistry_1/climate_explorations/unit4/molecular-properties-table/properties-table/scriptsProperties.js),
lines 218–231). The transporter first requests a handshake, then sends `ON_READY` and a full model
snapshot only after it receives an auth token (`simcapi.js`, lines 21515–21575). Torus deliberately
delays its handshake response by 500 ms and pushes `configData` after `ON_READY`
(`assets/src/components/parts/janus-capi-iframe/ExternalActivity.tsx:724` and
`assets/src/components/parts/janus-capi-iframe/ExternalActivity.tsx:746`). DOM presence can
therefore win the race against host initialization.

The private authored evidence closes the dangerous fresh-run branch: every one of the 54 locally
imported copies of each activity has the same source and config, and both configs initialize the
overall verdict, the nine per-molecule verdicts, and `showCorrect` to false. However, Torus applies
authored config first and then overwrites it with persisted state
(`assets/src/components/parts/janus-capi-iframe/ExternalActivity.tsx:1030`). Both activities also
contain an authored rule that can later mutate `showCorrect`. A resumed or contaminated attempt is
therefore not equivalent to a fresh standalone page.

Make readiness require the exact iframe source/version and expected control topology, plus evidence
that the host has received the initial CAPI surface and that `showCorrect` is false. Require all
student-editable selects to be enabled before answering. This is a step-6 determinism requirement,
not evidence against fresh-run drive feasibility.

### Should-fix 2 — The absorption table is not structurally identical and an all-select directive will fail

The absorption HTML contains 18 selects, but four are disabled and prepopulated
([`absorption-table/index.html`](https://etx-scripts.s3.us-west-2.amazonaws.com/gates_real_courses/real_chemistry_1/climate_explorations/unit4/molecular-properties-table/absorption-table/index.html),
lines 73–95 and 149–171). Playwright's installed implementation waits for the target select to be
enabled before selecting (`assets/automation/node_modules/playwright-core/lib/server/dom.js:464`).
Thus “`selectOption` per directive map” is unsound if derivation emits all 18 source-map entries.

Derive operations only for the 14 editable selects. Treat the four disabled cells as fixed
preconditions: assert their expected state in `ready`/`readback`, but never call `selectOption` on
them. The shared native `change` listener and grading function still make the editable path
mechanically feasible, so this changes the registry implementation and absorption verification,
not the gate verdict.

### Should-fix 3 — Keep grading payload, mechanism readback, and persistence barrier as three different contracts

Both sims expose eleven writable CAPI variables: the overall verdict, nine per-molecule verdicts,
and `showCorrect`. `showCorrect` is absent from `exposeWith`, but that does not hide it: the loop
still calls `expose` for every default, and `CapiAdapter.expose` supplies default writable options
when its params are absent (`simcapi.js`, lines 22017–22032). Each `change` recomputes every
per-molecule verdict and then the overall verdict (`scriptsProperties.js`, lines 180–201;
`absorption.js`, lines 183–202).

The registry sketch currently blurs those facts:

- `expectedPayload` should match the archived grading rule: the overall verdict only. Requiring
  per-molecule fields merely because `configData` declares them would be an unapproved
  strengthening and would couple grading to diagnostic implementation details.
- `readback` should be stronger than the grading rule: verify the selected DOM state and all ten
  verdict signals after the final change, while explicitly excluding `showCorrect` as an answer
  mechanism.
- `savedBarrier` should match the required persisted correctness state after the driver-stamped
  readback, not accept any later save solely because it contains the broad `stage.<part>.` prefix.

This separation prevents a stale host-pushed overall verdict or an unrelated post-readback CAPI
save from masquerading as evidence produced by the current drive.

### Should-fix 4 — A sim path is not a version; source-derived directives need an asset-graph pin

The archive points both parts at unversioned S3 URLs. The current S3 responses expose distinct
`x-amz-version-id` values, and the index and answer-bearing JS assets have different modification
histories. A registry key of `version = sim path` therefore aliases every future in-place update.
Deriving directives once at authoring time does not prove that the learner iframe later executed
the same source.

Record a content identity for the complete deployed asset graph: at minimum the index and its
answer-bearing JS, with SHA-256 (and optionally S3 version IDs for diagnosis). Put that identity
beside the derived directives in the private manifest, key the registry version by that identity,
and fail closed when the run observes different assets. Because pinning only the index does not pin
its relative script imports, either load versioned dependencies or verify the browser-loaded
dependency bodies too. Extract the object literals with a static, allowlisted parser; do not
execute downloaded JavaScript in the authoring environment.

This does not invalidate the feasibility result for the source fetched on 2026-08-09. It is
required before repeated step-6 evidence can be attributed to a stable family version.

### Should-fix 5 — Distinguish a feasibility-green result from formal §5 completion

The governing spec says §5 succeeds only when both graded instances are mechanically driven and
wire-verified twice; anything less is a failure that halts the Greenhouse migration
(`docs/exec-plans/current/epics/automated_testing/mer-5865-strict-framework-spec.md:702`). The spike
simultaneously says that evidence remains and that the gate has passed. Those statements are only
compatible if the gate is explicitly narrowed to “registry work may proceed because no mechanical
drive blocker is known,” while the migration stays gated on the step-6 two-success evidence.

Amend §5 or mark its formal gate open. Narrowing the status dominates treating §5 as complete
because it preserves the approved wire-verification stop while allowing the registry work needed
to obtain that evidence.

### Nit 1 — The sandbox item is not an untested assumption in the current Torus host

The rendered iframe has `src`, `scrolling`, `allow`, and accessibility attributes but no `sandbox`
attribute (`assets/src/components/parts/janus-capi-iframe/ExternalActivity.tsx:1234`). Therefore
sandboxing cannot explain a standalone-versus-in-lesson drive difference in the current runtime;
remove it from this spike's unknowns. Whether third-party CAPI iframes should be sandboxed is a
separate security/compatibility decision and must not be introduced during this registry change.

## Gate assessment

**GATE-VERDICT-STANDS for drive feasibility.** The decisive evidence is that the actual authored
fresh-run config pushes no solution/disable state, the Torus iframe applies no sandbox restriction,
and the remaining absorption difference consists of fixed disabled cells that the driver can
assert and skip. The Greenhouse migration itself remains gated on the step-6, twice-consecutive
wire verification required by §5.

Counts: **0 blocker, 5 should-fix, 1 nit.**

---

# WRITER RESPONSE (Claude, 2026-08-09) — all 6 folded into the spike doc

SF1 (readiness = handshake + topology + showCorrect false + enabled selects), SF2 (drive the
14 editable absorption selects only; the 4 disabled cells are asserted preconditions), SF3
(expectedPayload = grading rule only; readback stronger, ten signals, showCorrect excluded;
savedBarrier = the stamped-readback state, not the broad prefix), SF4 (registry version =
SHA-256 content identity of the deployed asset graph, fail closed on drift, static parser for
derivation), SF5 (gate statement narrowed: registry work may proceed; §5 formal gate stays
OPEN pending step-6 wire evidence), nit (sandbox removed from unknowns — no sandbox attribute
in the current host, verified). No code exists for this step yet, so all dispositions are doc
amendments; they become the step-6 registry entry's requirements.

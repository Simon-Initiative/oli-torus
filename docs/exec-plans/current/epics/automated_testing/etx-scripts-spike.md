# etx-scripts spike — MER-5865 step 0 (§5)

**Status:** drive mechanism SOLVED, scripted-drive PoC green (2026-08-09); Codex consult
2026-08-09: GATE-VERDICT-STANDS, 0 blockers, 5 should-fix folded below
(`reviews/mer-5865-etx-spike-consult.md`).
**Gate statement (per consult SF5, precisely narrowed):** registry work MAY PROCEED — no
mechanical drive blocker is known. The §5 formal gate stays OPEN until step 6 delivers the
twice-consecutive in-lesson wire verification; the Greenhouse MIGRATION remains gated on that
evidence, not on this document.

## The two graded instances (Exploration: Decoding the Mystery of Greenhouse Molecules)

| Screen (position) | Part id | Rule | Sim |
|---|---|---|---|
| Molecular Properties (20) | `molecularPropertiesTable` | `stage.molecularPropertiesTable.Correct equal true` | `.../molecular-properties-table/properties-table/index.html` |
| Investigating Molecules and Light (28) | `absorptionTable` | `stage.absorptionTable.Correct equal true` | `.../molecular-properties-table/absorption-table/index.html` |

Both live on the public `etx-scripts.s3.us-west-2.amazonaws.com` bucket. Three more instances
in the lesson are static tables (ungraded). The other Real Chem etx instances (d-orbitals ×4)
are all ungraded.

## Mechanism (from the sims' own source — phase 1)

Both sims are plain HTML tables of **native `<select>` elements** with deterministic ids
(`{molecule}BondType`, `{molecule}BondPolarity`, `{molecule}MolecularPolarity` — 27 selects in
properties-table, 18 in absorption-table). Grading is:

```
document.querySelectorAll("select").forEach(el => el.addEventListener("change", checkAll));
```

`checkAll()` compares every select's `.value` against an answer map declared IN the sim's own
JS, then sets the CAPI variables (`Correct` plus per-molecule `{x}Correct`) on a
`simcapi.CapiAdapter.CapiModel`. The deck's standard janus-capi machinery propagates those to
`stage.<part>.<var>` state.

**This is the opposite of the fill-in-the-blanks trap:** the sims listen to REAL native
`change` events — Playwright's `selectOption` fires them, so the interaction registers in the
sim's model with no jQuery-widget bypass. No hidden gesture, no canvas, no timing dance.

## Answer derivation

The correct values ship in the sims' public source (`scriptsProperties.js` `molecules` map;
`absorption.js` equivalent). The registry directive derives per-select values from the sim
source at authoring time — the manifest stays the single answer carrier, values never in the
repo. NOTE: the sims also expose a `showCorrect` CAPI flag that self-fills and disables the
table; the driver must never use it — it is the sim's show-solution path, not a student
action.

## Scripted-drive PoC (phase 3, standalone — 2026-08-09)

Throwaway Playwright spec against the S3-hosted properties-table directly: parsed the answer
map from the fetched source, drove all 27 selects via `selectOption`, observed the sim's own
verdict log flip to `everything correct`; changed ONE cell → `everything incorrect`
(40 deterministic verdict transitions). Absorption-table verified structurally identical
(same listener wiring, same `Correct` set, 18 selects).

## Remaining for full §5 success (not drive risk — run budget)

In-lesson wire verification, 2× consecutive per instance: `Correct: true` in a PATCH save,
evaluation `partInputs` carrying it, `actions.correct: true`. This is exactly the step-6
write-drive-verify loop with the registry entry — blocked only on the live-run budget (open
question 4), not on any unknown.

## Registry entry sketch (step 6 — amended per consult SF1–SF4)

- **family:** `etx_table`; **version = content identity of the deployed asset graph**, not the
  URL: SHA-256 of the index AND its answer-bearing JS (S3 URLs are unversioned and mutable —
  distinct `x-amz-version-id` histories observed). The identity lives beside the derived
  directives in the private manifest; a run observing different assets FAILS CLOSED. Directive
  extraction uses a static allowlisted parser over the object literal — never execute
  downloaded JS in the authoring environment.
- **detect:** janus-capi-iframe with etx-scripts src matching the pinned identity.
- **ready:** exact source identity + expected control topology + evidence the host handshake
  completed (config pushed after ON_READY — Torus delays it ~500 ms,
  `ExternalActivity.tsx:724,746`; DOM presence can win that race) + `showCorrect === false` +
  every student-editable select ENABLED.
- **answer:** `selectOption` over the EDITABLE selects only. The absorption table has 18
  selects of which 4 are disabled/prepopulated — they are fixed preconditions asserted in
  ready/readback, never driven (`selectOption` waits for enabled and would hang).
- **Three distinct contracts (SF3):** `expectedPayload` = the archived grading rule only
  (`stage.<part>.Correct equal true` — per-molecule fields are diagnostics, requiring them
  would be an unapproved strengthening); `readback` = STRONGER: selected DOM state + all ten
  verdict signals after the final change, `showCorrect` explicitly excluded as a mechanism;
  `savedBarrier` = the persisted correctness state after the driver-stamped readback, not any
  later save under the broad prefix.
- Resumed/contaminated attempts are NOT equivalent to fresh runs: Torus overwrites authored
  config with persisted state (`ExternalActivity.tsx:1030`) and an authored rule can mutate
  `showCorrect` — the framework's fresh-section-per-run assumption is load-bearing here.

## Untested assumptions (writer-known, for review)

1. ~~Standalone PoC vs in-deck initialization~~ **Resolved by consult:** both authored
   configs initialize every verdict and `showCorrect` to false (fresh-run branch safe), and
   the Torus iframe carries NO sandbox attribute (`ExternalActivity.tsx:1234`) — sandboxing
   was never a real unknown. The remaining in-deck requirements moved into the readiness
   contract above (handshake completion, resumed-attempt caveat).
2. The absorption-table sim was verified by source read + consult topology audit (4 disabled
   selects found), not yet driven live.
3. The `Correct` propagation path (CAPI model → deck save → evaluation payload) is assumed to
   be the standard janus-capi machinery proven for other widget families — not yet observed on
   the wire for these sims. This IS the open §5 evidence.

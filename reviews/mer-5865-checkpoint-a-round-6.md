# MER-5865 Checkpoint A — Review Round 6

## Verdict

**BLOCKED — 3 blockers, 0 should-fix findings, 1 nit.**

## Findings

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:762`** - The accepted
  decision is latched before drain/quiescence, and this branch never re-evaluates
  `finalizationStatus()`. If an accepted finalization is followed by a correlated duplicate that
  settles as categorical during the accepted branch, the late wire event restarts quiescence but
  does not switch the journal into terminalization. `markFrozenAccepted()` eventually rechecks the
  status and throws instead, leaving no completed-failure freeze or typed finalization-failure
  record. The fixture's seal fallback then skips end-of-run finalization invariants, so this
  completed-but-finalization-broken run can escape the auditable outcome required by §3.2. Recheck
  finalization status on observed arrivals and immediately before accepted freeze; a late rejection
  must enter terminalization and complete through the failure flavor. That state-aware transition
  dominates relying on the final guard because it preserves the categorical evidence as an audited
  outcome instead of converting it to an exception. Add the genuinely late duplicate crossing to
  the §8 **combined freeze STATE MACHINE** row; the existing crossed-order core tests settle both
  records before orchestration and do not exercise this race.

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveManifest.ts:427`** - Route coverage
  proves only edges whose sources are already in `manifest.scenario`, plus the terminal endpoint;
  the archive facts contain no selected-route start and the validator never proves the scenario's
  first step. A scenario that is a proper suffix of the archive-selected route can therefore
  classify its omitted route head as an exclusion and pass the inventory bijection, every checked
  edge, and the last-navigable check. That violates §3.8's requirement for exactly one step per
  screen on the route and leaves the §8 **bijection failures / unclassified exclusion** row open.
  Require an archive-proven route start (or, more directly, the complete selected route) and prove
  the scenario from head through terminal, including that every exclusion is off that route. A full
  selected-route proof dominates the current edge-plus-tail proof because it retains all valid
  branched-route manifests while rejecting strict-prefix omissions.

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveManifest.ts:371`** - Both archive
  dependency proof maps are optional, and line 462 treats an absent per-screen rule-reference entry
  as an empty set unless the manifest already declares a dependency. This makes the proof circular:
  when the manifest omits a real dependency or expectation, omitting that screen's archive-fact key
  makes the validator infer there was no rule reference and accept the underdeclaration. The same
  missing-evidence problem applies to effective dependency sets on screens declaring none. Require
  both maps to be total over the archive inventory, using explicit empty arrays where the extractor
  proved no references or dependencies, and reject missing or extra keys. Total facts dominate the
  optional fallback because valid dependency-free screens remain representable while unavailable
  archive evidence fails closed. The §8 **underdeclared cross-screen expectations** row remains open
  until a missing-fact witness rejects; current witnesses supply the very reference that drives the
  rejection.

- **nit, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:1578`** - The amended
  bidirectional permit allowlist can emit `wrong-role` for check-click or feedback-ack evidence on a
  navigation screen, but the formatter always says the permit occurred on a non-navigation screen.
  Use a role-neutral message (or include the observed role) so the redacted report describes the
  structured violation accurately.

## Verification

- Verified 2026-08-09: **237/237 student-delivery tests passed**.
- Scoped **tsc/eslint/prettier clean** for the reviewed material. The project-wide TypeScript
  invocation emitted only the two documented pre-existing `liveSocket` errors outside this scope.

---

# WRITER RESPONSE (Claude, 2026-08-09) — all 4 findings fixed. 240/240

## B1 (late categorical after the accepted latch) — FIXED
`awaitFreeze` no longer latches acceptance: the accepted drain loop re-evaluates
`finalizationStatus()` on every pass AND immediately before `markFrozenAccepted()`; a
correlated duplicate settling as categorical mid-drain enters terminalization and completes
through the completed-failure flavor with its typed finalization-failure record — an audited
outcome, never an exception into the seal fallback. New live-page witness: acceptance
observed, categorical duplicate lands during the drain, freeze flips to `completed-failure`
with `{reason: 'already_submitted'}` — the genuinely-late race, not the settled-before-
orchestration crossing.

## B2 (unproven route head) — FIXED
`ArchiveFacts.route_start_id` (required): the scenario must START at the archive-selected
route's entry, so head-through-terminal is now fully chained (start + every edge + `@end`).
Witness: a proper suffix classifying its omitted head as an exclusion — passes bijection,
edges and terminal, rejected by the start proof alone.

## B3 (optional maps circular) — FIXED
Both dependency-proof maps are REQUIRED and TOTAL over the archive inventory: an absent key
is missing evidence (fail closed, witnessed), an extra key is a facts/inventory mismatch
(witnessed); an explicit `[]` is the extractor's proof of "none". The old
declares-dependencies-but-no-facts special case dissolved into totality.

## Nit — FIXED. The wrong-role permit template is role-neutral.

Verification: 240/240, tsc clean (2 pre-existing liveSocket), eslint clean, prettier applied.
Zero commits.

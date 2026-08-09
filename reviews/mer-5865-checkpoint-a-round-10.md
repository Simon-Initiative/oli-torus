# MER-5865 Checkpoint A — Review Round 10

## Verdict

**BLOCKED — 4 blockers, 1 should-fix finding, 0 nits.**

## Findings

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveManifest.ts:356`** - The offline archive facts contain only screen IDs, so `validateRouteCoverage` can prove the route and inventory while never checking any screen definition's `resource_id` against the archive. Section 3.8 makes the archive resource ID part of each screen's identity, and this offline gate is the only valid place to check it because live imports remap resource IDs. A manifest can therefore carry the wrong archive activity identity and still pass every build-time proof. Carry the archive resource ID per screen in `ArchiveFacts`, require a total one-to-one mapping, compare every definition, and add wrong/missing/extra mapping witnesses.

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:391`** - A sealed run can still audit to zero violations. Sealed snapshots intentionally skip route cardinality here and all end-of-run invariants at line 760; their last visited window is open, so absence checks there are suppressed too. With no recorded operation failure or other positive journal defect, `auditRun` simply returns an empty array. That violates §3.2's guarantee that an ordinary bail cannot produce a clean sealed audit and can make the step-3 bail-equivalence gate pass if the wrapper misses a union member or fails to stamp the record. Add a dedicated positive violation when a sealed snapshot otherwise has no failure evidence, with empty- and partial-route witnesses that omit `operationFailures`.

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:1219`** - The through-response stability comparison does not distinguish a missing map key from a key whose stored value is `undefined`: `Map.get` returns `undefined` for both. `partEntries` accepts a path-only entry at lines 927-929, so a same-cardinality replacement of that path during the checking request can be judged stable; the old at-request path can then satisfy a presence-only grading expectation and yield a false-green cross-screen receipt. Require `throughResponse.state.has(path)` before comparing values, reject malformed path entries if they cannot be valid committed state, and add the same-cardinality key-replacement witness through `auditRun`.

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:144`** - The violation boundary is not redacted by construction as §3.1/§3.7 require. `ViolationFacts` still exposes unrestricted string slots such as `reason`, `planKind`, `planKind2`, and `terminal`, and the exhaustive formatter prints those slots directly. Current call sites and the canary happen to pass closed vocabulary, but the constructor accepts arbitrary text without a type error, recreating the exact future leak channel the closed fact model was meant to remove. Narrow every rendered categorical field to its existing closed union (including the explicit fallback where needed) and add compile-time/type-level coverage; keep free strings only for the identifiers and paths the spec explicitly permits.

- **should-fix, `assets/automation/src/systems/torus/tasks/AdaptiveManifest.ts:242`** - The runtime manifest validator checks an answer operation's `family` but never validates its optional `version` or `mode`, even though both are declared string components of the registry key. A non-string key component is returned as a typed `AdaptiveManifest` and survives the build boundary, contradicting the round-9 class-closure claim and deferring a general schema error until step-4 registry execution. Reject any defined `version` or `mode` that is not a non-empty string and add accept/reject witnesses for both fields; family-specific directive validation can remain with the registry as documented.

## Verification

- Verified 2026-08-09: **252/252 student-delivery tests passed**.
- Scoped **tsc/eslint/prettier clean** for the reviewed material. The project-wide TypeScript invocation emitted only the two documented pre-existing `liveSocket` errors outside this scope.

---

# WRITER RESPONSE (Claude, 2026-08-09) — all 5 fixed. 257/257. CHECKPOINT A CLOSED.

Closure basis: human call (protocol "or Human calls it"), your ENDORSE-WITH-AMENDMENTS in
reviews/mer-5865-checkpoint-a-closure-consult.md, both amendments folded verbatim into the
spec's materiality policy, and your confirmation that nothing material from rounds 1–10
remains open once these five land:

- **B1 (archive resource_id)** — `ArchiveFacts.resource_ids`, total map, per-definition
  equality; wrong/missing/extra witnessed.
- **B2 (clean sealed audit)** — `seal-without-evidence` sentinel: a sealed snapshot with zero
  violations is itself a violation; witnessed empty and stamped-suppression cases; the
  legal-rotation witness now asserts exactly the sentinel.
- **B3 (stability key semantics)** — `Map.has` before value comparison; path-only entries are
  never committed state (`hasValue` on part entries); same-cardinality key-replacement and
  path-only witnesses.
- **B4 (redaction typing)** — `reason`/`planKind`/`planKind2`/`terminal` narrowed to their
  closed unions; compiled clean with zero call-site changes, which is itself the proof the
  vocabulary was already closed — now the compiler enforces it.
- **SF (version/mode)** — non-empty-string validation for both registry-key components;
  accept/reject witnessed. Your round-9 class-closure correction acknowledged: my sweep
  missed nested operation fields.

Permit-stamp deferral escalation recorded in the spec DEBT list per your consult: material at
B0 if step 4 has not delivered the journal-domain stamps.

Verification: 257/257, tsc clean (2 pre-existing liveSocket), eslint clean, prettier applied.
Zero commits — the human commit gate is next.

# MER-5865 Checkpoint A — review round 5

## Verdict

**BLOCKED — 2 blockers, 1 should-fix finding, 0 nits.**

## Findings

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:913`** - The
  `savedBarrier` check bounds only the PATCH request's `requestSeq`. Although it requires that the
  record eventually receive a 2xx status, it never requires `responseSeq < checkClick.seq`. A save
  can therefore start after readback, remain in flight while the driver clicks Check, commit only
  after that click, and later satisfy the frozen audit. That does not prove the committed state was
  available to the evaluation and admits the stale-state race the barrier was introduced to close.
  Bounding the already-recorded response event is strictly stronger evidence than bounding request
  initiation and requires no new instrumentation: require the successful save's `responseSeq` to
  precede the check-click permit, and add the inverse-order mutation witness.

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveManifest.ts:477`** - Coverage of
  archive `rule_prior_state_refs` is enforced only when a reference's owner differs from the current
  screen. Section 3.6 and this module's own contract require **every** expected-correct rule
  reference to have a covering grading expectation. A same-screen rule reference can consequently
  be omitted from the manifest, pass build validation, and leave the local receipt checking only a
  subset while relying on the server verdict for the omitted rule input. The owner distinction is
  relevant to dependency declaration, but not to expectation completeness; an unconditional
  `coveredByExpectation` check dominates the current foreign-only check because it preserves every
  covered manifest while rejecting the additional underdeclared class. Add the same-screen
  underdeclaration row alongside the existing cross-screen witness.

- **should-fix, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:395`** - Permit role
  validation is one-directional: it rejects `widget-button` outside navigation, but navigation
  steps silently accept `check-click` and `feedback-ack`, and duplicate detection omits
  `widget-button`. The approved navigation amendment says the driver stamps no acknowledgment
  permit there, and the navigation branch exits before these extra permits are ever consumed or
  reported. Thus contradictory or duplicated driver evidence can survive a full audit. Validate a
  role-specific permit allowlist and duplicate cardinality for every permit kind, with navigation
  wrong-kind and duplicate-widget witnesses.

## Verification

- Verified 2026-08-09: **234/234 student-delivery tests passed**.
- Scoped **tsc/eslint/prettier clean** for the reviewed material. The project-wide TypeScript
  invocation emitted only the two documented pre-existing `liveSocket` errors outside this scope.

---

# WRITER RESPONSE (Claude, 2026-08-09) — all 3 findings fixed. 237/237

## B1 (barrier commit order) — FIXED
The barrier now requires the save's RESPONSE (`responseSeq`) to precede the check-click permit,
not merely its request — an in-flight save at click-time proves nothing about what the
evaluation read. Inverse-order witness added: request inside the window, response after the
click → `saved-barrier`.

## B2 (same-screen underdeclaration) — FIXED
`coveredByExpectation` is unconditional: every archive rule reference — same-screen included —
must have a covering expectation; the owner distinction now governs only dependency
DECLARATION. Same-screen underdeclaration witness added alongside the cross-screen one.

## SF (permit allowlist) — FIXED
Role allowlist binds both directions: navigation steps accept `widget-button` only (per the
approved amendment — the driver performs no check click and no acknowledgment there); other
roles accept `check-click`/`feedback-ack` only. Duplicate cardinality now covers all three
kinds. Witnesses: `check-click` on a navigation step → `wrong-role`; duplicate
`widget-button` → `duplicate`.

Verification: 237/237, tsc clean (2 pre-existing liveSocket), eslint clean, prettier applied.
Zero commits.

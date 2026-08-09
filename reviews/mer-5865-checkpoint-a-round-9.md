# MER-5865 Checkpoint A — Review Round 9

## Verdict

**BLOCKED — 1 blocker, 2 should-fix findings, 0 nits.**

## Findings

- **blocker, `assets/automation/src/systems/torus/tasks/AdaptiveManifest.ts:215`** - `validateAdaptiveManifest` never validates the optional `combine_feedback` field before returning the raw object as an `AdaptiveManifest`. A truthy non-boolean scalar therefore passes the build gate and is coerced to `true` by the oracle at `AdaptiveOracle.ts:611`, `:823`, `:1316`, and `:1328`, changing the footer event-selection branch and every downstream plan/obligation while recorded-plan replay can still agree with the same malformed manifest. This defeats the fail-closed v2 schema and the §8 combine-feedback matrix at its input boundary. Reject any defined `combine_feedback` value that is not a boolean, and add a manifest-validation witness proving a non-boolean scalar cannot reach planning.

- **should-fix, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:282`** - Resolved operation failures are validated against the scenario's expected screen rather than the observed visit. Section 3.2 assigns resolved failures to the observed screen and reserves expected-step derivation for `identity-unresolved`; when the route itself has diverged, the current comparison marks an accurately observed screen contradictory and accepts a claimed expected screen even though no visit supports it. It also accepts a resolved failure for an in-scenario step that has no visit at all. Require every resolved failure to have a visit at `expectedStepIndex` and match that visit's screen; keep scenario-derived attribution only for `identity-unresolved`. Add route-divergent and missing-visit witnesses.

- **should-fix, `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:632`** - The unused-permit audit checks a `feedback-ack` only when `firstPlan !== null`. On a fully audited window with no usable first evaluation, a stray acknowledgment permit is therefore never reported as unused, even though §3.4 licenses it only after a feedback plan and the permit-inventory contract is meant to account for every permit. Other evaluation violations keep the run non-green, but the positive evidence is incomplete and the existing unused-permit witness covers only `check-click`. Treat a missing first plan as an unused acknowledgment too, and add zero-evaluation and unusable-first-evaluation witnesses.

## Verification

- Verified 2026-08-09: **248/248 student-delivery tests passed**.
- Scoped **tsc/eslint/prettier clean** for the reviewed material. The project-wide TypeScript invocation emitted only the two documented pre-existing `liveSocket` errors outside this scope.

---

# WRITER RESPONSE (Claude, 2026-08-09) — all 3 findings fixed. 252/252

## B1 (combine_feedback unvalidated) — FIXED, class already closed
Non-boolean `combine_feedback` fails the build by name. Class sweep ("optional schema field
returned unvalidated"): audited every field of ScreenDefinition, ScenarioStep, exclusions and
the manifest root — `combine_feedback` was the ONLY unvalidated one; the class closes with it.
Witness: `'yes'` rejected, `true` accepted.

## SF1 (attribution vs observed visit) — FIXED
Resolved failures anchor to the VISIT at their expected step: observed-screen naming on a
diverged route is legal, scenario-screen naming is contradictory, and a resolved failure for
a step with no visit is contradictory. Scenario derivation stays reserved for
identity-unresolved. Witnesses: route-divergent both directions, missing-visit; the round-7
matrix expectation was updated (a beyond-domain resolved failure now also counts as
contradictory — no visit can support it).

## SF2 (stray ack with no usable first plan) — FIXED
`firstPlan === null` (zero evaluations or unusable first) now marks a feedback-ack unused on
full audits. Witness: ack on a zero-evaluation content window.

Verification: 252/252, tsc clean (2 pre-existing liveSocket), eslint clean, prettier applied.
Zero commits.

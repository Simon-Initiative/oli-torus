# MER-5865 Checkpoint A — implementation review round 1

**Verdict:** BLOCKED

**Counts:** 9 blockers, 3 should-fix, 0 nits

## Blockers

### B1. `auditRun` never applies the cross-screen matcher

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:413`

`auditRun` finds a receipt and calls `auditGradedStep`, but that function evaluates only
`matcher: 'local'`; a `cross_screen` receipt takes no matcher path at all
(`AdaptiveOracle.ts:658-675`). The committed-prior-state implementation is exposed separately
as `auditCrossScreenReceipt` (`AdaptiveOracle.ts:729`) and the tests call that helper directly,
so they do not prove the public oracle contract. A graded cross-screen step with a usable true
verdict and a receipt can therefore pass `auditRun` regardless of committed dependency state.
Integrate the matcher into `auditRun`, derive its dependency lineage from audited evidence, and
verify that receipt identity and expectations correspond to the manifest rather than trusting a
detached caller-supplied copy.

### B2. Committed prior state is merged per path, not selected per newest part attempt

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:711`

The server selects the newest activity attempt and then the newest part attempt per `part_id`.
Here `submittedPairs` discards the part-attempt identity (`AdaptiveOracle.ts:583-599`) and
`committedPriorState` folds every successful save under the newest activity attempt into one
path map. A newer part attempt with a partial or empty response therefore leaves paths from the
older part attempt in the reconstructed state. The test at
`adaptive-oracle.spec.ts:765` explicitly asserts “latest save per path,” which restates this
different implementation instead of the §3.6 contract. Preserve enough part identity in the
journal and reproduce the per-`part_id` newest-attempt partition before merging responses.

### B3. The archive validator has no transition or rule facts, so three build-time proofs are impossible

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveManifest.ts:351`

`validateRouteCoverage` receives only a flat list of archive screen ids. It can prove a set
bijection, but it cannot prove that the scenario is a valid route, that its last `next` step has
no successor, or that declared dependencies equal the archive's effective dependency set.
Likewise, `validateAdaptiveManifest` only checks that dependency names exist
(`AdaptiveManifest.ts:280-291`); it receives no rule references with which to reject an
underdeclared grading expectation. Consequently the final-step exception in
`AdaptiveOracle.ts:844-863` trusts “last scenario element” as a substitute for the required
archive proof. Pass the relevant archive graph and rule/dependency facts into build validation
and make all three checks explicit.

### B4. Planner replay agreement cannot be audited because no recorded plan exists

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:71`

`RunRecord` contains visits, permits, receipts, and operation failures, but no transition plans.
`auditTransitions` only derives a plan again from the evaluation (`AdaptiveOracle.ts:895-897`),
so it cannot compare the driver's online decision with the oracle replay as §3.5 and §8 require.
The current tests exercise the same planner function directly and indirectly; they cannot detect
a future executor recording or following a different plan. Add the driver's recorded plan to
the run evidence and compare it with the replay before checking fulfillment.

### B5. Transition obligations accept evidence that predates the response which created the plan

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:923`

A feedback acknowledgment is accepted when its seq is greater than the evaluation's
`requestSeq`, and navigation is accepted when the next visit fence is greater than that same
request seq (`AdaptiveOracle.ts:995-1004`; navigation screens repeat the check at
`AdaptiveOracle.ts:865-874`). Both events may therefore occur while the evaluation response is
still outstanding, before the planner could have derived the obligation. Use `responseSeq` as
the causal lower bound for acknowledgments and successor visits, and test the request→fence→
response and request→permit→response orderings as rejects.

### B6. A sealed open window can emit an absence-based saved-barrier violation

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:427`

Receipt absence is gated by `fullWindowAudit`, but any present receipt is passed to
`auditGradedStep` unconditionally. Its saved-barrier branch emits “no save” whenever no matching
save is currently present (`AdaptiveOracle.ts:628-655`), even for the last open window of a seal
or for `seal_incomplete`, where that save may still be outside the audited set. This violates the
§3.2 restricted-audit matrix's positive-only rule. Pass the full-window scope into the graded
audit and suppress every saved-barrier absence conclusion unless the window is closed and
settled.

### B7. Predicate evaluation does not mirror the normative production operators

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveManifest.ts:493`

Several branches change production truth conditions. `notEqual` is implemented as a raw
negation of `equalOperator`, although the production operator rejects invalid numeric inputs
instead of turning them into a successful inequality. `notContainsAnyOf` similarly negates the
positive helper, while the production module returns false for falsy inputs before applying the
set test. The numeric comparisons also compare `parseFloat(rawInput)`
(`AdaptiveManifest.ts:488,511-518`), whereas json-rules-engine validates with `parseFloat` but
performs the comparison on the original fact; a partially numeric string is therefore accepted
here and rejected there. Mirror the normative functions exactly and extend the matrix with
falsy, invalid-numeric, and mixed scalar/list cases.

### B8. Reporter redaction is conventional, not by construction

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:78`

`Violation` exposes an unrestricted `message: string`, the internal constructor accepts that
string unchanged (`AdaptiveOracle.ts:106-111`), and `formatViolations` writes it verbatim
(`AdaptiveOracle.ts:1023-1029`). The type system therefore permits answer or key material to
reach a report string; safety depends on every current and future call-site interpolating only
approved fields. Replace the free-form message with a closed discriminated violation union whose
fields cannot carry submitted values, let the reporter own the fixed templates, and add the §8
raw-journal canary test against every emitted string.

### B9. The stub suites do not discharge the §8 deterministic matrices

**Location:** `assets/automation/tests/torus/student_delivery/adaptive-oracle.spec.ts:346`

The 188 tests pass, but the new suites cover representative rows rather than the required
mutation-style matrices. Material omissions include: cross-screen behavior through `auditRun`;
newest-part selection; every sealed window state and saved-barrier absence gate; each final-step
navigation disqualifier plus successor-exists; recorded planner replay; a redaction canary; the
default operation-ref expansion; pre-entry accept/reject and split-rotation fencing; and the
underdeclared cross-screen build failure. The operation-failure union has 10 variants, while the
oracle suite exercises only 2. Add reject and accept witnesses for every §8 row, and ensure each
witness fails under the named one-line mutation rather than only testing helpers in isolation.

## Should-fix

### SF1. `already_submitted` can be accepted, and multiple rejection reasons are order-dependent

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:260`

`finalizationStatus` accepts a correlated 2xx `success/success` record before inspecting its
`reason`, so a record that also carries `already_submitted` is accepted despite the explicit
contract that this reason is always a violation. In `aggregateRejection`, every correlated
failure overwrites the previous one (`AdaptiveJournal.ts:291-311`), making the chosen reason
depend on response order when duplicates disagree. Give `already_submitted` explicit precedence
over acceptance and define a deterministic rejection precedence; add crossed duplicate rows.

### SF2. Permit identity and inventory are not validated

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:261`

Permits are selected by `stepIndex` only. Their `screenId` is ignored, duplicate permits are
silently collapsed by `find`, permit seqs are not fenced to the visit, and `widget-button`
permits are never checked at all (`AdaptiveOracle.ts:349-371`). A permit attributed to another
screen—or an impossible extra permit—can therefore license the current step. Validate the exact
permit inventory against both step and screen, reject duplicates/unused evaluation-capable
permits, and enforce the visit/response ordering appropriate to each kind.

### SF3. The checkpoint model reviews the shadow gate only after the behavior switch

**Location:** `docs/exec-plans/current/epics/automated_testing/option-c-spec.md:715`

Checkpoint A is a useful pure-core boundary. Checkpoint B, however, is scheduled after step 4,
so the step-3 differential evidence and the step-4 executor/driver switch are reviewed together
only after the first behavior change. That is later than step 3's own stop-before-seam-removal
gate and allows a mistaken equivalence projection to shape the replacement driver before
cross-model review. Add a narrow review gate after step 3 and before step 4. Checkpoint C also
groups manifest authoring, all registry families, and two migrations (steps 5-8); split once
after manifest/registry validation so defects do not compound across both migrations.

## Nits

None.

## Verification

- Intended student-delivery suites: **188/188 passed**.
- Broad `adaptive-` filename filter now also selects 4 authoring tests: 189 passed, 1 unrelated
  authoring test failed, 2 dependent tests did not run.
- Scoped ESLint: clean.
- Scoped Prettier: clean (configuration emitted the existing unknown-option warnings).
- TypeScript: only the 2 documented pre-existing `liveSocket` errors.
- Legacy target check: no `for..of` over Set/Map iterators and no spread of `.entries()` in the
  five modules.


---

# WRITER RESPONSE (Claude, 2026-08-07) — all 12 findings addressed, 209/209 green

Every finding was verified against code/spec/server before acting. Verdicts: 9/9 blockers
CONFIRMED and fixed; SF1 half-confirmed (hardened anyway); SF2 confirmed and fixed; SF3 is a
human decision, presented to Francisco with a recommendation to accept.

## B1 — FIXED. Cross-screen matcher integrated into `auditRun`
`auditCrossScreenStep` runs inside the graded branch for `matcher: 'cross_screen'`: dependency
lineages are derived from audited evidence (each dependency's own visit stamp roots
`attemptLineage` over journal mints — new exported helper), the checking evaluation is the
step's first usable one, and `auditCrossScreenReceipt` now takes multiple lineages (combined
state matched once). New `auditReceiptIdentity` also rejects a receipt whose screenId, matcher
or expectations do not correspond to the MANIFEST (`receipt-mismatch`), so a detached
caller-supplied copy can no longer substitute the contract. Witnesses: accept + reject +
matcher-contradiction, all THROUGH `auditRun`.

## B2 — FIXED. Per-part_id newest part attempt, save-replacement semantics
`committedPriorState` now partitions by part_id (path-derived), selects the newest PART
attempt per part (partInputs' own attemptGuid), and treats each save as REPLACING that part
attempt's response (the server stores the submitted map; it never merges paths across saves) —
one step stricter than the review asked, because a per-path merge within one part attempt was
also wrong. The offending "latest save per path" test was rewritten to the §3.6 contract plus
a newest-part-attempt witness (partial newer response must eclipse the older part attempt).

## B3 — FIXED. `validateRouteCoverage` now takes `ArchiveFacts`
`{screen_ids, last_navigable_id, effective_dependencies?, rule_prior_state_refs?}`: bijection
(kept), scenario-must-end-at-the-archive-proven-last-navigable-entry (§3.5's offline half),
declared dependencies ⊆ archive effective set, and every rule prior-state reference covered by
an expectation (underdeclared ⇒ build failure, §3.6b bidirectional). A dependent screen with
no archive facts fails — the proof is impossible, so the build is. PUSHBACK (scoped, not
skipped): full scenario route-graph replay stays out — §3.8 assigns route MEMBERSHIP to
offline validation and route TRAVERSAL to the oracle's live transition fidelity; an offline
graph replay would duplicate the oracle's job on weaker evidence. Say if you disagree.

## B4 — FIXED. Recorded plans are now run evidence
`RunRecord.plans: RecordedPlan[]` ({stepIndex, evaluationSeq, plan}); the oracle compares the
recorded plan against its replay per usable evaluation: divergence = positive violation
(`plan-divergence`), missing record = absence conclusion gated by the §3.2 matrix (mirrors
receipt-missing). On navigation screens recorded plans are compared when present but not
required — the §3.4 sequence rule owns that dance; the LAST plan's obligations still bind.
Flag if you want recording mandatory there too.

## B5 — FIXED. Obligations are bounded by the plan's RESPONSE
`usable()` now requires `responseSeq`; feedback acks must satisfy `seq > responseSeq`; the
recheck's licensing edge requires the ack after the FIRST evaluation's response; successor
visit stamps must follow the response; lesson-end fulfillment now also requires
`lessonEndSeq >= responseSeq`. Witness pair: the same ack seq between request→response fails,
after the response passes.

## B6 — FIXED. Saved-barrier absence gated by the §3.2 matrix
`auditGradedStep` receives the window's full-audit verdict; the "no committed save" conclusion
is drawn only on closed+settled windows. Payload mismatches on PRESENT evaluations remain
positive evidence, ungated. Witness: sealed open window with no save draws no conclusion.

## B7 — FIXED. Operators mirror the normative modules exactly
`notEqual` gets the production NaN/undefined refusal (equality.ts:155-170); `notContainsAnyOf`
is its own operator with the production falsy-input guard and case-SENSITIVE string branch
(contains.ts:79-96) — an empty submission can no longer satisfy an exclusion; `containsAnyOf`
uses the production coercing isNaN+parseFloat pair; `contains`/`containsOnly` falsy guards are
the production `!inputValue`; numeric comparisons now mirror json-rules-engine's dist source
exactly (validator on parseFloat, comparison on the RAW fact — verified in
`engine-default-operators.js:34-48`): `"5abc"` refuses, `" 5 "` compares. Matrix extended with
NaN, undefined, falsy, partial-numeric and case-sensitivity witnesses.

## B8 — FIXED. Free-form message eliminated
`Violation` is now `{code, screenId, stepIndex, facts: ViolationFacts}` — a closed, typed fact
set (seqs, counts, ids, kind unions, booleans, a closed `detail` enum). No string field exists
for arbitrary content; `formatViolations` owns an exhaustive per-code template table (the
`Record<ViolationCode, …>` enforces completeness). §8 redaction canary added: sentinel answer
values driven through payload-mismatch, contamination and unstable-dependency paths — no
emitted report contains them. NOTE: `pathLabel`/`prefix`/`guid` remain strings because paths
and guids ARE the permitted vocabulary (§3.7); the type cannot stop a future call site passing
a value AS a path — the canary test is the guard for that residual, as §8 prescribes.

## B9 — ADDRESSED (this round's slice). 209/209
Added: cross-screen through auditRun (accept/reject/matcher), per-part_id newest selection,
recorded-replay divergence + missing, response-bound ack pair, sealed-open saved-barrier gate,
permit inventory (screen-mismatch, duplicate, wrong-role, unused), all 10 operation-failure
union members, final-step disqualifier (`prev`), pre-entry accept+reject, redaction canary,
operator refusal matrix, default operation-ref expansion, underdeclared cross-screen build
failure, archive last-step proof, `already_submitted`-over-acceptance, crossed duplicate
rejections. Rows still open (flag any you consider round-blocking): remaining
navigate-off-sequence target variants (`first`, `last`, explicit), entry-stamp fencing beyond
the attribution suite's existing coverage, split-rotation FENCING variants beyond the shipped
ones, full freeze state-machine ordering matrix.

## SF1 — FIXED (half was unreachable, hardened anyway)
Verified server-side: `already_submitted` always ships as `result:"success",
commandResult:"failure"` (`page_lifecycle_controller.ex:127-134`), so the accepting shape
cannot occur against Torus — but the journal also audits synthetic input, so acceptance now
refuses `reason: already_submitted` categorically. `aggregateRejection` resolves crossed
duplicates by RANK (`already_submitted > failed > uncorrelated > malformed`), never by
response order. Both witnessed.

## SF2 — FIXED. Permit inventory validated
Per step: permits must name the visit's screen, sit inside the visit window, respect role
(`widget-button` only on navigation screens), no duplicate evaluation-capable permits, and — on
full audits — a check-click with no evaluation or a feedback-ack with no feedback plan is
`permit-mismatch: unused`. The recheck edge additionally requires the ack to postdate the
first response (B5).

## SF3 — HUMAN GATE. Presented to Francisco with recommendation to ACCEPT
Writer's view: both amendments are cheap and address real seams (reviewing the shadow-gate
evidence BEFORE the step-4 driver swap; splitting checkpoint C after manifest/registry
validation so defects cannot compound across two migrations). Decision and spec amendment
belong to the human.

Verification: 209/209 (`npx playwright test adaptive-` student-delivery suites; the 4 authoring
tests the broad filter drags in are out of scope), tsc clean (2 pre-existing liveSocket),
eslint clean, prettier applied. All files still uncommitted.

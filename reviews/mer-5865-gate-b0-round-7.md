**Verdict:** GATE-BLOCKED

**Counts:** 3 MATERIAL; 2 recorded-non-material.

**Decisive reason:** the fresh artifacts are credible and all three round-6 mutations are red,
but the gate still has three live false-green paths. It does not fully recompute the §3.2
finalization acceptance predicate, its save-status rule can be bypassed by hollowing a save's
attempt identity, and the C10 claim of an exact 65-entry driver-evidence multiset is not pinned:
a common-mode journal/ledger plan substitution passed with one green at 64 and the other at 65.

## MATERIAL findings

### M1 — The green envelope omits three mandatory finalization-acceptance predicates

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:249-305`;
`assets/automation/src/systems/torus/tasks/AdaptiveJournal.ts:252-296`;
`assets/automation/tests/torus/student_delivery/mer5865-shadow-gate.spec.ts:195-209,293-340`

Section 3.2 defines acceptance as parsed, correlated, completed 2xx, `result: success`,
`commandResult: success`, and not categorically `already_submitted`. `finalizationStatus()`
implements all of those terms. `validateGreenEnvelope()` independently rechecks completion,
2xx, action, `commandResult`, and all three correlation identities, but never checks
`parseError === null`, `finalization.result === "success"`, or
`finalization.reason !== "already_submitted"`.

I changed each omitted term independently in a fresh green dump while retaining the serialized
accepted snapshot. Each mutation passed the full gate 5/5 with zero in-scope violations and zero
unexplained differences. This is a direct false-green: a record that the journal's own acceptance
contract categorically rejects is still licensed as the terminal evidence for a green replay.

**Required fix:** make the replay predicate exactly coextensive with §3.2 and
`finalizationStatus()`—including parsed state, both success fields, and the categorical reason.
Add independent green-entry-point witnesses for a non-success `result`, a parse error, and
`already_submitted`; do not rely on the snapshot's precomputed freeze flavor. Split C4 into atomic
identity and acceptance rows so these predicates cannot be hidden inside one compound claim.

### M2 — Hollowing a save's attempt identity bypasses the advertised status semantics

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:332-358`;
`assets/automation/tests/torus/student_delivery/mer5865-shadow-gate.spec.ts:342-358`;
`docs/exec-plans/current/epics/automated_testing/mer-5865-shadow-gate-evidence.md:146`

The r6 rule advertises that save statuses admit only a 2xx pre-evaluation commit or a 403
post-evaluation `only_active` rejection. The validator, however, silently skips any save whose
terminal is not `completed`, whose `attemptGuid` is null, or whose attempt has no evaluation.
The per-graded-screen presence check is separate and needs only one surviving own-state save.

I took a redundant pre-evaluation 2xx save from a fresh green, retained its record and payload,
set its attempt identity to null, and changed its status to 500. Another save for that graded
visit continued to satisfy C7. The full gate passed 5/5. Thus identity hollowing removes the
record from C8 before the status predicate runs, masking exactly the server-error shape that the
r6 closure says is red.

This does not challenge the documented 403 pattern: the fresh captures really contain the stable
13 pre-evaluation 2xx / 16 post-evaluation 403 split, and rejected post-evaluation flushes are not
being called commits. The defect is that the rule is not fail-closed over the identity needed to
classify a save.

**Required fix:** for every captured completed save, require a nonempty attempt identity and a
determinable evaluation boundary before applying the status rule; an unclassifiable completed
save must be red, not skipped. Add attempt-identity hollowing and no-matching-evaluation witnesses
through the real gate entry point. If C8 is intentionally narrower, narrow the claim and prove the
excluded records have no decision path; the present “nothing else” claim is unsupported.

### M3 — C10 claims an exact 65-entry multiset, but the gate accepts cross-green shrinkage

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:79-130`;
`assets/automation/tests/torus/student_delivery/mer5865-shadow-gate.spec.ts:91-102`;
`docs/exec-plans/current/epics/automated_testing/mer-5865-shadow-gate-evidence.md:148`

The test compares the actual driver-evidence inventory with an expected inventory derived from
the same dump's journal and manifest. It never pins the reviewed 65-entry key set or cardinality,
and it never requires the two green inventories to match each other. C10 nevertheless claims the
exact 65-entry multiset and the composition rule says every row must hold.

I replaced one graded response's plan semantics with a different legal navigating plan and made
the shipped ledger transition agree. The archive route, grading payload, verdict, visit/ledger
envelopes, and all mandatory evidence remained intact. The full gate passed 5/5 while reporting
64 driver-evidence violations for the mutated green and 65 for the untouched green. This is the
semantic common-mode replacement required by the adopted proof protocol; the current r4 omission
witnesses do not exercise it.

**Required fix:** resolve the contract mismatch explicitly. If 65 and its keyed multiset are a
gate claim, compare each green against a reviewed reference independent of the dump and require
cross-green equality; add this 64/65 semantic-replacement witness. If the intended guarantee is
only run-relative expected/actual equality, remove “65” and “exact reviewed multiset” claims from
the HANDOFF/evidence table and obtain the human's approval for that narrower proof. The current
implementation and C10 cannot both be true.

## Recorded non-material findings

### N1 — `realpath` still leaves a check/write ancestor-replacement race

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowCapture.ts:32-45,233-246`

The destination is created and resolved before validation, which closes the unresolved-component
bug from round 6. But validation and `writeFile` still use a pathname, not an already-opened
directory handle. A concurrent actor can rename a validated ancestor and replace it with a
symlink between `realpathSync` and `writeFile`, redirecting the private dump. The inspected fresh
artifacts are in the private scratchpad and no such redirect is evidenced, so this has no path to
the B0 decision, replay comparison, causal license, or screen attribution.

**Owner:** step-3 capture harness, before any additional live capture. Use a no-follow/handle-based
write discipline or stop claiming the check and write cannot diverge.

### N2 — Claims table v3 does not conform to its required structure

**Location:** `docs/exec-plans/current/epics/automated_testing/mer-5865-shadow-gate-evidence.md:137-151`

The adopted protocol requires `Spec/gate source` and `Positive witness` columns; both are absent.
C6 uses a compound class (`independent-artifact ... + journal count`) rather than one of the three
permitted reference classes, and C13 combines the shipped-bail envelope with the oracle
same-screen result. Those form defects do not independently change the current gate decision, but
they made the bidirectional audit materially harder and helped conceal the unsupported C4/C8/C10
claims above.

**Owner:** claims-table author, before the B0 resubmission. Restore the required columns, split
compound rows, and reuse stable IDs in the standing tests.

## Fresh artifact judgment

The recapture itself is internally consistent and materially stronger than the retired set:

- both greens have a populated DOM correlation, `green` / `accepted`, frozen accepted snapshots,
  22 visits, 22 ledger entries, 23 evaluations, one creation, one finalization, and 29 saves;
- both greens reproduce the 65 driver-evidence count, exactly one intentional delta, and the same
  13 pre-evaluation 2xx / 16 post-evaluation 403 split;
- the retired greens have the same route, evaluation, mint, finalization, save, and status counts,
  but no exported correlation, as expected;
- the fresh bail is sealed and complete, poison-stamped, and the replay finds exactly the required
  same-screen `verdict-not-correct` violation.

The writer running the server and captures itself does not by itself invalidate the evidence.
The DOM and wire references share one recorder/serializer, as disclosed, so their independence is
relational rather than provenance-authenticated. I found no artifact fact suggesting the stated
environment or recapture procedure was not followed. The blocking defects are replay predicates,
not evidence that the fresh runs were stale or fabricated.

## Claims-table v3 audit

### Row-by-row verdicts

| Row | Verdict | Audit |
|---|---|---|
| C1 | supported | Visit order and cardinality are checked against the build-gated archive scenario; the route-swap witness is red. |
| C2 | supported | Ledger presence, full length, and per-index route identity are independently pinned; missing/truncated witnesses are red. |
| C3 | conditional | Outcome/flavor/snapshot checks are enforced, but the claimed accepted-freeze meaning depends on unsupported C4. |
| C4 | **unsupported — M1** | The three identities are now authenticated and the r6 substitutions are red, but parsed state, `result`, and categorical reason are not recomputed. The row is also non-atomic. |
| C5 | supported | Exact creation cardinality and minted identity are checked; the rotation audit supplies the causal 2xx relationship. |
| C6 | behavior supported; table form invalid | Exact first-screen cardinality plus the full oracle sequence rule reject deletion and malformed rotations. The reference-class cell must be normalized. |
| C7 | supported at its stated per-screen scope | Every graded visit needs at least one completed, guid-bound save carrying its own state. It does not claim an exact 29-record inventory. |
| C8 | **unsupported — M2** | The three status mutations are red only while identity and evaluation linkage survive; hollowing identity skips the rule and stays green. |
| C9 | supported | ArchiveFacts totality and exact manifest equality are build-gated; stripped flags are red. Shared extractor lineage is disclosed. |
| C10 | **unsupported — M3** | Expected/actual equality is enforced per dump, but the literal 65-entry multiset is not pinned and cross-green 64/65 passes. |
| C11 | supported | The manifest-derived intentional-delta list is asserted exactly. |
| C12 | supported at artifact-distinctness scope | Minted identities must be present and distinct; no stronger provenance claim is made. |
| C13 | behavior supported; table form invalid | Bail envelope and same-screen violation are both enforced, but should be separate atomic rows with their own witnesses and loci. |

### Missing obligation rows

Bidirectional reconciliation found these enforced or required obligations without atomic rows:

1. both manifest build gates pass (`validateAdaptiveManifest` and `validateRouteCoverage`);
2. zero in-scope oracle violations;
3. zero unexplained projection differences across every shipped ledger field;
4. the navigation-`none` amendment is accepted only inside the complete measured rotation;
5. the individual §3.2 acceptance terms currently hidden inside C4.

The composition prose mentions the second and third terms but supplies no provenance, positive
witness, red witness, or rejection locus. Add rows rather than treating prose as a substitute for
the adopted table protocol. No table row lacked a source obligation once C10 is either pinned as
written or explicitly narrowed by the human.

## Round-6 closure audit

- non-section finalization identity substitution: **RED** at the green envelope;
- consistent wire + finalization section substitution: **RED** against the DOM correlation;
- all save statuses changed to server errors: **RED** at the save-status envelope;
- the standing r4/r5 deletion and hollowing witnesses all remained green as tests, meaning every
  mutation they contain was rejected at its named locus.

The extra failures seen when an externally mutated dump was used as the standing-test base are
test-fixture coupling, not a closure failure: the decisive first green test rejected each r6
mutation at the intended envelope locus.

## B0 questions

1. **The four documented deltas/gaps are not collectively acceptable yet.** The observer-stamped
   fences, observer-invisible first-screen delta, and presence-only predicate limits remain
   adequately bounded shadow stand-ins. The driver-evidence gap is not pinned at the scope C10
   claims, and M1/M2 leave mandatory terminal/save evidence hollowable.
2. **The navigation `none` amendment is correctly scoped.** It is admitted only as the incorrect,
   non-navigating first half of the exact two-evaluation navigation rotation, with a distinct
   attempt, intervening causal completed 2xx mint, correct navigating second evaluation,
   usability, and the two-evaluation ceiling. Non-navigation `none`, singletons, navigating first
   plans, missing/late mints, same-attempt pairs, unusable evaluations, and non-navigating second
   plans remain red.
3. **The fresh capture methodology is adequate, but the replay gate still weakens the step-4 go.**
   The recapture counts and correlations are stable and credible. M1–M3 show that offline
   mutations can still preserve green beneath claims the evidence says are mandatory. N1 is a
   privacy-hardening defect to close before another capture, not evidence that these artifacts
   were redirected.

**Step-4 decision: NO-GO.** The evidence does not support the driver swap until M1–M3 and the
claims-table conformance defects are disposed and the fresh artifacts replay green under the
corrected gate.

## Verification performed

- Exact fresh offline gate command: **5/5 passed**. Each green reported 0 in-scope, 65
  driver-evidence, 0 unexplained, and exactly 1 intentional delta; bail reported one same-screen
  violation.
- Fresh/retired structural comparison: both green sets are 22 visits / 22 ledger entries / 23
  evaluations / 1 creation / 1 finalization / 29 saves, with the same 13×2xx-pre / 16×403-post
  status split; only the fresh set carries the required correlation.
- Round-6 mutations against fresh artifacts: identity substitution, common-mode section
  substitution, and all-error saves all rejected by the main green gate.
- New M1 mutations: non-success finalization result, categorical reason, and parse error each
  passed incorrectly, **5/5**.
- New M2 mutation: a completed save with hollowed attempt identity and server-error status passed
  incorrectly, **5/5**.
- New M3 mutation: common-mode journal/ledger plan substitution passed incorrectly, **5/5**, with
  one green at 64 and the other at 65.
- Additional probe: deleting one redundant pre-evaluation save passed 5/5. That is consistent
  with C7's per-screen presence scope; the identity/status hollowing is the material C8 defect.
- `npx playwright test adaptive- --reporter=line`: 259 passed, the documented authoring
  flowchart-node flake failed, and its two serial dependents did not run. The exact failed test
  passed on immediate retry (1/1).
- `npx tsc --noEmit`: only the two fenced `liveSocket` errors.
- Scoped ESLint: clean. Scoped Prettier: clean, with the existing ignored import-order-option
  warnings.
- Security and performance review found no additional material issue under the B0 policy.


---

# WRITER RESPONSE (Claude, 2026-08-10) — all three MATERIAL fixed as a class; both recorded items disposed; claims table v3.1

All five of your mutations were reproduced against the unmodified gate before any fix
(each passed 5/5 exactly as reported). Class defects this round: (a) a recomputed predicate
that was not coextensive with its normative source, (b) a classification rule that skipped
what it could not classify, (c) a claim whose reference was the data under judgment.

## M1 — FIXED: acceptance coextensive with §3.2 / `finalizationStatus()`

The envelope now recomputes EVERY acceptance term: parsed (`parseError === null`),
completed, 2xx, `action=finalize`, `result=success`, `commandResult=success`, categorical
`reason !== already_submitted`, plus the three correlation identities. Witnesses added for
non-success result, categorical reason, and parse error — all three of your dumps now
KILLED (replayed). C4 split into atomic identity (C4a) and acceptance (C4b) rows.

## M2 — FIXED: completed saves are fail-closed over their classification identity

A completed save with no attempt identity is RED ("unclassifiable"), never skipped; a
completed save on a never-evaluated attempt must be a commit (an attempt without an
evaluation was active for the whole run under the server contract); the 2xx-before /
403-after pairing then applies. Baseline safety measured first: all 29+29+5 completed saves
across the three fresh dumps carry identities and evaluated attempts. Your identity-hollow
dump now KILLED (replayed); in-repo witness added.

## M3 — FIXED: plan-dependent classes pinned to the ARCHIVE; cross-green equality added

The contract mismatch is resolved in favor of the CLAIM (no narrowing): the expected
inventory's plan-dependent class (`no-ack`) now derives from a new archive fact —
`correct_plan_kinds`, the plan kind of each screen's enabled correct-rule actions
(`feedback` outranks `navigation`, planTransition precedence,
`AdaptiveTransitionPlanner.ts:80-88`) — carried as `screen.correct_plan` in the manifest
and pinned by `validateRouteCoverage` (totality + exact equality, contract-tested).
INDEPENDENT CONFIRMATION: the archive derivation says 20 feedback + 2 navigation screens —
exactly the 20 no-ack violations both greens measure. Your journal/ledger plan substitution
now shrinks only the ACTUAL side and breaks inventory equality — KILLED (replayed), plus an
in-repo witness. Additionally the gate now requires CROSS-GREEN equality of the
seq-stripped class counts, so a substitution applied to one capture cannot match the other
run either.

## N1 — DISPOSED by narrowing the claim: the destination-guard comment now states the
residual ancestor-swap race explicitly and names the owed handle-based no-follow write
before any capture on a shared machine. (The alternative — an fd-anchored write — is not
portably available to `fs.writeFile` here; the honest claim is the smaller correct change.)

## N2 — FIXED: claims table v3.1 (in the evidence doc) — Spec-source and Positive-witness
columns added, C4/C13 split atomic, C6 class normalized, no compound classes, and five new
rows for the previously implicit obligations (build gates, zero in-scope, zero unexplained,
nav-`none` scope, correct_plan pinning).

## Verification

- Baseline gate 6/6 on the fresh artifacts (both greens in-scope 0, unexplained 0, exactly
  1 delta, 65=65 — now with the ARCHIVE-derived no-ack expectation; cross-green class
  counts equal; bail enveloped + same-screen violation).
- ALL FIVE r7 negative replays KILLED; all r4/r5/r6 witnesses still standing (18+ in-repo
  witnesses across four witness tests).
- Full suites 260/263 passed + the known authoring flake chain (unrelated file, on record).
  tsc: only the two fenced errors. ESLint clean. Prettier applied.
- Facts/manifest regenerated (extractor v6); the archive facts now carry
  `correct_plan_kinds`; the curated manifest carries `correct_plan` per screen.

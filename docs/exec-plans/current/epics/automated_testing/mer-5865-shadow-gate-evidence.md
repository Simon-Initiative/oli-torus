# Shadow differential gate — evidence for review gate B0 (MER-5865 step 3)

**Status:** **B0 CLOSED 2026-08-10** (human call; closure consult
`reviews/mer-5865-gate-b0-closure-consult.md` ENDORSE-WITH-AMENDMENTS — all amendments
folded into the STEP-4 CONTRACT OBLIGATIONS below). Gate replays 7/7; awaiting the step-3
commit gate.

## STEP-4 CONTRACT OBLIGATIONS (closure-consult amendments; stable IDs gate B must check)

- **B4-C3** Journal-owned completion state: only the journal state machine's accepted
  freeze enters the green predicate; the driver can neither declare nor deserialize it.
- **B4-C4A** Independently rooted run correlation: section/revision/attempt identity from a
  source that is NOT the finalization record under judgment; exact match before accepted
  freeze; one producer may serialize both, never manufacture both from the same wire record.
- **B4-C5** Journal-observed causal mint: lineage extends only from a parsed successful
  server creation, journal-ordered between the rotation evaluations, identity preceding
  every evaluation that uses it. Driver-declared mints are red.
- **B4-C8** Derived, not declared, lineage: roots bound to journal-stamped visits;
  extensions satisfy §3.3 parsed-success + temporal rules; no driver declaration inserts
  an identity.
- **B4-C12** Run/session identity contract: define the run identity, its trusted source,
  binding to fresh setup + finalization correlation, and the gate-B distinctness witness
  for the canary + acceptance runs.
- **B4-C15** Live acceptance composition: green ⟺ `auditRun` over the immutable live
  journal + complete live runRecord returns zero violations; every non-green driver exit
  maps to sealed/completed-failure evidence with ≥1 positive violation; a driver success
  flag is never a license.
- **B4-C16** Comparison-seam retirement: the switched entry point has NO shipped-ledger or
  shadow-projection acceptance dependency; the differential harness is swap/regression
  evidence only.
- **B4-STAMP** One journal sequence domain (MATERIAL, per the consult): entry fences,
  readback-completed fences, check/ack permits all issued by the journal's monotonic API;
  caller-supplied or driver-local seqs forbidden; gate B exercises both interleavings per
  ordering-sensitive fence.
- **B4-PRED** The step-4/LotE manifest owner either implements the exact predicate
  contract for the divergent-rules screen + regex parts, or explicitly writes the reduced
  matcher scope into the live contract — no longer "deferred to step 5".
- Suite-health: gate B cites the EXACT executed strict subset, not "264 tests"; the
  `adaptive-authoring` serial flake needs a real ticket + owner (human action, open).

## B0 CLOSURE STATEMENT (writer-drafted 2026-08-10; human decision, option C)

**What B0 was for (spec §7):** a narrow gate on the shadow evidence before the step-4
driver swap — does the journal+oracle account agree with the shipped walker's account on
real runs, and does a poisoned run diverge at the same screen?

**Answer, stable across 4 independent green runs and 2 bail runs on two capture sets:**
YES. 0 in-scope violations, 0 unexplained differences, exactly the one classified delta,
identical driver-evidence class counts (65) with the plan-dependent class independently
reproduced from the archive (20 feedback + 2 navigation), the bail differential at the
poisoned screen. The gate replays offline 7/7 with 25+ standing deletion/hollowing/
substitution witnesses accumulated over 8 review rounds.

**Why the loop ends by human call and not by "nothing material":** rounds 5-8 examined the
replay apparatus under an unbounded artifact-corruption threat model. The shadow evidence
is capture-internal BY DESIGN — the run has no driver, so several claims can never be
independent of the capture. Every remaining finding class lives on that boundary, and the
boundary is removed by step 4 itself, not by more shadow hardening.

**Residual capture-internal rows and their step-4 discharge:**

| Residual (claims table v3.2) | Why it cannot close in shadow | Step-4 discharge |
|---|---|---|
| C5 mint corroboration | creation record self-reported | driver mints under a check-click permit; causal license becomes first-party evidence |
| C8 lineage set | built from the capture's own visits/evals/mint | the driver KNOWS its attempts; lineage becomes driver-declared, journal-stamped |
| C10 driver-evidence multiset (conditional) | expected inventory derives from the journal under judgment | the gap CEASES TO EXIST — permits/plans/acks are real, the 65 muted checks become live oracle verdicts |
| C12 run distinctness (artifact-level) | minted guids are capture data | driver-side session identity; runs distinct by construction |
| C13a bail evidence (one serialized dump) | walker error, poison stamp, seal all in one file | the DRIVER is the bailing party; bail evidence is first-party operation-failure records (§3.2 closed union) |
| Observer-stamped fences + observer-invisible first-screen delta | observer stamps at render | driver stamps fences at its identity read; the delta class disappears |
| Permit-stamp API debt (DEBT escalation) | permits carry caller seqs | journal-domain permit stamps land with the driver (step 4 core work) |

**Deferred, NOT discharged by step 4 (named owners):** presence-only predicates for the
divergent-rules screen + regex parts (step-5 regex-operator decision); LLM-capable screens
unsupported until an independent runtime reference exists (build fails closed; future
contract, owner: step-5/registry design); destination-guard ancestor-swap race (harness
owner, before any capture on a shared machine); `adaptive-authoring` flake (suite health,
candidate ticket, unrelated).

**Review regime from here (human-set, 2026-08-10):** gates B/C1/C2 = one
contract-before-build pass + one implementation pass + fixes + human call. No re-review
loops unless the human requests one.

## B0 round-1 disposition (all three MATERIAL findings)

- **M1 (ledger-copied contract):** the oracle's manifest now comes from the ARCHIVE — roles,
  route, resource_ids, combine_feedback from the extractor, grading expectations translated
  from the AUTHORED CORRECT RULES (19/19 graded screens: 22 exact predicates, 2 presence-only
  on one divergent-rules screen, extractor-noted). Receipts assert the manifest's own
  expectations; the wire is the only evidence. Nothing originates in the shipped ledger except
  the comparison TARGETS.
- **M2/M3 (self-asserted permits, replay tautology):** nothing is synthesized anymore. The
  oracle runs without driver evidence, and the violations that requires (causal edges,
  widget-button presence, recorded plans, acks — a CLOSED documented list,
  `isDriverEvidenceViolation`) are classified DRIVER-EVIDENCE: reported and counted (65 per
  green run), expected in shadow, closed by step 4's real stamps. The green claim covers the
  journal-derivable invariants only.
- **N1:** delta renamed `observer-invisible-first-screen-traffic` and classified only when the
  §3.4 sequence rule judged the sequence legal in the same audit. **N3:** the bail dump
  carries a poison-fired stamp and the gate asserts `verdict-not-correct` at that screen.
  **N4:** the recorder detaches in `finish`'s finally. **N5:** formatting applied.

## Round-2 results (same captures, independent judgment; r2 fixes folded)

Roles now ARCHIVE-derived (buttonwidget part → navigation; stage-conditioned correct rule →
graded; else content) — zero mismatches against the v1 classification, consumed from the
archive side only. The gate validates the contract through BOTH build gates
(`validateAdaptiveManifest` + `validateRouteCoverage` over the archive facts). Both green
captures: **in-scope 0, unexplained 0, 1 classified delta, driver-evidence multiset EXACTLY
equal to the independently computed inventory (65)**. Bail (fresh, poison-stamped):
`verdict-not-correct` at that screen.

## Round-3 disposition (M1/M2 material, N1/N2 recorded — all fixed)

- **M1 (empty rule-reference proof):** the extractor now records EVERY stage reference of the
  enabled correct rules — local `stage.*` refs verbatim for the 19 graded screens (24 refs),
  cross-screen `<sid>|stage.*` refs with owner (LotE has none). Local refs are scoped to
  GRADED screens because content/navigation verdicts are unasserted by design (§3.5) — their
  rules are not grading-expectation material. `validateRouteCoverage` now proves local
  expectation completeness non-vacuously; two mutations confirm it fails closed (a fabricated
  uncovered local ref, and a graded screen's expectations dropped — both KILLED).
- **M2 (screen-erasing inventory keys):** both inventories now key
  `stepIndex|screenId|code|detail|requestSeq` (the one keyless class, the missing
  widget-button permit, is identified by its step alone). Mutations confirm: moving one
  violation to another screen, and swapping two same-class violations across screens with
  totals unchanged, both break equality.
- **N1 (zero-count map entries):** gone by construction — the expected inventory bumps once
  per concrete evaluation/step, never materializing empty classes.
- **N2 (extractor exits 0 on problems):** extraction now exits non-zero when the problem list
  is non-empty; the cross-check no longer depends on a human reading stdout.

## Round-4 disposition (M1/M2 material, N1/N2 recorded — all fixed; captures unchanged)

Round 4 endorsed the artifacts and both round-3 closures (independently mutation-verified),
then found the REPLAY not fail-closed over its evidence: a green with no shipped ledger
passed vacuously (M1), and recorder omissions shrank the expected and actual inventories in
lockstep — 65→64 with the mandatory first-screen delta silently gone, or all saves gone
(M2). Class fix: the gate now pins the capture ENVELOPE against capture-independent
references before any comparison.

- **`validateGreenEnvelope`:** outcome/flavor/freeze must be green-accepted-frozen; visits
  and ledger must EXACTLY match the archive scenario route (length + per-index screenId);
  exactly 1 terminal creation and 1 terminal page finalization; first-screen rotation =
  exactly 2 owned evaluations (when the scenario head is navigation); every graded screen
  has ≥1 terminal save bound by `renderedAttemptGuid` (guid, not fence window — 3/19 saves
  precede the observer's next entry stamp on both greens); `compareProjections` compares the
  union length; the intentional-delta set is asserted EXACTLY (manifest-derived).
- **`runIdentity`:** the two greens must be distinct runs (server-minted creation guid).
- **Deletion witnesses (reviewer guardrail, adopted):** a standing gate test replays EIGHT
  in-memory corruptions of the real capture (missing/truncated ledger, wrong flavor, dropped
  rotation eval, dropped saves, dropped creation, dropped finalization, broken route order)
  and requires rejection. All four round-4 negative env replays (ledger-stripped,
  missing-first-eval, saves-removed, duplicate-run) now FAIL.
- **N1:** one failure boundary owns walk + ledger log + completion assertion — any post-arm
  failure seals and dumps the bail capture exactly once. **N2:** `dump()` refuses any
  destination inside a git repository.

## Round-5 disposition (M1/M2/M3 material, N1/N2 recorded — all fixed; captures unchanged)

Round 5 found HOLLOWING: witnesses proved records exist, not that they carry evidence. All
fixed (full detail + CLAIMS TABLE in `reviews/mer-5865-gate-b0-round-5.md` writer response):
§3.2 finalization acceptance RECOMPUTED from the record with a wire-slug cross-source check;
saves must carry the owning screen's own state paths; `combine_feedback` pinned by a TOTAL
ArchiveFacts map with exact equality; fail-closed BAIL envelope (sealed complete snapshot,
on-route graded poison, walker error naming the screen, route-prefix visits); hollowing
witnesses adopted as a second standing gate test (10 witnesses). All 8 negative env replays
(4×r5 + 4×r4) fail. **New measured fact:** the live deck 403s a stable subset of saves —
16 of 29 on BOTH greens, the same 11 graded screens each run — while the walker passes;
the save witness therefore requires completed + own-state payload, not 2xx. Step 4 should
explain the 403 pattern. `dump()` now records the delivery-props correlation as a second
source for step-4 pinning; dumps refuse git-repo destinations via realpath.

## Round-6 disposition (M1/M2 material — fixed; captures RETIRED, recapture pending)

- **M1:** the finalization is now authenticated against the DOM delivery-props correlation
  (`ShadowDump.correlation`, REQUIRED; all three identities exact) — the r5 wire-slug check
  was internal consistency, not independence (Codex's common-mode substitution proved it).
  Pre-r6 dumps lack the field and are rejected; fresh captures required.
- **M2 + the 403 explanation:** `save_active_part` commits only active attempts and 403s
  submitted ones (`attempt_controller.ex:448-469`, `only_active: true`). Measured: every
  2xx save is pre-evaluation (13 = real pre-check commits on 8 screens), every 403 is
  post-evaluation (16 = deck post-check flushes). The witness is renamed SAVE-TRAFFIC (not
  saved-barrier — that stays the oracle's receipt+permit-gated 2xx rule for step 4) and the
  envelope enforces the server contract bidirectionally: pre-eval saves must be 2xx,
  post-eval saves must be 403, anything else is red. Codex's all-error mutation dies.
- Claims table v2 with reference-class column (independent-artifact / independent-source /
  capture-internal) in the r6 writer response.
- Suite-health note (not B0): `adaptive-authoring` flowchart node-count flake, ~50% on
  2026-08-10, hit by both reviewer and writer on untouched files — candidate ticket.

## Runs (all against a live local server, real LotE archive, fresh sections)

Current evidence = the 2026-08-10 recapture set (r6 harness: correlation recorded, single
failure boundary, realpath-validated destination). The 2026-08-09 set is RETIRED (r6 M1)
and kept only for forensics.

| Run | Outcome | Freeze | Result |
|---|---|---|---|
| green 1 (`lote-green-1786378384523`) | shipped walker passed (4.3m) | `accepted` | envelope clean; audit **0 violations**, **0 unexplained diffs**, exactly 1 classified delta; 65=65 pinned |
| green 2 (`lote-green-1786378649848`) | shipped walker passed (4.3m) | `accepted` | identical: 0 / 0 / 1; 65=65 |
| bail (`lote-bail-1786378973158`, first graded screen blanked in flight, 89 values) | shipped walker bailed at that screen | `sealed` | bail envelope clean; audit **1 violation**: `verdict-not-correct` at the SAME screen |

Cross-set stability: the fresh greens reproduce the retired set's counts exactly (65
driver-evidence violations each, same intentional delta, same 13-pre-check-2xx /
16-post-check-403 save pattern) on newly seeded sections.

## Round-8 disposition (M1/M2 material — fixed; both recorded items fixed)

- **M1 (identity laundering):** save classification is LINEAGE-BOUND — identities outside
  {rendered visits, evaluated attempts, server mint} are red, never inferred active. Empty,
  foreign, and 403→2xx-laundered shapes all replayed KILLED.
- **M2 (llmFeedback precedence):** new TOTAL archive fact `llm_feedback_capable` (ALL
  enabled rules scanned for the server's `activationPoint kind=feedback` trigger); the
  coverage gate FAILS CLOSED on any capable screen (its plan kind is not
  archive-determined); the envelope rejects any captured llmFeedback as impossible traffic
  on this archive. LotE: 0 of 22 capable — the classifier is coextensive with the planner
  for every screen this gate judges. Both failure directions closed.
- N1: extractor v7 writes `correct_plan` into the draft — regeneration reproducible.
  N2: "saved-barrier saves" wording retired (own-state save traffic; barrier = step 4).

## Round-7 disposition (M1/M2/M3 material — fixed; captures judged credible)

- **M1:** the green envelope's acceptance predicate is now COEXTENSIVE with §3.2 /
  `finalizationStatus()` — parsed, result AND commandResult success, categorical
  `already_submitted` — with witnesses for each term.
- **M2:** completed saves are fail-closed over classification: no attempt identity = red;
  never-evaluated attempt must be a commit; then the 2xx-before/403-after pairing.
- **M3:** the plan-dependent expected-evidence class derives from the new archive fact
  `correct_plan_kinds` (authored correct-rule actions; feedback outranks navigation —
  planTransition precedence), carried as `screen.correct_plan` and pinned by the coverage
  gate. Archive says 20 feedback + 2 navigation — exactly the 20 no-acks both greens
  measure. Cross-green seq-stripped class-count equality added on top.
- N1 disposed by narrowing the destination-guard claim (residual ancestor-swap race named,
  handle-based write owed before shared-machine captures). N2: table v3.1 below.

## Claims table v3.1 (gate proof protocol; r7 N2 conformance folded)

Composition rule: the gate is green ONLY when every row holds — no capture-internal row can
license green alone; C15/C16 are the final decision terms and C14 guards every other row's
reference. IDs are stable and reused by the standing tests.

| ID | Claim (atomic) | Spec source | Subject | Reference + provenance | Class | Shared domain | Positive witness | Red witnesses (replayed 2026-08-10) | Rejection locus |
|---|---|---|---|---|---|---|---|---|---|
| C1 | visit sequence = selected route | §7 step 3, §3.8 | `dump.visits` | `manifest.scenario` (build-gated) | independent-artifact | archive extractor (disclosed) | both fresh greens | route order swap | envelope `scenario expects` |
| C2 | ledger sequence = selected route, full length | §7 step 3 | `dump.ledger` | `manifest.scenario` | independent-artifact | same | both fresh greens | missing ledger; truncated ledger | `no shipped ledger` / `ledger length` |
| C3 | capture declares a green accepted freeze | §3.2 | outcome/flavor/snapshot state | envelope enumeration | capture-internal (conditional on C4b) | one dump | both fresh greens | bail relabeled green | `outcome must be "green"` |
| C4a | finalization identities = THIS run's | §3.2 | finalization section/revision/attempt (wire) | `dump.correlation` (DOM delivery props) | independent-source (shared recorder/serializer DISCLOSED) | one capture process | fresh greens (correlated=true) | per-identity substitutions; common-mode wire+finalization substitution; correlation stripped | `does not match the delivery correlation` |
| C4b | finalization acceptance recomputed in full | §3.2 = `finalizationStatus()` | parseError/status/action/result/commandResult/reason | the §3.2 predicate (journal impl normative) | independent-artifact (predicate) over capture data | journal | both fresh greens | hollowed fields; non-success result; parse error; categorical reason | `not an accepted finalize` / `result is not success` / `did not parse` / `already_submitted rejection` |
| C5 | exactly one recorded causal mint with server guid | §3.4 | creation record | oracle rotation audit corroborates | capture-internal corroboration | journal | both fresh greens | creation dropped; guid nulled | `exactly 1 terminal creation` / `no server-minted` |
| C6 | first-screen rotation present (exactly 2 owned evals) | §3.4 | journal step-0 window | scenario-head role (manifest) | independent-artifact (trigger; count is journal data) | journal | both fresh greens | first rotation eval removed | `first-screen rotation` |
| C7 | every graded screen produced own-state save traffic | evidence-doc mandatory list | save records, guid-bound | manifest roles | independent-artifact (role set) | journal | 29 saves/green | saves dropped; payloads emptied; foreign payloads | `no completed save carrying` |
| C8 | every completed save is LINEAGE-BOUND and legal under only_active (identity ∈ {visits, evaluated attempts, mint}; 2xx pre-eval / 403 post-eval; unbound = red) | r6/r7/r8 dispositions | save status × identity × eval order | server source `attempt_controller.ex:448-469` + run lineage set | independent-artifact (server code); lineage capture-internal (disclosed) | journal supplies ordering + lineage | 13×2xx-pre + 16×403-post per green, all in lineage | all-500; pre-eval 403; post-eval 2xx; null/empty/foreign identity; laundered 403→2xx under substituted identity | the status/classification messages incl. `not in this run's attempt lineage` |
| C9 | combine_feedback exact per screen | §3.5 | manifest flags | `ArchiveFacts.combine_feedback` (total) | independent-artifact (shared extractor DISCLOSED) | extractor | 4 combining screens | flags stripped | coverage `combine_feedback` errors |
| C10 | driver-evidence gap = expected multiset, keyed step\|screen\|code\|detail\|seq, class counts equal ACROSS greens | §7 step-3 gap | oracle violations | structural inventory (journal counts pinned by C1/C2/C6) + `correct_plan` classes (C18) + cross-green equality | capture-internal, CONDITIONAL on C1–C8/C18 (disclosed) | journal both sides | 65=65 on both greens | r4 omissions; r7 plan substitution; cross-green shrink | inventory equality / `green i vs green 0 class counts` |
| C11 | intentional deltas exactly the required set | §3.4/N1 r1 | projection diffs | manifest-derived list | independent-artifact | — | exactly 1 per green | delta-erasing omission | `toEqual(requiredIntentional)` |
| C12 | the two greens are distinct artifacts | r4 M1 | minted guids | inequality across artifacts | capture-internal (distinctness, not provenance) | — | fresh greens differ | same file twice | `distinct runs` |
| C13a | bail artifact carries the shipped-bail evidence | §3.5 bail differential | outcome/flavor/seal/poison/walkError | bail envelope enumeration + manifest roles/route | capture-internal (three serialized sources DISCLOSED) | one dump | fresh bail | relabel; unfired poison; stripped/nameless error | bail envelope messages |
| C13b | oracle finds the violation AT the poisoned screen | §3.5 | oracle audit of sealed journal | archive receipts (manifest) | independent-artifact (contract side) | journal evidence | fresh bail: `verdict-not-correct` at poison screen | wrong-screen swap (r3 witnesses) | `verdict-not-correct` + screenId equality |
| C14 | both build gates pass before any comparison | §3.8/§3.6b | manifest + facts | `validateAdaptiveManifest` + `validateRouteCoverage` | independent-artifact (validators) | extractor lineage disclosed | every gate test entry | stripped combine/correct_plan/facts keys | validator `fail(...)` messages |
| C15 | zero in-scope oracle violations per green | §3.5 scope table | oracle output | archive receipts + closed driver-evidence list | capture-internal decision term (conditional on all rows) | journal | both fresh greens | poison bail audits red (C13b) | `auditRun: no violations` |
| C16 | zero unexplained projection differences | §7 step 3 | union-length ledger↔shadow compare | shipped ledger vs journal projection | capture-internal decision term | one dump | both fresh greens | truncated ledger `presence` diffs | `unexplained toEqual([])` |
| C17 | nav-`none` admitted ONLY inside the full measured rotation | §3.4 amendment | oracle rotation rule | oracle contract tests (suite) | independent-artifact (test suite) | — | `adaptive-oracle` suite green | rotation-shape negative tests | oracle spec assertions |
| C18 | correct_plan exact per screen | r7 M3 | manifest `correct_plan` | `ArchiveFacts.correct_plan_kinds` (total) | independent-artifact (shared extractor DISCLOSED) | extractor | 20 feedback + 2 navigation = measured no-acks | dropped/drifted plan kind | coverage `correct_plan` errors |
| C19 | no screen is LLM-feedback capable, and no captured evaluation carries llmFeedback | r8 M2 | archive rules + captured evals | `ArchiveFacts.llm_feedback_capable` (total; ALL enabled rules scanned for `activationPoint kind=feedback`, the server trigger `llm_feedback.ex` / `attempt_controller.ex:753-768`) | independent-artifact (archive + server code) | extractor | 0 of 22 capable; 0 llmFeedback on both greens | capable-screen facts fail the build; fabricated llmFeedback fails the envelope | coverage `LLM feedback activation point` / envelope `impossible traffic` |

Raw captures are PRIVATE (answer values) — scratchpad only. The evaluation is replayable
offline via `mer5865-shadow-gate.spec.ts` (env-gated), so re-judging costs zero live runs.

## Mandatory live evidence — all captured

Pre-entry navigation rotation (incorrect check → causal mint → correct navigating check),
the mint chain (exactly 1 creation), 29 own-state save-traffic records (13 pre-check
commits + 16 post-check only_active rejections — saved-BARRIER evidence stays step 4's
receipt+permit rule), the combineFeedback screens'
response derivations, and the ACCEPTED page-lifecycle finalization (correlation read from the
delivery props).

## The divergence the gate caught (the reason it exists)

The live deck's incorrect navigation check returns ONE result with an EMPTY actions array —
plan `none`. Checkpoint A's synthetic rule (round 4) declared `none` illegal on every role and
demanded a `feedback` first plan; reality overrules. Oracle amended (scoped to navigation
screens only; navigating first plans remain illegal), witness flipped citing the capture,
§3.4/§3.5 spec amendments drafted as **writer-proposed pending B0**.

## Current deltas and gaps (post round-2 redesign)

1. **Observer-invisible first-screen traffic** (classified per-diff): the shipped observer
   cannot count the first screen's rotation; classification requires the §3.4 sequence rule to
   have judged the sequence legal in the same audit. Observer fences stamp at render, so this
   is not proven pre-entry relative to a future driver fence.
2. **Driver-evidence gap, PINNED per step/screen/evaluation-seq:** no permits or recorded
   plans exist in shadow, so the oracle's causal-edge / widget-button / recorded-plan /
   feedback-ack violations are expected — and the gate asserts their exact multiset (keyed
   `stepIndex|screenId|code|detail|requestSeq`) equals an inventory computed independently
   from journal + manifest (`expectedDriverEvidence`). `receipt-missing` is IN-SCOPE
   (receipts are projector-built from the archive contract). Closed by step 4's real stamps.
3. **Predicate-strength limits, recorded:** one divergent-correct-rules screen and regex
   receipt parts project to presence-only; the v2 regex-operator question is a step-5 decision.
4. Observer-stamped entry fences stand in for driver-stamped fences (step 4).

## B0 questions

1. Are the four deltas acceptable stand-ins for this gate's purpose (equivalence of the
   JOURNAL+ORACLE against the shipped account), given each is replaced by driver-real evidence
   in step 4?
2. Is the navigation `none`-plan amendment (§3.4/§3.5) correctly scoped?
3. Anything in the capture methodology that weakens the step-4 go decision?

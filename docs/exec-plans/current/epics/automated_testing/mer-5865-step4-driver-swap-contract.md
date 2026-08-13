# Step-4 driver swap — contract-before-build (gate B proof design) — v6

**Status:** v6 DRAFT after five Codex reads (fold history: Appendix A). Awaiting the
reopened Codex pass. A verdict means "reviewable design", never pre-approval; material
predicate/reference/class/composition changes reopen it — implementation detail does not.
All witnesses are `PENDING-BUILD`: this page fixes each witness's identity, mutation, and
expected rejection locus; replay statuses are recorded in the gate-B submission.

## 1. Decision and scope

Gate B licenses exactly: the LotE spec switched to the new strict entry point (family
registry + new driver consuming the committed journal/attribution/planner/permits/oracle
core, LotE manifest v2), then — second stage — deletion of the old strict
walker (`AdaptiveHappyPathTask.ts`, `AdaptiveEvaluationObserver.ts`,
`AdaptiveStrictContract.ts`). NOT licensed: C1/C2 scope, registry entries beyond LotE's
six families, compat deletion, changes to `AutomationSetupTask.ts`/`AdaptiveLessonTask.ts`.

> **AMENDMENT A1 — the two stages become two GATES (2026-08-13).** Human scope decision:
> MER-5865 ships the strict verification FOUNDATION, proven live on LotE; migrating the two
> Real Chem lessons and deleting the old walker move to a follow-up ticket. Stage 2 (`DEL`)
> therefore defers WITH them.
>
> **This is a rename, not a weakening.** Reviewer ruling (round-9 consult, 2026-08-13):
> *"The cut is sound only as a renamed foundation gate. SWAP-GREEN certifies that the strict
> stack is wired, fail-closed, and proven live on LotE; it does not certify replacement
> completeness. Amend the contract explicitly — calling original GATE-B-CLOSE green without
> DEL would contradict its fail-closed composition rule."* Same ruling, same consult:
> **no `SWAP-GREEN` conjunct may be cut** — the four §7 derivations, SUITE, DIFF and ACCEPT
> all stand. `DEL` defers because it proves EXCLUSIVITY (nothing else consumes the old
> walker), which is a property of replacement, not of foundation correctness.
>
> Consequences, all normative:
> - `GATE-B-FOUNDATION` is what this ticket closes. It licenses the switched spec ONLY.
>   It does NOT license any claim that the old walker is unused, unreachable, or retired.
> - `GATE-B-CLOSE` keeps its original meaning and its `∧ DEL` conjunct, and is UNCLOSED
>   until the follow-up ticket. Two walkers coexisting is the accepted residue.
> - The compat-walk extraction and its §1/§6 delta-list amendment defer with `DEL`; the two
>   Real Chem specs keep importing `completeAdaptiveHappyPath` untouched.
> - §6.1 and §6.2 expiries ("Expiry: gate B") attach to `GATE-B-FOUNDATION`.
> - W-DEL1/2/3 are PENDING-FOLLOW-UP, not waived: an unexecuted conjunct is red for
>   `GATE-B-CLOSE`, which simply is not the gate being claimed here.

**Final predicate — any missing, unknown, malformed, or unexecuted conjunct = RED:**

```
SWAP-GREEN         ⟺ WIRE ∧ SUITE ∧ DIFF ∧ ACCEPT ∧ EXIT-TOTAL
GATE-B-FOUNDATION  ⟺ SWAP-GREEN                      (A1: what MER-5865 closes)
GATE-B-CLOSE       ⟺ SWAP-GREEN ∧ DEL                (A1: deferred to the follow-up)

WIRE       = ENTRY ∧ CORE ∧ VERDICT-S ∧ VERDICT-L ∧ REG ∧ MAN ∧ BIJ (rows §3; W-W*)
SUITE      = executed set == EXPECTED-INV ∧ all pass ∧ CONFORMANCE-MAP total (W-U*)
             EXPECTED-INV = pre-step-4 canonical Playwright discovery of the `adaptive-`
             scope at f9f9982874, committed as an artifact BEFORE build, ∪ the additive
             step-4 test manifest; unexplained removal/rename/case-count change = RED
             CONFORMANCE-MAP (r4-B3, hardened r5-B3) = a bidirectional gate-evidence
             table over SUBCASE IDs: every §3 row ID and every §4 witness SUBCASE (each
             mandatory variant of a compound witness carries its own ID — W-J4a/b/c,
             W-W3a/b, W-W7 per enumerated signal, and every W-ST/W-D/W-X case) ↦ a
             discovered test id or a reported case id. Each entry records test/case id,
             EXACT MUTATION PARAMETERS, expected locus, OBSERVED locus, and replay
             result; the gate-B reviewer verifies SEMANTIC conformance of the mapped
             assertions against this contract's mutation and locus — ID presence alone
             never satisfies an entry. An unmapped subcase, or a mapped test whose
             assertion is weaker than its subcase, = RED. Cardinality-bearing inner loops
             (e.g. the disqualify-target cases inside adaptive-oracle.spec.ts:1799)
             either become named tests or emit a runtime case inventory compared to an
             EXPECTED SET FIXED PRE-BUILD as a gate artifact derived from this contract
             or the pre-step-4 source — sharing NO constant, array, or helper with the
             runtime emitter (r5-B3); discovery identity alone is NOT accepted for them
DIFF       = step-3 harness agreement over the step-3 projection on swapped live runs;
             deltas only on §6's closed list — corroborating, never a license alone
ACCEPT     = canary + 3 consecutive fresh-seed live runs; per run green ⟺ auditRun(map,
             scenario, live runRecord, frozen live journal) = 0 violations under
             accepted-freeze; runs pairwise distinct
EXIT-TOTAL = EXIT-SCOPE ∧ EXIT-INV ∧ EXIT-EM ∧ EXIT-MAP per the §3 rows and the CLOSED
             TWO-STEP PROCEDURE:
             (0) EXIT-SCOPE (r5-B1) — the source UNIVERSE is closed INDEPENDENTLY FIRST:
             at the gate revision the gate-B reviewer derives it from the real switched
             entry point + spec fixture dependency/call graph, including EVERY reachable
             file whose failure can cross the outer boundary (helpers, registry entries,
             core wrappers), and compares it BIDIRECTIONALLY with the submission's
             declared scope; each exclusion is individually justified in gate evidence;
             any file in the derived universe absent from the declared scope = RED. The
             writer never fixes the universe alone.
             (1) EXIT-INV — within that independently closed universe: site identity =
             file:line + exit kind from the closed kind list {throw, rejecting await
             without local handler, failure-path early return, catch branch,
             finally/cleanup failure, outer error/finally boundary}; the artifact must
             equal, as a SET, the reviewer-derived site list; each site pins exactly ONE
             typed producer.
             (2) EXIT-EM / EXIT-MAP — per-site injection must activate THAT site and
             assert its pinned producer — and NO other — emitted before any
             boundary/seal; mapping per the EXIT-MAP row
DEL        = files absent ∧ closed sweep (§6.5) clean ∧ sweep self-test passed
```

**Self-red-team — green-while-false input → killing witness:** WIRE: lookalike planner,
imports/seqs/MAN green → W-W2. VERDICT: `auditZero || override` shape → W-W7a static
closure; a build-introduced captured/env signal → W-W7's derived dependency inventory
(bidirectional, not the anticipated four); a verdict that FILTERS one violation class
before testing zero → W-W7c per-class discrimination. SUITE: required new witness omitted
from the additive manifest → W-U6 unmapped-subcase red; mapped test weaker than its
subcase → W-U8 semantic-conformance red; inner-loop case deleted → W-U7 (expected set
shares no helper with the emitter). ACCEPT: driver flag green over violated journal →
W-W6. EXIT: a helper file with exit sites omitted from the declared scope → W-E0
scope-closure inequality; uninventoried catch branch → W-E1; injection reaching a
different producer → W-E2. LINEAGE: failed/unparsed creation with an apparent GUID
extending lineage → W-J11/12/13. DEL: hollow sweep → W-DEL2.

## 2. Material false-green threats

1. Driver self-license — completion/mint/lineage declared, not journal-observed (C3/C5/C8).
2. Common-mode correlation — identity manufactured from or consistently replaced with the
   finalization under judgment; late or mutated snapshot (C4A).
3. Sequence-domain fragmentation — non-journal seqs reorder fences/permits (STAMP).
4. Run-identity confusion — runs not provably distinct (C12b).
5. Hybrid/lookalike wiring — new path present but not load-bearing; alternate,
   build-introduced, or selectively filtered verdict input (CORE-L, VERDICT-S/L, REG-L).
6. Residual comparison seam (C16).
7. Predicate hollowing / helper common-mode (PRED, MAN, BIJ).
8. Suite self-selection, self-shrinkage, or unmapped coverage (SUITE).
9. Silent or falsely pinned exit; self-selected exit-file universe (EXIT-SCOPE/INV/EM).
11. Lineage extended by a failed, unparsed, or GUID-less creation (C5, r5-B4).
10. Retirement laundering (§6.1).

## 3. Atomic proof table

One class per row: `IA` independent-artifact, `IS` independent-source, `CI`
capture-internal — independence FROM THE ROW'S SUBJECT; mandatory force comes from §5
composition. Role: `M` mandatory, `C` corroborating.

| ID | Claim | Reference + provenance | Class | Shared domain (disclosed) | Role |
|---|---|---|---|---|---|
| B4-ENTRY-S | Switched spec statically binds the new entry point | import witness | IA | — | M |
| B4-ENTRY-L | Bound path exercised live: canary runRecord carries journal-issued fence seqs | canary journal + runRecord | CI | journal recorder | M |
| B4-CORE-S | Driver statically consumes the committed core (§3.1/§3.10: one planner, both callers) | import graph | IA | — | M |
| B4-CORE-L | Each core consumer LOAD-BEARING: per consumer, bypass AND discriminating substitution each red at a named downstream locus, with imports/seqs/MAN held green | W-W1..W-W5 through the real entry point | CI | harness shares entry point under test | M |
| B4-VERDICT-S | Static closure of the assertion boundary's input domain (r5-SF1): an INDEPENDENTLY DERIVED, bidirectional data-flow inventory at the gate revision — parameters, free/captured variables, imports/helpers, exception/fallback paths, environment/config, mutable outer state — shows the boundary consumes the UNMODIFIED auditRun result with exact `violations.length === 0` semantics; any transformation or per-class filter must itself carry a discriminating subcase (r5-B2) | W-W7a/b (static inventory + shape) | IA | — | M |
| B4-VERDICT-L | Live exclusivity: every dependency in that derived inventory — not only the four anticipated ({driver flag, ledger, projection, swallowed exception}) — placed in its licensing state while auditRun returns a violation → spec red; plus per-violation-class discrimination (r5-B2) | W-W6, W-W7c/d | CI | — | M |
| B4-REG-S | Registry resolution fail-closed by family+version(+mode); unknown/ambiguous → throw by name (§3.6) | accept/reject contract matrix | IA | — | M |
| B4-REG-L | Live resolver load-bearing: post-validation wrong-but-valid resolution → red at family answer/readback locus, MAN held green | W-W9 | CI | harness | M |
| B4-MAN | Manifest v2 registry metadata validated against the RAW archive via the independent reader | raw archive, independent reader | IS | extractor produces facts + manifest input; reader is the breaking leg | M |
| B4-BIJ | Archive↔map↔scenario completeness (§3.8 gates: bijection, one step per on-route screen, classified exclusions, operation-ref resolution) against the raw archive | raw archive via §3.8 gates | IS | as MAN | M |
| B4-C3 | Only the journal's accepted freeze enters the green predicate; driver can neither declare nor deserialize it (§3.2) | journal recorder + acceptance contract, live wire | CI (independent of the DRIVER) | journal single producer; shares Playwright process with driver | M |
| B4-C4A | Correlation triple from server-rendered Delivery DOM props (`AdaptiveShadowCapture.ts:190-207` mechanism), FROZEN BY THE FIXTURE immediately after opening the intended Delivery page, before the driver acts (normative); exact match vs runRecord AND finalization before accepted freeze; section field cross-anchored to the setup response | fixture-frozen snapshot; producer = server render | IS | same page/process as driver; separate reader, no shared helper/alias with runRecord serialization | M |
| B4-C5 | Lineage extends only from PARSED SUCCESSFUL server creations — a failed, unparsed, or absent/empty-GUID creation confers NOTHING (§3.3:463-466) — journal-ordered between the rotation evaluations, identity preceding every use | journal creation records + seq order | CI | journal recorder | M |
| B4-C8 | Lineage derived, not declared: roots = journal-stamped visits; §3.3 parsed-success + temporal rules | journal + journal-issued entry fences | CI | journal; fences driver-requested, journal-valued | M |
| B4-C12a | Run identity binding: frozen triple ↔ setup section ↔ finalization correlation | as C4A | IS | as C4A | M |
| B4-C12b | Canary + 3 runs pairwise distinct on every identity component | the four frozen triples, pairwise compared | CI | one setup task requests all; server issues each | M |
| B4-STAMP | ONE journal sequence domain: entry fences, readback-completed fences, check/ack permits from the journal's monotonic API; caller-supplied seqs forbidden — no API shape accepts one (§3.3) | journal API surface, type-level | IA | driver controls timing only | M (MATERIAL) |
| B4-EXIT-SCOPE | The source UNIVERSE is closed independently FIRST (§1 step 0): reviewer-derived from the real entry-point + fixture dependency/call graph at the gate revision, compared bidirectionally with the declared scope, every exclusion individually justified (r5-B1) | reviewer-derived dependency/call graph vs declared scope | IA | — | M |
| B4-EXIT-INV | Control-flow exit-site inventory closed per §1 step 1 WITHIN the EXIT-SCOPE universe: set equality with the reviewer-derived site list; each site file:line + kind, pinned to exactly one producer | inventory artifact vs reviewer-derived list | IA | — | M |
| B4-EXIT-EM | Each inventoried site, injected AT THAT SITE, emits its pinned producer's record — and no other — before any boundary/seal | W-E2/W-E3 fault-injection matrix | CI | harness | M |
| B4-EXIT-MAP | Every record class + every non-green journal path (completed-failure × reason, freeze_timeout, seal_incomplete, open/closed pre-completion seals) → ≥1 positive violation through auditRun; open-window zero-positive boundary closed | §3.2 record union + seal matrix through auditRun | CI | harness | M |
| B4-C15 | Per-run green ⟺ auditRun = 0 violations under accepted-freeze over immutable journal + complete runRecord; driver flag never an input | auditRun output | CI (license only via §5) | inherits inputs | M |
| B4-C16 | Switched path has NO shipped-ledger or shadow-projection acceptance dependency; differential = swap evidence only | static reference witness | IA | — | M |
| B4-PRED | Grading predicates exact per the closed v2 operator set except §6.3's enumerated scope; extractor/helper common-mode broken by an implementation-independent raw-condition reader (separate parser, no shared helper) | raw archive rule conditions via the independent reader | IS | extractor + helpers produce facts AND manifest input; reader shares none | M |
| B4-SUITE | §1 SUITE: pre-step-4 artifact ∪ additive manifest, bidirectional equality, CONFORMANCE-MAP total AT SUBCASE GRANULARITY with reviewer-verified semantic conformance, inner-loop expected sets fixed pre-build with no shared helper, enumerator validated on generated identities | pre-change discovery artifact + pre-build case sets + conformance map vs executed list | IA | — | M |
| B4-DIFF | Swapped driver's live account agrees with the step-3 projection; deltas only on §6's closed list | step-3 harness over swapped live runs | CI (shares journal/projector code with system under test) | disclosed | C |
| B4-DEL | Stage 2: files absent ∧ §6.5 sweep clean ∧ self-test passed | post-deletion sweep + self-test | IA | — | M |
| B4-FIN1 | `already_submitted` = violation (§3.2, sourced); the at-most-one-ACCEPTED invariant stays a PROPOSED amendment (§6.6) until adopted | journal finalization records | CI | journal recorder | M (narrowed) |

Bidirectional coverage: §7-step-4 obligations ↦ rows (registry→REG-S/L; driver→CORE-S/L,
ENTRY-S/L, VERDICT-S/L; manifest v2→MAN/BIJ/PRED; spec switch→ENTRY-S/L; canary+3×→
ACCEPT, C12b; deletion→DEL); all closure-consult B4-* obligations carried; C5/C8 use the
consult's journal-observed wording as normative.

## 4. Witness matrix

All statuses `PENDING-BUILD`; the gate-B submission records each witness's replay. Every
witness SUBCASE ID appears in the CONFORMANCE-MAP (§1 SUITE) with its mutation
parameters, expected locus, observed locus, and replay result, or the gate is red. A row
listing lettered subcases (a/b/c…) maps EACH letter separately; a mapped test whose
assertion is weaker than the subcase it claims = RED (r5-B3).

| W-ID | Row | Mutation / case | Expected rejection locus |
|---|---|---|---|
| W-J1 | C3/C15 | positive: accepted-freeze green run | — (accept) |
| W-J2 | C3 | deletion: audit on unfrozen journal | auditRun input contract |
| W-J3 | C3 | hollowing: records, no accepted finalization | completed-failure freeze + finalization-failure violation |
| W-J4a/b/c | C4A | correlation field wrong: section / revision / attempt (one subcase each) | §3.2 acceptance contract |
| W-J5 | C4A | both-sides SECTION swap (runRecord + finalization consistent) | setup-response section anchor |
| W-J6 | C4A | revision/attempt substitution; triple derived from finalization | fixture-frozen snapshot mismatch |
| W-J7 | C3 | status corruption (`result: success` flipped) | acceptance contract |
| W-J8 | FIN1 | `already_submitted` finalization | §3.2 violation |
| W-J9 | C5 | mint reordered after its consuming evaluation | §3.3 lineage |
| W-J10 | C5 | mint before the first rotation evaluation | §3.4 rotation order |
| W-J11 | C5 | NON-2xx creation carrying an apparent GUID, consuming evaluation present (r5-B4) | lineage/rotation locus — confers nothing |
| W-J12 | C5 | creation with PARSE ERROR, apparent GUID, consuming evaluation present | lineage/rotation locus |
| W-J13 | C5 | 2xx creation with ABSENT or EMPTY response GUID, consuming evaluation present | lineage/rotation locus |
| W-J14 | C5 | deletion: no creation record at all, second evaluation present | edge-less/rotation violation |
| W-J15 | C5 | hollowing: creation record present, response body empty | lineage locus |
| W-S1 | C4A | positive: frozen triple matches runRecord + finalization | — |
| W-S2 | C4A | deletion: snapshot absent | gate red (mandatory evidence) |
| W-S3 | C4A | hollowing: props element present, fields empty | correlate-equivalent false → red |
| W-S4 | C4A | post-snapshot navigation/DOM replacement; finalization matches later render | retained triple unchanged; later finalization rejected |
| W-S5 | C4A | same-node `data-react-props` attribute mutation after capture (r4-SF1) | retained VALUE triple unchanged; mutated-props finalization rejected |
| W-S6 | C4A | reader aliased to driver's serializer | static no-shared-helper check |
| W-R1 | C8 | visit deletion | coverage violation |
| W-R2 | C8 | cardinality-preserving root/visit ownership swap | §3.3 window/lineage |
| W-R3 | §3.4 | permit deletion | edge-less evaluation violation |
| W-R4 | STAMP | permit with non-journal seq | API shape rejection |
| W-R5 | §3.5 | receipt deletion on graded step | receipt-present invariant |
| W-ST1..4 | STAMP | both orders at EACH fence: request×entry, save×readback, evaluation×check permit, second-evaluation×ack permit | attribution / causal-edge loci |
| W-ST5 | §3.5 | save racing the readback-completed seq | savedBarrier temporal audit |
| W-ST6 | §3.5 | save racing the check-permit seq | savedBarrier temporal audit |
| W-E0a | EXIT-SCOPE | a reachable helper/registry/core-wrapper file whose failure crosses the boundary omitted from the declared scope (r5-B1) | reviewer-derived universe inequality |
| W-E0b | EXIT-SCOPE | declared scope names a file absent from the derived universe (reverse direction) | bidirectional inequality |
| W-E1 | EXIT-INV | set inequality: reviewer-derived site list vs artifact (either direction) | inventory completeness check |
| W-E2 | EXIT-EM | per-site injection: pinned producer AND NO OTHER emitted before boundary/seal | per-site emission assertion |
| W-E3 | EXIT-EM | site mutated to exit before its producer | emission red |
| W-E4 | EXIT-MAP | every record class + every non-green journal path through auditRun | ≥1 positive violation each |
| W-E5 | EXIT-MAP | open-window pre-completion seal with record suppressed | zero-positive boundary clause |
| W-E6 | EXIT-EM | hand-built-records-only evidence offered | rejected: emission provenance required |
| W-M1 | MAN/BIJ/PRED | positive: build passes; independent reader agrees | — |
| W-M2 | MAN/BIJ | raw archive absent | build red (never vacuous) |
| W-M3 | MAN/BIJ | archive without rule conditions | independent reader red |
| W-M4 | BIJ | graded screen's expectation dropped | validateRouteCoverage |
| W-M5 | PRED | presence-only outside §6.3 | manifest validation by name |
| W-M6 | PRED | unknown operator / type-mismatched argument | schema rejection |
| W-M7 | PRED | shared extractor/normalization HELPER mutated | independent raw reader disagreement |
| W-M8 | MAN | family/version metadata transform | raw-archive comparison red |
| W-W1 | CORE-L | planner bypass (transition without planner) | plan-replay mismatch (§3.5) |
| W-W2 | CORE-L | planner SUBSTITUTION: altered plan on an exercised live branch | plan-replay mismatch |
| W-W3a/b | CORE-L | attribution: (a) bypass, (b) ownership-altering substitution | §3.3 window/ownership violations |
| W-W4 | CORE-L | permit bypass (no permit) | edge-less violation (§3.4) |
| W-W5 | CORE-L | permit substitution (wrong screen/step) | causal-edge rule |
| W-W6 | VERDICT-L | auditRun returns ≥1 violation, driver flag green | spec red |
| W-W7a | VERDICT-S | independently derived, bidirectional data-flow inventory of the assertion boundary at the gate revision (parameters, captured vars, imports/helpers, exception/fallback paths, env/config, mutable outer state) vs the declared input set (r5-B2) | inventory inequality → red |
| W-W7b | VERDICT-S | boundary consumes the UNMODIFIED auditRun result with exact `violations.length === 0`; any transformation/filter present | static shape witness → red unless each transformation carries its own discriminating subcase |
| W-W7c | VERDICT-L | PER VIOLATION CLASS: auditRun returns a violation of that class alone; a class filtered before the zero test (r5-B2) | spec red per class |
| W-W7d/… | VERDICT-L | EACH dependency in the W-W7a inventory — not only {driver flag, ledger, projection, swallowed exception} — set to its licensing state under a returned violation; one subcase per discovered dependency | spec red per dependency |
| W-W8 | REG-S | unknown/ambiguous family+version(+mode) | throw by name |
| W-W9 | REG-L | post-validation wrong-but-valid resolution (MAN green) | family answer/readback mismatch |
| W-W10 | ENTRY-S | import witness | — (positive) / static red |
| W-W11 | ENTRY-L | canary runRecord lacks journal-issued seqs | red |
| W-W12 | C16 | reintroduced shipped-ledger/projection reference | static red |
| W-U1 | SUITE | positive: EXPECTED-INV == executed, all pass | — |
| W-U2 | SUITE | pre-step-4 test missing at gate revision | pre-change artifact inequality |
| W-U3 | SUITE | empty executed set | red |
| W-U4 | SUITE | required test swapped for unrelated passing test, count preserved | file:test identity inequality |
| W-U5 | SUITE | enumerator omits loop-generated identities (adaptive-oracle.spec.ts:624) | enumerator itself red |
| W-U6 | SUITE | any §3 row ID or §4 witness SUBCASE unmapped in CONFORMANCE-MAP | red (r4-B3) |
| W-U7 | SUITE | cardinality-bearing inner-loop case removed (e.g. a :1799 disqualifying target) | inequality vs the PRE-BUILD expected set (shares no constant/array/helper with the emitter, r5-B3) |
| W-U8 | SUITE | a mapped test exercises a WEAKER variant than its claimed subcase (reviewer semantic-conformance check) | red (r5-B3) |
| W-U9 | SUITE | expected case set and runtime emitter share a constant/array/helper | provenance check → red |
| W-D1..4 | DIFF | positive; screen missing; empty account; single tuple-field swap | comparison red (2–4) |
| W-X1..3 | C12b | positive; witness absent; shared identity component | red (2–3) |
| W-DEL1 | DEL | files absent + sweep clean | — |
| W-DEL2 | DEL | self-test: planted reference of EACH §6.5 form | sweep must find all, else sweep red |
| W-DEL3 | DEL | residual reference in any included path | sweep red |

## 5. Composition and fail-closed rules

**A1 (2026-08-13):** the composition rules below govern `SWAP-GREEN`, and therefore govern
`GATE-B-FOUNDATION` unchanged — deferring `DEL` removes a conjunct from a DIFFERENT gate, it
does not relax any rule stated here. A claim of `GATE-B-CLOSE` still requires `∧ DEL` and is
not made by this ticket.

GATE-B-CLOSE is the §1 two-stage conjunction, stated once, mutated ACROSS row boundaries
(SUITE ∧ DIFF green + C12b failed → RED; ACCEPT green + any EXIT row absent → RED; WIRE
statics green + W-W11 failing → RED; EXIT-INV green under a scope that failed EXIT-SCOPE
→ RED; any W-W* witness green → RED). CI rows persist post-swap (C3, C5, C8, C12b, C15,
FIN1, ENTRY-L, CORE-L, VERDICT-L, REG-L, EXIT-EM, EXIT-MAP, DIFF): **no CI row, alone or
in CI-only combination, licenses a green** — every green additionally requires the IS
anchors (fixture-frozen identity, raw archive via independent readers) and IA anchors
(STAMP API shape, static wiring, VERDICT-S, pre-step-4 suite artifact + CONFORMANCE-MAP,
EXIT-SCOPE, EXIT-INV, DEL sweep) on which the CI rows' meaning depends.
Missing/unknown/malformed input anywhere = red; unresolved evaluation candidates are
violations (§3.5); unfrozen journals rejected; absent witnesses fail the submission; an
unexecuted conjunct is a red gate, never skipped.

## 6. Allowlist / delta discipline (closed; no open-ended class)

1. **Driver-evidence retirement:** closed element-level mapping table in gate evidence:
   each member of the closed `isDriverEvidenceViolation` class list (causal edges,
   widget-button presence, recorded plans, acks — 65 occurrences per green run;
   plan-dependent classes 20 feedback + 2 navigation, archive-reproduced) ↦ the live
   oracle predicate now auditing it. Unmapped DIFF difference = RED. Expiry: gate B.
2. **Observer-invisible first-screen delta retires;** reappearance in DIFF = failure.
   Expiry: gate B.
3. **B4-PRED reduced scope — exactly ONE screen:** `q:1516197466626:752` ("Reflect",
   divergent correct rules; parts `stage.Metacognition.numberOfSelectedChoices`,
   `stage.Metacognition.selectedChoices`). `q:1516189150386:363` RESOLVED arm (a): exact
   predicate `stage.IronDensity.selectedChoice equal 3` (verified 2026-08-10). Arms for
   Reflect: (a) exact predicates within the closed operator set, or (b) reduced matcher
   scope for exactly these two parts, written into the live contract. Choice lands in the
   step-4 manifest; step-5 may LIFT a reduction, never widen. Expiry: final at gate B.
4. **`adaptive-authoring.spec.ts:133` flake:** one recorded retry in SUITE evidence; not
   a membership exemption. Owner: human ticket (open).
5. **DEL sweep:** scope = ENTIRE repository; reference forms = static `import`/`export …
   from`/`require`, dynamic `import(…)` string, bare string module-path references to any
   of the three filenames; exclusions = EXACTLY `docs/exec-plans/**` and `reviews/**`.
   Self-test per W-DEL2.
6. **B4-FIN1 pending arm — the one open human decision:** PROPOSED §3.2 amendment "at
   most one ACCEPTED finalization per run". Until adopted, FIN1 audits only
   `already_submitted`. Owner: human, before build.
7. **Suite inventory deltas:** ONLY the additive step-4 test manifest and individually
   justified removals/renames recorded in gate evidence; unexplained removal, rename, or
   case-count change = RED.

## 7. Conformance IDs

Row IDs (§3) and witness SUBCASE IDs (§4) are stable; implementation tests, the
CONFORMANCE-MAP, and the gate-B claims table reuse them verbatim. The CONFORMANCE-MAP
obligation (§1 SUITE) makes the mapping bidirectional AT SUBCASE GRANULARITY: every
subcase ID ↦ a discovered test or reported case with its mutation parameters and observed
locus, verified for semantic conformance by the gate-B reviewer; every strict-suite test
traces back to at least one ID or is marked pre-existing.

**Gate-B reviewer obligations (derivations this contract cannot perform pre-build; each
has a RED condition above):** (1) EXIT-SCOPE — derive the source universe from the real
dependency/call graph and compare bidirectionally (W-E0a/b); (2) EXIT-INV — derive the
exit-site list within it (W-E1); (3) VERDICT-S — derive the assertion boundary's
data-flow inventory (W-W7a) and instantiate one W-W7d subcase per discovered dependency;
(4) CONFORMANCE-MAP — verify semantic conformance of every mapped subcase (W-U8). A
reviewer derivation that is not performed leaves its conjunct UNEXECUTED = RED (§5).

8. **Registry version precision is MAJOR-only (build finding, 2026-08-11, unit 4a).** The
   authored archive pins CAPI widget srcs at a major wildcard
   (`/spr-widget-matching/prod/2.*`, `/spr-widget-general-drag-drop/6.*`), so
   family+version resolution and the live `detect` check can only compare MAJOR. A minor or
   patch change published upstream by the widget host is invisible to B4-REG-S/B4-MAN.
   Independent bound: the archive is the reference for what is DECLARABLE, and manifest
   major must equal archive major exactly (B4-MAN unchanged); the residue is upstream
   mutation within one major, which no repo-side artifact can observe. Owner: this gate —
   named here, cited in gate evidence. Expiry: none (a product-side property, not a
   deferral); revisit only if widget srcs gain exact versions.

## Appendix A — fold history

- **A1 (2026-08-13, scope amendment — human decision + reviewer ruling):** the two stages split
  into two gates. `GATE-B-FOUNDATION ⟺ SWAP-GREEN` is what MER-5865 closes; `GATE-B-CLOSE`
  keeps `∧ DEL` and defers to the follow-up ticket with steps 5–10. No `SWAP-GREEN` conjunct
  was cut. Reviewer also ruled: merge the piece-4 round-10 pass INTO the single gate pass
  (EXIT-SCOPE/INV and CONFORMANCE-MAP subsume the round-9 recheck), and §1 SUITE's
  "either become named tests" arm is accepted for the cardinality-bearing inner loops
  provided each case carries a unique stable discovered identity and an explicit subcase
  mapping.

- r1 (8B/2SF): two-stage predicate + sweep; EXIT concept; WIRE rows; SUITE pinning; C4A
  independent leg; PRED enumeration + raw comparison; §6.1 closed retirement mapping; §4
  completion; class relabels; FIN1.
- r2 (7B/3SF): C4A/C12a rebuilt on the verified DOM-prop mechanism (setup response
  carries section.slug only — `AutomationSetupTask.ts:19-20`); CORE-L + REG live
  witnesses; EXIT emission/mapping split; SUITE discovery derivation; BIJ row; the
  implementation-independent raw reader; §4 source rows; §6.5; ENTRY/CORE splits +
  C12b→CI; FIN1 narrowed + §6.6.
- r3 (3B/2SF): EXIT-INV control-flow site inventory (record union = mapping reference
  only); CORE-L substitution matrix + B4-VERDICT + REG-L post-validation; pre-step-4
  discovery artifact + additive manifest + enumerator validation; REG/EXIT single-class
  rows; normative snapshot timing + section-narrowed anchor + W-S4.
- r4 (3B/2SF): EXIT-INV closed procedure (scope, site identity, kind list, reviewer-derived
  set equality, pinned-producer-and-no-other injection); VERDICT input-domain closure
  (W-W7); CONFORMANCE-MAP + case inventories for inner loops (discovery verified 123
  tests; :1799 is one identity); W-S5 same-node mutation; compact-matrix restructure.
- r5 (4B/1SF): EXIT-SCOPE as an independent step-0 row (reviewer closes the source
  universe from the real dependency/call graph BEFORE the site set — W-E0a/b);
  VERDICT-S/VERDICT-L split with a derived bidirectional data-flow inventory, exact
  `violations.length === 0` shape, and per-violation-class discrimination (W-W7a–d);
  CONFORMANCE-MAP hardened to SUBCASE granularity with mutation parameters, observed
  loci, reviewer semantic-conformance verification, and pre-build expected case sets
  sharing no helper with the emitter (W-U6/U8/U9); C5's sourced parsed-success boundary
  given full-strength witnesses (W-J11–J15: non-2xx, parse error, absent/empty GUID,
  deletion, hollowing); gate-B reviewer obligations named in §7.

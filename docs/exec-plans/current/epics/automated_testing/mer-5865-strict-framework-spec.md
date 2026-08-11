# MER-5865 — Strict adaptive verification framework: spec (refactor + three-lesson migration)

> Formerly `option-c-spec.md` — "Option C" was the winning branch of the MER-5674 driver
> decision (`mer-5674-driver-decision.md` §4); the checkpoint-A review history cites the
> old file name. The work's name is the strict adaptive verification framework.

## ⇥ HANDOFF — session boundary 2026-08-10 (read this first)

**Where we are → what's next:** steps 0–3 SHIPPED; gate B0 CLOSED by human call after 8
rounds; the gate-B **contract-before-build page is CLOSED SOUND-AS-DRAFTED** and committed
(`8a634180c2`). Next unit: **BUILD step 4** against that contract's IDs.

### SHIPPED (all ✅ verified this session; nothing pushed — human gates every commit)

- `2c843a8ecf` docs, `b05ac917cf` step 1, `5fb5bfee1c` step 2 — checkpoint-A core
  (journal/attribution/manifest/planner/oracle).
- `390aab1026` step 0 — etx spike.
- `ae207485b2` — oracle nav-`none` rotation amendment + archive-facts coverage gates
  (`combine_feedback`, `correct_plan_kinds`, `llm_feedback_capable` — all TOTAL maps,
  LLM-capable screens fail the build closed).
- `eaa725a19c` — step 3: `AdaptiveShadowCapture.ts`, `AdaptiveShadowProjector.ts`
  (fail-closed green+bail envelopes, lineage-bound save classification, §3.2-coextensive
  acceptance recomputation, archive-pinned driver-evidence inventory, cross-green
  equality), `mer5865-shadow-gate.spec.ts` (5 witness tests, 25+ standing witnesses),
  lote spec hooks.
- `f9f9982874` — evidence doc + B0 rounds 1–8 + closure consult + process consult.
- `8a634180c2` — **gate-B proof contract v6** (`mer-5865-step4-driver-swap-contract.md`) +
  six Codex design reads (`reviews/mer-5865-step4-contract-read{,-2..-6}.md`).

Every commit: `[ENHANCEMENT] [MER-5865] subject`, single line, no trailers.
Branch: `MER-5865-adaptive-lessons-share-strict-verification-and-migrate-real-chem-specs`
on `b8042f0cf8`.

### GATE B0 — CLOSED 2026-08-10 (human call; consult ENDORSE-WITH-AMENDMENTS)

Equivalence answered YES on stable evidence (4 greens + 2 bails across two capture sets:
0 in-scope / 0 unexplained / exact delta / 65=65 archive-pinned; bail differential at the
poisoned screen; offline gate 7/7). Round history + writer responses:
`reviews/mer-5865-gate-b0*.md` (committed). Closure statement + residual→step-4 discharge
map + **STEP-4 CONTRACT OBLIGATIONS (B4-C3/C4A/C5/C8/C12/C15/C16/STAMP/PRED)**:
`mer-5865-shadow-gate-evidence.md`. ⚠️ B4-STAMP and B4-C3/C15 are flagged MATERIAL for
gate B; C5/C8 discharges were REWRITTEN by Codex to journal-observed (never
driver-declared) — use the consult's wording, not older drafts.

### REVIEW REGIME (human decision 2026-08-10, "option C" — supersedes the checkpoint-loop model below for the REMAINING gates)

Gates B, C1, C2 are **SINGLE-PASS**: one contract-before-build read (the 1-page contract
MUST carry the B4-* IDs) + build with mechanical nets + ONE implementation review pass +
fixes + human call. **No re-review loops unless the human explicitly asks.** Rationale
(recorded): 18 rounds across checkpoint A + B0 were consumed by an unbounded
artifact-corruption threat model against evidence that is capture-internal by design until
step 4; the loop was structurally non-converging. Step 4's protection is mechanical: the
strict test subset (cite the EXACT executed subset, never "the 264"), the shadow
differential harness built precisely for the swap, and live acceptance runs.

### PRIVATE ARTIFACTS (scratchpad — answer values, never in repo)

`/private/tmp/claude-501/-Users-franciscocastro-code-oli-torus/17b893f6-258e-4945-ba2d-bfe0e7b81b49/scratchpad/mer5865/`:
`extract_lote_facts.py` (v7: combine map, correct_plan_kinds, llm_feedback_capable,
reproducible draft), `extract_lote_manifest_v2.py`,
`lote-archive-facts.json`, `lote-manifest-v2.json`. CURRENT captures (2026-08-10, r6
harness, correlation recorded): `shadow/lote-green-{1786378384523,1786378649848}.json`,
`shadow/lote-bail-1786378973158.json` (poison-stamped). The 2026-08-09 dumps are RETIRED
(r6 M1), forensics only. Replay:
`cd assets/automation && MER5865_MANIFEST=... MER5865_ARCHIVE_FACTS=... MER5865_GREEN_DUMPS=g1,g2
MER5865_BAIL_DUMP=... npx playwright test mer5865-shadow-gate` → 7/7. Both greens: in-scope
0, unexplained 0, 1 classified delta, 65=65 pinned. Bail: `verdict-not-correct` at
`q:1516177456571:380`. Server start (background OK):
`PLAYWRIGHT_ASSETS_BUCKET=torus-playwright-assets-dev PLAYWRIGHT_SCENARIO_TOKEN=my-token mix phx.server`;
capture env: `MER5865_SHADOW_DIR=<scratchpad>/mer5865/shadow PLAYWRIGHT_BASE_URL=http://127.0.0.1
PLAYWRIGHT_AUTOMATION_API_KEY=<admin api key with automation_setup_enabled>`.

### GATE-B CONTRACT — CLOSED 2026-08-11 (SOUND-AS-DRAFTED, committed `8a634180c2`)

`mer-5865-step4-driver-swap-contract.md` **v6 is normative for the step-4 build**: 26 atomic
proof rows, 75 witness subcases, two-stage predicate `SWAP-GREEN → GATE-B-CLOSE`, closed
delta list. Six Codex reads (8B/2SF → 7B/3SF → 3B/2SF → 3B/2SF → 4B/1SF → 0/0); rounds 1–2
killed two vacuous conjuncts and a reference that did not exist. Row/witness IDs are STABLE —
implementation tests, the CONFORMANCE-MAP, and the gate-B claims table reuse them verbatim.
Four derivations are deferred to the gate-B reviewer (contract §7, each with a RED condition
and UNEXECUTED = RED): EXIT-SCOPE source universe, EXIT-INV site list, VERDICT-S data-flow
inventory, CONFORMANCE-MAP semantic conformance.
⚠️ **Open human decision (contract §6.6):** adopt "at most one ACCEPTED finalization per run"
as a §3.2 amendment (writer recommendation) or keep B4-FIN1 narrowed to `already_submitted`.
Blocks the oracle finalization edit, not the registry/driver/manifest units.

### STEP-4 BUILD — unit 4a DONE (uncommitted, awaiting human gate)

`AdaptiveFamilyRegistry.ts` (new) + `adaptive-family-registry.spec.ts` (24 contract-matrix
tests) + 3 part-scoped readback primitives added to `AdaptiveDeckPO.ts` (additive only:
`partScope`, `mcqSelectionCount`, `fillTextInputInPart`, `textInputMatches`). Six LotE
families registered, keyed family+version(+mode), resolution fail-closed by name:
`janus-mcq@1:radio`, `janus-mcq@1:checkboxes`, `janus-input-text@1`,
`spr-widget-fill-in-the-blanks@2`, `spr-widget-matching@2`,
`spr-widget-general-drag-drop@6`. CAPI ownership is by `/family/` segment in the iframe src
PLUS declared major — a wrong-family resolution fails at detect (B4-REG-L's live half).
Readback is now REAL evidence per family (the shipped walker's `readback` was a cosmetic
string, `AdaptiveHappyPathTask.ts:484`). Verified: tsc (only the 2 known `liveSocket`
errors), eslint clean, prettier applied, 285/288 adaptive tests pass — the only failure is
the documented `adaptive-authoring:133` flake (see below). **Contract §6.8 added:** registry
version precision is MAJOR-only because the archive pins widget srcs at a major wildcard.
Remaining units: 4b manifest v2 + build gates, 4c driver + journal fences/permits, 4d spec
switch + verdict boundary.

**`adaptive-authoring:133` flake — new data (2026-08-11):** 1 pass in 5 runs this session
(recorded prior rate ~50%). Always fails at `BasicPracticePagePO.ts:399` waiting for
`.flowchart-node` toHaveCount(3), received 2 — the "-- Create new screen --" rule does not
add its node. NOT cross-test pollution: it fails with `:79` excluded too. Unrelated to the
registry (no import path; the deck-PO diff is additive). Still owed a real ticket + owner.

### NEXT

1. **BUILD step 4** against the contract IDs (swap the shipped walker internals:
   `AdaptiveHappyPathTask.ts`, `AdaptiveEvaluationObserver.ts`, `AdaptiveStrictContract.ts`
   become consumers of the committed core; driver-stamped fences; journal-domain permit +
   readback stamps per B4-STAMP).
3. Verify mechanically: strict suite + shadow differential harness (run the swapped driver
   on live LotE, gate compares accounts) + live acceptance run.
4. ONE implementation review pass (gate B) → fixes → human commit gate.
5. Then steps 5–6 → C1 (single-pass), 7–8 → C2 (single-pass), 9–10 (no Codex).
6. Open human actions: `adaptive-authoring.spec.ts:133` flake needs a real ticket + owner;
   leaked automation section/project slugs owed a batch cleanup.
7. Demo files (`mer5865-demo-oracle-contrast.spec.ts`, `mer5865-demo-presentation.html`,
   `branch-map-tsunami-mechanics.*`) NEVER committed.

Review model (human-agreed 2026-08-05; amended 2026-08-09, round-1 SF3 approved):
**checkpoints, not per-step loops** — **A CLOSED 2026-08-09** after 10 rounds (human call,
Codex ENDORSE-WITH-AMENDMENTS: `reviews/mer-5865-checkpoint-a-closure-consult.md`; all
round-10 findings fixed, 257/257), **B0 after step 3** (narrow gate on the shadow evidence,
before the step-4 switch), B after step 4, **C1 after step 6** (manifests + registry, before
either migration), C2 after step 8; steps 9–10 no Codex.

**Materiality policy for the remaining gates (human-adopted 2026-08-09, Codex amendments
folded):** a finding BLOCKS a checkpoint only when it is MATERIAL — it could (a) create,
preserve, or MASK a false-green outcome on a live run, **including common-mode agreement
where the driver and oracle/replay share the same malformed input, coercion, helper, or
self-asserted causal evidence**, or (b) mis-attribute a violation's screen (breaking the
step-3 same-screen comparison). Non-material findings (type narrowing, validation of unused
fields, defense-in-depth beyond the driver contract) are recorded and batch-fixed without
holding the gate — and they qualify as non-material ONLY when a traced consumer analysis
shows no path to a live decision, replay comparison, causal license, or screen attribution
in the current gate, and any deferral has a named owner that closes before first live use.

### HARD CONSTRAINTS

- Human authorizes EVERY commit. Codex reviews, never writes. One writer (Claude).
- `AutomationSetupTask.ts` + `AdaptiveLessonTask.ts` untouched (open PRs #6750/#6752); the
  shipped strict walker files (`AdaptiveHappyPathTask.ts`, `AdaptiveEvaluationObserver.ts`,
  `AdaptiveStrictContract.ts`) untouched until step 4 replaces them behind the shadow gate.
- Keys/archives never in repo; violations/reporter redacted by construction — no answer values.
- Verify per change: `cd assets/automation && npx playwright test adaptive- --reporter=line`
  (264 total as of 2026-08-10; `adaptive-authoring.spec.ts:133` flakes ~50% and takes its
  2 serial dependents with it — retry before treating as a finding) + tsc (exactly two
  fenced `liveSocket` errors) / eslint / prettier scoped to touched files.
- **GATE PROOF PROTOCOL (human-adopted 2026-08-10; full spec =
  `reviews/mer-5865-process-consult.md`, ADOPT-WITH-AMENDMENTS):**
  (1) Every gate submission carries a CLAIMS TABLE v3 — ATOMIC rows (no `mixed` class), one
  per claimed guarantee, columns: ID | claim | spec source | subject | reference +
  provenance | reference class (`independent-artifact` / `independent-source` /
  `capture-internal` — only the first two are independent checks) | shared
  producer/failure domain | positive witness | red witnesses | expected rejection locus.
  Coverage is BIDIRECTIONAL: every spec/gate obligation maps to a row and vice versa.
  (2) Witness minima per mandatory evidence source: positive + DELETION + HOLLOWING, plus
  the semantic mutations the claim implies (common-mode substitution, ownership swap,
  status corruption, ordering, duplication, cardinality-preserving replacement). Each
  witness names its expected rejection locus and records its latest replay.
  (3) Reviewer order: fresh-eyes pass FIRST (own claim inventory + mutations), claims
  table audited LAST, then conformance replay through the real gate entry point.
  (4) CONTRACT-BEFORE-BUILD for gates B, C1, C2: before machinery is built, a 1-page
  proof-design contract (decision + green predicate, threat list, atomic proof table,
  witness plan, composition/fail-closed rules, allowlist discipline, stable claim IDs that
  implementation tests reuse) gets ONE Codex pass. Its verdict means "reviewable design",
  never pre-approval; material predicate/reference/class changes reopen it.
  (5) No capture-internal row can independently license a green; the final decision
  formula is stated and mutated across row boundaries.

### DEBT / OWED

- Passive shadow capture (journal armed on live LotE runs) — deferred from step 1.
  **UNBLOCKED 2026-08-09: open question 4 resolved by the human — run budget unconstrained
  ("I don't care about polluting my local DB, we can reset it when needed"). Leaked slugs
  noted per run for later batch cleanup.**
- Journal permit/readback-stamp API — SUPERSEDED by **B4-STAMP** (a normative step-4
  contract row, flagged MATERIAL for gate B: one journal-owned sequence domain for entry
  fences, readback-completed fences, check/ack permits; caller-supplied seqs forbidden;
  both interleavings exercised per ordering-sensitive fence).
- Destination-guard ancestor-swap race (capture harness, r7 N1): close with a handle-based
  no-follow write before any capture on a shared machine.
- `adaptive-authoring.spec.ts:133` flake: needs a real suite-health ticket + owner (human).
- Open questions 2 (Santi/greenhouse), 3 (bucket key policy) — human.
  ~~Open question 4 (run budget)~~ RESOLVED 2026-08-09: unconstrained, local dev DB reset
  accepted.
- `mer-5674-followups.md` FU-2 (evaluate.ex 500 on rules-worker error) still open, unrelated ticket.

### GOTCHAS

- Playwright can emit `requestfailed` AFTER response headers — the recorder keeps request
  handles until records are TERMINAL; a body-read rejection is a failure, never a completion.
  Regressing this reintroduces round-2 B1.
- Attempt lineage must grow CAUSALLY (entered-at map): plain graph closure accepts a
  B→C-then-A→B mint order — round-2 B5; test "rooting is causal" is the tell.
- The oracle gates ABSENCE conclusions (missing ack/successor/lesson-end) on closed+settled
  windows (§3.2 matrix) — sealed-run tests fail loudly if that gating is loosened or dropped.
- tsc target < es2015 here: no for..of over Set/Map iterators or `.entries()` spreads in
  automation sources — use forEach/Array.from (and remember `continue` → `return` in callbacks).
- Tests must run from `assets/automation/` (its own package; repo-root `npx tsc` is a trap —
  and shell cwd PERSISTS between commands, so a stray `cd` poisons every later call: prefer
  absolute paths or re-`cd` per command).
- Playwright line-reporter output carries ANSI escapes — `grep -c "^\s+1 failed"` silently
  matches nothing; strip with `sed 's/\x1b\[[0-9;]*[A-Za-z]//g'` or judge by the LAST line
  ("N passed" = pass; a failed-test listing = fail).
- `npx playwright test --list` boots the dev webServer and can hang for minutes — don't use
  it for quick counts.
- NEVER `git stash` around a timeout-prone command: a timeout kills the compound command
  before `stash pop` and strands uncommitted work in the stash (cost a scare 2026-08-10;
  recovery: `git stash list` → `pop`). Back up files to the scratchpad instead.
- Prettier `--write` reformats beyond the diff you made — run it BEFORE final gate replays,
  and re-verify after.
- The dev server must be started with `PLAYWRIGHT_SCENARIO_TOKEN` + `PLAYWRIGHT_ASSETS_BUCKET`
  or every capture 401s/404s at asset fetch (values: HANDOFF "PRIVATE ARTIFACTS"). The
  capture API key is created at `/admin/api_keys` with automation_setup_enabled.
- The bail capture run's TEST FAILURE is the intended outcome — the dump file is the product.

### Pointers

Spec = the rest of THIS document (§7 = step order, §8 = verification). Vocabulary:
`adaptive-lesson-terminology.md`. Why the strict path exists: `lesson-completion-is-not-an-oracle.md`.
Review history: `reviews/mer-5865-step1-round-{1,2}.md`. Cross-session memory:
`~/.claude/projects/-Users-franciscocastro-code-oli-torus/memory/project_mer5865_status.md`.

**Status:** v9 — REVIEW LOOP CLOSED after pass 8 (writer's call, delegated by the human
2026-08-04): 8 passes, 62 findings, all folded; passes 4–8 surfaced no structural flaws, only
contract refinements of prior-pass constructs — remaining ambiguity is implementation-class
and belongs to the implementation review loop. AT HUMAN GATE. No code yet.
**Date:** 2026-08-04 (v9)
**Author:** Claude (writer). Review: Codex (design passes, then implementation review loop, no
round cap).
**Branch:** `MER-5865-adaptive-lessons-share-strict-verification-and-migrate-real-chem-specs`,
stacking on `b8042f0cf8` (the MER-5674 strict commit, PR #6761).
**Ticket:** [MER-5865](https://eliterate.atlassian.net/browse/MER-5865).

v2 changes: online/offline split made explicit (transaction executor + shared pure transition
planner — design-pass blocker 3); attribution windows and autonomous-check policy defined
(blockers 1, 2); full invariant inventory with explicit strictness scope (blocker 4); cross-screen
grading separated from local operations (blocker 5); scenario/screen-definition split and
skeletal extension points for branching / expected-wrong / computed (blocker 6); shadow
differential gate and reordered steps (blocker 7, should-fix 2); **round-4 findings recovered
verbatim from the 2026-07-31 session transcript** and mapped individually (blocker 8); etx spike
exit criteria hardened (blocker 9); predicate AST (should-fix 1); d-orbitals migrates before
greenhouse (should-fix 3); journal lifecycle/redaction contracts (should-fix 4).

v3 changes (pass 2): evaluation ownership split from payload provenance (blocker 1); one causal
edge per evaluation + navigation judged as one whole-sequence rule (blocker 2); journal freeze
boundary + request-time fail-closed classification + scope-table precedence (blocker 3); shadow
gate given an explicit equivalence projection, intentional-delta list, mandatory evidence, and
journal privacy (blocker 4); savedBarrier lower bound = readback-completed stamp (should-fix 1);
per-screen layer-parent chains (should-fix 2); expectation-specific readiness contract
(should-fix 3); scenario steps hold operation references, never copies (should-fix 4).

v4 changes (pass 3): navigation singleton must navigate/terminate + plan obligations must be
fulfilled, not just match (blocker 1); unresolved evaluation candidates in a screen window are
violations — preserves the shipped failed-duplicate guarantee (blocker 2); provenance by
precedence instead of disjointness — Codex measured both cross-screen dependency owners as
layerRef ancestors of their checking screens (blocker 3); transaction-built receipts for
expectation-only cross-screen steps (blocker 4); shadow projection restricted to fields the
shipped ledger actually exposes (blocker 5); freeze requires the lesson-end finalize resolved,
residual bound named (blocker 6); attempt-lineage temporal definition (should-fix 1); operation
ref validation contract (should-fix 2); first screens named correctly (nit).

v5 changes (pass 4, claims source-verified): lesson-end evidence is the page-lifecycle
finalization, not any activity-attempt PUT — journal scope widened to record it (blocker 1);
final-step "navigate off sequence" obligation fulfilled by lesson completion, no successor
visit (blocker 2); cross-screen receipts stop demanding earlier paths in the checking request —
the server assembles that state itself (`evaluate.ex` `assemble_full_adaptive_state`), evidence
is the earlier proven submission + the declared dependency + the usable verdict (blocker 3);
failure-sealed snapshots with restricted invariants make bail↔violation equivalence
implementable, plus a mandatory deliberate-bail differential run (blocker 4); feedback-plan
with queued navigation counts as navigating (should-fix 1); shadow transition fold = final
fulfilled plan (should-fix 2).

v6 changes (pass 5, claims source-verified): finalization acceptance contract — correlated to
this run's section/revision/attempt GUID, `commandResult: success` required, bounded wait, and
the corrected call chain through `LessonFinishedDialog` (blocker 1); cross-screen receipts
anchored to the archive-validated effective dependency set + source lineage + latest committed
pre-check state, and the §3.5 matcher formally split local vs cross-screen (blocker 2); atomic
seal with immutable cutoff and `seal_incomplete` semantics (blocker 3); failure-state matrix —
full audits only on closed settled windows, positive-only findings on open ones (blocker 4);
final-step exception requires normalized target `next` + archive-proven no successor
(blocker 5); archive↔map↔scenario completeness bijection at build time (should-fix 1);
cross-screen provenance rationale rewritten to the measured empty-payload shape (nit).

v7 changes (pass 6, claims source-verified): completed-failure frozen state with a positive
finalization-failure record auditRun accepts (blocker 1); committed-prior-state matcher
reproduces the server's latest-attempt/latest-part selection with stability through the
evaluation response (blocker 2); §8 deterministic contract matrices for every v6 contract
(blocker 3); typed driver-operation failure records as positive oracle evidence (should-fix 1);
seal membership fixed at requestSeq ≤ cutoff, completion during sealing allowed (should-fix 2);
closed predicate-operator enumeration with normalization rules (should-fix 3); raw journals
internal-only, failure reports emit the redacted projection (should-fix 4).

v8 changes (pass 7): two explicit freeze flavors — accepted-freeze and completed-failure
freeze with a terminalization rule for outstanding requests (blocker 1); closed
operation-failure union + `runRecord` in the auditRun signature + expected-step attribution
rule (blocker 2); per-part_id newest-attempt partition stated (should-fix 1);
through-response stability named as a deliberate strengthening (should-fix 2); production
operator modules declared normative with the divergent list-op truth conditions pinned
(should-fix 3); §8 matrices extended to the v7 contracts (should-fix 4).

v9 changes (pass 8, claims source-verified): terminalization is a persistent post-deadline
mode (blocker 1); the footer's exact combineFeedback selection algorithm made normative — not
"process all" (blocker 2); archive-to-expectation completeness rule for cross-screen receipts
(should-fix 1); production operator names adopted (`greaterThanInclusive`/`lessThanInclusive`,
json-rules-engine defaults) with empty condition args forbidden at validation (should-fix 2);
visit entry stamps issued from the journal's own sequence domain (should-fix 3); §8 matrices
extended: combined freeze state machine, classification precedence, operation-ref expansion
(should-fix 4).

Inputs: Codex's architecture verdict (SESSION-FINDINGS §5) and design-pass response
(2026-08-03); derive data for all three lessons (§3g); `testing-model-four-pieces.md`; the
shipped strict implementation; the `torus-adaptive-playwright` skill's support matrix.

---

## 1. Goal

Three deliverables, one branch:

1. **The refactor** — journal + attribution + permits + pure transition planner + pure oracle +
   family registry. Guarantees stay identical or get *deliberately* stronger (every strengthening
   named in §3.5's scope statement — none accidental).
2. **Strict migration of d-orbitals (MER-5673) and greenhouse (MER-5672)** — in that order
   (§4) — including Drive verification for every family they depend on.
3. **Deletion of the compatibility path** once nothing consumes it.

Out of scope: the offline map generator; lessons outside the three archives in our bucket;
`hotspot`/`slider`/`input-number`. Branching, expected-wrong verdicts and computed answers are
**shaped but not implemented** (§3.8) — Codex's principle, adopted: *shape future variation now;
implement it later.*

## 2. Why now (recap, one paragraph)

The strict oracle is proven (canary + 4 acceptance runs) but its build accreted through nine
review rounds: attribution in the per-screen observer, licensing in walker branches, auditing
split across inline bails and `assertLedger`. Codex's verdict: right oracle, over-distributed
ownership; rounds 3–4 measured it — all seven round-4 findings traced to round-3 fixes. Both
merged specs assert only completion text — measured compatible with "4 of 22 screens never
answered" — and every family they depend on is Drive-unverified.

## 3. Target architecture

### 3.1 The pieces

| Piece | Job | Purity |
|---|---|---|
| **Map** | course facts: reusable screen definitions (identity, role, parts, grading expectations, local operations) | data |
| **Scenario** | the path program for THIS run: ordered check-steps referencing screen definitions, each step carrying its expected verdict and licensed operations. Linear happy-path for the three lessons; the shape, not the implementation, admits branches and wrong-then-correct sequences | data |
| **Registry** | family+version(+mode) interaction mechanics | impure, page-scoped |
| **Driver** | screen-transaction executor: performs operations, records permits, visit stamps and typed operation-failure records (§3.2), and **decides what to do next by incrementally waiting on journal evidence and calling the transition planner** | impure |
| **Transition planner** | ONE pure function `(evaluationRecord, screenDef, scenarioStep) → plan` (await-navigation / ack-feedback / expect-recheck / terminal). The driver uses it online; the oracle replays it offline. One derivation, two callers — the seam that previously duplicated transition judgement is gone by construction, not by hope | pure |
| **Journal** | immutable lesson-lifetime record of `/activity_attempt/` traffic + the page-lifecycle finalization (§3.2) | recorder |
| **Attribution** | pure reducer over journal + visit stamps (§3.3) | pure |
| **Oracle** | `auditRun(map, scenario, runRecord, journal)` → `Violation[]`, where `runRecord = {visits, permits, receipts, operationFailures}` (§3.2); replays the planner and checks every invariant in §3.5 | pure |
| **Reporter** | renders `Violation[]`; violations are **redacted by construction** — constructors accept part paths, counts, kinds and booleans, and have no field that can hold an answer value | pure |

### 3.2 Journal

Page-level recorder attached before the deck loads, **detached in a `finally` owned by the spec
fixture** — early exceptions cannot leave it dangling or lose captured evidence (the partial
journal is part of the failure report). Records creations (POST), saves (PATCH `/active`),
evaluations/finalizes (PUT) with the monotonic seq counter, parsed bodies, parse errors — and a
**terminal record for every failed/aborted request** (Playwright `requestfailed`), so `settle()`
converges on an auditable record instead of waiting on traffic that will never respond.

**Classification happens at request time, fail-closed.** URL + method fix the class candidate
before any response exists: PATCH `/active` = save; POST = creation; PUT = evaluation-or-finalize
candidate, resolved by the response body — a PUT whose response never arrives or fails stays an
**unresolved evaluation candidate**, never silently a finalize.

**Journal scope includes the page-lifecycle finalization — with an acceptance contract.**
Lesson completion is finalized by a POST through `finalizePageAttempt`, issued NOT by
`finalizeLesson` (which only sets Redux lesson-end state, `deck.ts:454-458`) but by
`LessonFinishedDialog`'s unawaited effect (`LessonFinishedDialog.tsx:52` →
`page_lifecycle.ts:21`, body `action: 'finalize'`). No `/activity_attempt/` PUT identifies
lesson end: bare-success activity-attempt PUTs are ACTIVITY finalizes and can be intermediate.
The recorder captures this POST, and it counts as freeze/terminal evidence only when
**accepted**: correlated to this run's section slug, revision slug, and resource-attempt GUID,
parsed, `result: success` with `commandResult: success`. `already_submitted` is a violation —
every strict run owns a fresh section, so it cannot legitimately occur (revisit if the shadow
gate ever shows one). A missing, failed, or uncorrelated finalization does not hang freeze: the
wait is bounded; on expiry or rejection the journal takes the **completed-failure freeze**
(below) with a positive **finalization-failure record**
(`reason: missing | uncorrelated | malformed | failed | already_submitted`). `auditRun`
accepts both freeze flavors; the §3.5 terminal obligation reads the record and emits the
violation — a completed lesson whose finalization misbehaves is auditable, never stuck
between "cannot freeze" and "seal matrix skips finalization".

**Two freeze flavors, both immutable, both auditable.**
*Accepted-freeze:* lesson-end signal → correlated finalization ACCEPTED → zero outstanding →
quiescence → detach.
*Completed-failure freeze:* lesson-end signal → acceptance wait expired or finalization
rejected → **terminalization becomes a PERSISTENT MODE**, not a one-shot: at the deadline
every still-outstanding request (including a response-less finalization POST) receives a
terminal `unterminated` record, and from that point on ANY newly observed request is
terminal-recorded immediately on observation — so a quiescence-restarting arrival can neither
hang the freeze nor leave the journal detached with outstanding traffic → quiescence judged
over the terminalized stream → detach, finalization-failure record attached. No run outcome lacks an
auditable terminal state: green runs take accepted-freeze, completed-but-finalization-broken
runs take completed-failure freeze, pre-completion failures take the seal.

**The audited snapshot has a freeze boundary.** `auditRun` accepts only a **frozen** journal —
either flavor above. Accepted-freeze requires ALL of, in order: the deck's lesson-end signal;
the page-lifecycle finalization ACCEPTED per the contract above (freeze cannot precede the
very record §3.5 requires); zero outstanding requests; then a full quiescence interval with no
new observed traffic (length set
empirically in step 1; the shipped 500 ms quiescence reads are the prior). A zero-pending
instant is not quiescence — that is exactly the R4-SF1 race; an arrival during the interval
restarts it. The recorder detaches only at freeze (the `finally` covers failure paths via the seal). Raw
journals — frozen or sealed, with parsed request bodies — are INTERNAL oracle input and
private artifacts only (§7 step 1); every emitted failure report carries the §3.7 redacted
projection, never parsed bodies. **Residual bound, named:** traffic
that starts after detach is unobservable — the quiescence interval is the explicit bound, the
same class as the shipped `settle()` timeout. The step-3 harness enforces both: freeze is
impossible while anything is outstanding, and in-interval arrivals extend the window.

**Freeze-timeout record (round-2 amendment, 2026-08-05).** When the finalization is ACCEPTED
but traffic never quiesces within the overall freeze deadline, the run does not freeze — it
bails and SEALS. Before the bail the journal records a typed `freeze_timeout` entry
(outstanding count at expiry); the sealed snapshot carries it and `auditRun` maps it to a
violation, preserving the bail↔violation equivalence even when every member of the sealed set
completed (informational traffic can keep the wire busy with zero outstanding). Journal-side
evidence — the driver operation-failure union below stays closed.

**Failure-sealed snapshots — atomic seal, then a failure-state matrix.** When the driver fails
or bails before lesson end, the recorder makes an atomic state transition
`armed → sealing → sealed`: the seal fixes an immutable cutoff seq; **audited-set membership is
determined by `requestSeq <= cutoff` alone** — a member record whose response arrives during
`sealing` is completed in place (that is what the bounded settle deadline is for), while a
request starting after the cutoff is counted as a post-seal marker and never enters the
audited set. If the settle deadline expires the snapshot is marked `seal_incomplete`. The
audited object never mutates after `sealed`. Restricted invariants on a sealed run, by window state:

| Window state at seal | Audits allowed |
|---|---|
| closed AND settled | full: cardinality, absence, fulfilled obligations |
| open (no closing stamp — includes the step in transit and a failing step with no entry stamp yet) | positive observed violations only; no absence or cardinality conclusions |
| any, when `seal_incomplete` | positive observed violations only, journal-wide |
| end-of-run invariants (full coverage, terminal, page finalization) | skipped always (completed runs with finalization failures use the completed-failure frozen state above, not a seal) |

**Typed driver-operation failures are positive evidence — a CLOSED union in the oracle
contract.** Many bails leave no journal trace. The driver records each as an
**operation-failure record** in the `runRecord` that `auditRun` takes as an argument
(§3.1: `auditRun(map, scenario, runRecord, journal)`, where
`runRecord = {visits, permits, receipts, operationFailures}`). The union, closed — an
unlisted failure mode is itself a spec bug, not a free extension point:
`identity-unresolved | readiness-timeout | answer-failed | readback-failed | barrier-timeout |
check-click-no-effect | feedback-never-opened | ack-no-effect | widget-button-unavailable |
navigation-timeout`. **Attribution rule:** to the observed screen when an identity was
resolved; otherwise (`identity-unresolved`) to the EXPECTED scenario step by position — so
same-screen shadow equivalence is deterministic even when the failure is that identity never
arrived. The oracle maps every record to a violation; a sealed audit cannot return zero
violations for an ordinary bail.

This is what makes the §7 step-3 bail↔violation equivalence implementable — a bailed run's
journal can never satisfy the freeze predicate.

### 3.3 Attribution

Pure `attribute(journal, visits, layerParents)` where `visits` are the driver's stamped windows.
Window semantics, explicit:

- **Half-open ownership windows.** Screen S owns `[entryStamp(S), entryStamp(S+1))` — the stamp
  is taken at identity read of the *next* screen, not at navigation, so traffic during a
  transition (after the old screen changes, before the new identity is stamped) stays with the
  old screen. **Entry stamps are issued by the JOURNAL from its own monotonic seq domain** — a
  fence event the driver requests at identity read — never wall clocks or a driver-local
  counter, so an identity-read racing a request has one strict order (§8 tests both
  orderings). This reproduces the current held-observer semantics ("pathless late traffic
  belongs to the screen just completed") as data, not lifecycle.
- **Pre-entry window.** `[journalStart, entryStamp(first))` is the init window: it is owned by
  the first screen, and its evaluations enter that screen's §3.4 navigation sequence rule (all
  three lessons start on navigation screens — LotE's buttonwidget Cover, d-orbitals' Title and
  greenhouse's Welcome Screen, the latter two janus-navigation-button; a non-navigation first
  screen with pre-entry evaluations is a violation). LotE's Cover init-time check — measured,
  rendered `e6fd16a7` / submitted `5c3a94ec` — lands here *visibly* instead of before any
  observer armed.
- **Evaluation ownership ≠ payload provenance — two separate judgements.** An evaluation is
  OWNED by the step whose window covers its requestSeq, cross-checked by attempt lineage (the
  screen's rendered attempt plus journal-observed mints targeting it) — never by its payload
  prefixes. Prefix-first ownership is unsound: the measured cross-screen checks submit EMPTY
  local `partInputs` (the server assembles dependency state itself, §3.6), and any future
  payload legitimately carrying a dependency's prefix would be mis-owned by the earlier
  screen — stranding the checking step and faking a duplicate. Payload PROVENANCE is then
  validated on the owned
  evaluation: every submitted prefix must be the owning screen's own, one of its declared
  cross-screen dependencies, or one of its whitelisted ancestors — anything else is
  contamination. A pathless record is owned by its window's screen, lineage-checked the same
  way; a record whose GUID belongs to no known attempt of that screen is a violation, not
  silently owned. **Attempt lineage, precisely:** the screen's rendered attempt, extended only
  by mints — each a parsed 2xx POST creation whose response supplied the new GUID and whose
  responseSeq precedes the requestSeq of every evaluation using that GUID — recursively rooted
  at the rendered attempt. A failed, unparsed, or temporally later creation confers nothing.
- **Layer parents are per-screen ancestor chains, resolved by precedence — no blanket
  disjointness.** Codex measured (pass 3) that both cross-screen dependency owners are ALSO
  layerRef ancestors of their checking screens (450042→453181, 459700→459104), so the classes
  overlap in the real lessons. Provenance of each submitted prefix resolves in order: the
  owning screen's own prefix → a declared cross-screen dependency → an ancestor prefix that is
  NOT a manifest screen → violation. A manifest-screen prefix that is not a declared dependency
  is contamination even when it is an ancestor. Build-time validation: ancestor chains derived
  per screen from the archive hierarchy; every declared dependency must name a manifest screen.
  **Deliberate strengthening**: today any non-manifest prefix is tolerated
  (`AdaptiveHappyPathTask.ts:217-228` filters contamination against manifest ids only);
  recorded in §3.5's scope statement.

### 3.4 Permits

One permit per **evaluation-capable operation** — not per physical click (registry answer
gestures are many clicks and evaluation-incapable) — and **exactly one causal edge per
evaluation**, so no evaluation ever has two possible owners:

- `check-click(screen, step)` — licenses exactly the FIRST evaluation that follows it. Nothing
  else.
- `feedback-ack(screen, step)` — one click, one permit; it ALONE licenses the optional second
  evaluation, and only when the planner's plan for the acknowledged response was
  `expect-recheck` (`DeckLayoutFooter.tsx:679-681`). The re-check's causal edge is the ack —
  never also the check-click.
- `widget-button(screen, step)` — navigation screens' in-widget button. **Licenses no
  evaluation directly**; navigation evaluations are judged only by the sequence rule below.
- **Navigation sequence rule** (one rule over the WHOLE sequence — replaces both the shipped
  `assertNavigationEvaluations` and any per-record policy): collect every evaluation owned by a
  navigation screen — pre-entry window included, widget-triggered or not — as one ordered
  sequence. Legal shapes, exhaustively: empty (the widget navigated without checking); one
  usable evaluation under a single attempt **whose plan navigates or terminates** — a feedback
  plan whose post-ack obligation is navigation counts as navigating (the product queues the
  target and navigates on ack, `DeckLayoutFooter.tsx:565-571`); an
  incorrect non-navigating singleton is a violation even if the deck somehow advanced, because
  it is precisely the first half of a rotation whose completion was never proven; or the
  measured rotation (incorrect check whose plan is FEEDBACK **or NONE** and does not navigate —
  **shadow-measured 2026-08-09, writer-proposed pending B0:** the live deck's incorrect nav
  check returns one result with an EMPTY actions array, deriving `none`; the widget handles
  its feedback internally, so `none` is the measured first half on THIS role → 2xx POST mint
  observed between → correct navigating check under the minted guid). Every record usable (2xx, parsed,
  boolean `correct`). Judging the whole sequence at once means a rotation chain can never be
  split into a "legal pre-entry singleton" plus a "widget-permitted check" that individually
  pass while the causal mint audit is bypassed.
- **Navigation ack fulfillment (amendment, human-approved 2026-08-09, checkpoint A):** the
  widget acknowledges its own feedback INTERNALLY — off the wire, off the driver's hands — so
  on navigation screens no `feedback-ack` permit exists to demand: the rotation's
  feedback/recheck obligation is fulfilled by the causal mint plus the second evaluation (the
  rotation shape above). The driver records its online plan for EVERY navigation evaluation
  (§3.5 replay agreement binds unchanged) but never stamps an acknowledgment permit it did not
  perform.
- Non-navigation screens: an evaluation with no causal edge is a violation, full stop.

### 3.5 Oracle — invariant inventory and strictness scope

`auditRun` re-states, explicitly and exhaustively (design-pass blocker 4):

**Run shape:** ordered full coverage of the scenario; exact cardinality; no undeclared screens;
run-internal live-resourceId consistency; terminal transition only at the last step **and** the
deck independently reported lesson completion (two distinct checks, both kept —
`AdaptiveHappyPathTask.ts:262-265` today). Scenario coverage alone is self-referential — the
archive↔map↔scenario completeness bijection is a build-time obligation (§3.8).

**Per evaluation:** every owned evaluation has exactly one causal edge, or falls under its
navigation screen's sequence rule (§3.4); **every
counted evaluation of any role must be usable** — response received, 2xx, parsed, boolean
`actions.correct` (today: nav via `assertNavigationEvaluations`, graded/content via
`waitForUsableEvaluation`); `none` is not a legal post-check plan **on non-navigation
screens — on navigation screens the rotation's first check measurably derives `none`
(shadow capture 2026-08-09; §3.4 amendment pending B0)**; a re-check must end in
navigation or terminal.

**Per graded step:** receipt present; **every licensed evaluation — including the feedback
re-check — has verdict `correct: true` AND satisfies its receipt's MATCHER** (today:
`onSecondEvaluation` folds both); first evaluation belongs to the rendered attempt. Two formal
matchers, never mixed: local receipts match the current request's payload; cross-screen
receipts match committed prior state per §3.6 — their current-request check covers local
inputs only, vacuously.

**Per content step:** exactly one evaluation, rendered-attempt anchored, verdict unasserted.

**Barriers:** a receipt's `savedBarrier` is satisfied only by a PATCH save observed **after the
family's answer + readback completed (a driver-stamped seq) and before the check-click permit's
seq** — a save emitted mid-gesture cannot satisfy it (prefix-only CAPI barriers would otherwise
accept the widget's initial-state save). Oracle-checked from the journal, not merely awaited by
the driver (today `waitForPropagatedState` only gates from answer *start*, and nothing audits it
afterwards — a strengthening, named).

**Transition fidelity:** the oracle replays the planner over every owned evaluation and the
recorded plan must match — **and every plan's obligation must be fulfilled by later journal or
visit evidence**: feedback ⇒ its ack permit exists; expect-recheck ⇒ the ack-licensed second
evaluation exists — both on NON-NAVIGATION screens; on navigation screens the widget's
internal ack has no permit to stamp, and the feedback/recheck obligation is fulfilled by the
causal mint plus the second evaluation of the §3.4 rotation (amendment, human-approved
2026-08-09); navigate ⇒ the next visit stamp follows — EXCEPT on the final step, where a
navigate plan (including a re-check's) is fulfilled by lesson completion instead of a successor
visit (**navigate off sequence**) — and it qualifies ONLY when the plan's normalized target is
`next` AND the manifest proves offline that this step is the sequence's last navigable entry:
the deck ends the lesson exactly when `next` resolves no successor (`deck.ts:361`); `prev`,
`first`, `last` or an explicit target never qualify, so an unrelated lesson-end signal cannot
fulfill an illegal navigation; terminal ⇒ lesson end plus the ACCEPTED page-lifecycle
finalization (§3.2). A matching plan with an unfulfilled obligation is a violation. The planner implements
`combineFeedback` with the product's EXACT selection algorithm as normative
(`DeckLayoutFooter.tsx:423-444`), not "process all": when `combine_feedback: true`, the
processed set is — ALL results when every result carries the same navigation target; otherwise
FIRST result only when the first event navigates AND the aggregate verdict (`every result
correct`) is false; otherwise ALL results. `combine_feedback: false` processes `results[0]`
alone. Any deviation between planner and footer here changes navigation/feedback/re-check
obligations downstream — the matrix (§8) covers all four branches.

**Strictness scope statement** (what is a violation vs. informational — design-pass blocker 4's
"accidentally stronger" point, resolved by naming):

Classification is by kind first (fixed at request time, §3.2); exactly one row applies per
record — no record is ever both informational and a violation:

| Record class (in precedence order) | Treatment |
|---|---|
| evaluations | fully audited: causal edge / navigation sequence rule, usability, verdict, payload provenance (§3.3 — provenance applies to evaluations ONLY) |
| unresolved evaluation candidates (failed/response-less PUTs) | **violation whenever owned by any screen's window** — fail-closed. This preserves the shipped guarantee that ANY extra PUT, even failed or response-less, breaks count equality (`evaluations()` counts `unknown`-kind records today, `AdaptiveEvaluationObserver.ts:171-173`). Recorded-only when owned by no window at all |
| activity finalizes (bare-success `/activity_attempt/` PUTs) | informational — may legitimately be intermediate; none identifies lesson end |
| page-lifecycle finalization (POST `action: 'finalize'`) | required at lesson end — terminal obligation and freeze evidence (§3.2); absence on a completed run is a violation |
| PATCH saves | informational, EXCEPT those satisfying a `savedBarrier` (audited, §3.5 Barriers). Saves are exempt from provenance — they persist accumulated deck state |
| attempt creations | informational, EXCEPT mints causally required by a navigation sequence (audited) |
| other failed/aborted requests | terminal-recorded, reported, never block freeze |

**Named deliberate strengthenings beyond shipped behaviour — the complete list:** the §3.3
provenance whitelist; the §3.5 savedBarrier temporal audit; unresolved-candidate violations;
the §3.4 incorrect-non-navigating-singleton rejection; `already_submitted` as violation; the
§3.6 through-response stability window (conservative bound on an unobservable server read).

### 3.6 Family registry

One module per family, keyed **family + version (+ mode)**, resolution fail-closed by name.
Interface:

```
detect(screenDef, partInventory) -> owned part | null | throw-on-ambiguity
ready(page, part) -> stable | throw
answer(page, part, directive) -> void | throw        # ALL interaction scoped to `part`
readback(page, part, directive) -> evidence | throw
expectedPayload(part, directive, runContext) -> ExpectedSubmission
savedBarrier(part, directive) -> ExpectedSubmission
```

- **Interaction scoping is part of the contract** (round-4 B4's class): `answer` receives the
  owning part and may not touch page-global controls; a screen with several parts of one family
  either names the owner in the map or throws. Today `part_id` scopes receipts but
  `setNativeDropdowns`/`setFibDropdownsByLabel` act page-globally — that asymmetry does not
  survive the move.
- **`runContext`** (read-only: receipts and submitted state of earlier steps) flows into
  `expectedPayload` — required by cross-screen grading (§3.8) and reserved for computed answers.
- **Expectation-only steps get a transaction-built receipt — matched against PRIOR evidence,
  not the checking request.** The two measured cross-screen screens have no local operations
  and `detect → null`. Their checking request legally carries empty `partInputs`: `triggerCheck`
  submits only the current attempt's parts, and the server itself assembles the earlier
  screens' state from `activitiesRequiredForEvaluation`
  (`triggerCheck.ts:194`, `evaluate.ex` `assemble_full_adaptive_state`). Demanding the earlier
  screen's paths in the checking payload would reject both measured patterns. The SCREEN
  TRANSACTION builds the receipt (`directive: 'cross_screen'`, `savedBarrier` empty) and its
  evidence — the **committed-prior-state matcher** — is: (a) the manifest's declared dependency
  is validated OFFLINE against the archive's effective dependency set (the activity's
  `activitiesRequiredForEvaluation` plus what its rules reference — the server infers exactly
  this via `AdaptiveRuleRequirements.infer`, `evaluate.ex:448-453` — so a mistaken manifest
  dependency cannot self-validate); (b) the matcher reproduces the server's own selection —
  **newest activity attempt for the dependency, then within it the newest part attempt PER
  `part_id`, all per-part responses merged** (`hierarchy.ex` `get_latest_attempts` partitions
  by part_id; a single-newest-row implementation would not reproduce `evaluate.ex:778`) — so
  the matched state is the latest committed state of that lineage, a later attempt MINT alone
  shifts the effective lineage even without a later save, and the state must hold **stable
  through the checking evaluation's responseSeq** — a DELIBERATE STRENGTHENING (named in
  §3.5's list): the server reads at an unobservable instant mid-evaluation, so the matcher
  conservatively rejects mutations the real read may not have seen; a correct save
  followed by a poisoned one, or by a fresh attempt, fails — the stale-correct receipt cannot
  pass; (c) the checking evaluation is owned, usable, verdict true, its payload audited for
  local inputs only (measured: empty). Validation is BIDIRECTIONAL: declared dependencies must
  belong to the archive's effective set, AND every prior-state reference in the expected-correct
  rule must be covered by a grading expectation — an underdeclared receipt that validates only
  a subset of the intended prior state fails the manifest build, it cannot lean on the verdict
  for the rest. The graded-step-has-receipt invariant (§3.5) holds unchanged.
- **Readiness is expectation-specific** (R4-B3's swallowed footer timeout was intentional —
  widget-button screens can lack a footer): a step planning `check-click` requires footer
  readiness and fails loudly without it; a widget-navigation step instead requires its registry
  entry's own control ready. No readiness wait is swallowed; each is owned by the expectation
  that needs it.
- Seeded by **moving** the six verified families' code; new families (§6) are new entries.
- Carousel entry's readback asserts `Viewed Images Count >= N`; flashcard asserts
  `All Modified`; video asserts `hasStarted` where the rule gates on it.

### 3.7 Reporter

Renders `Violation[]` + journal summary. Redaction by construction (§3.1). Part paths, counts,
kinds, match booleans — never values; traces run with the private key.

### 3.8 Map + scenario schema (v2)

Two layers, replacing the single `screens` array (design-pass blockers 5, 6; should-fix 1):

**Screen definitions** (reusable, per screen):
- identity (`id`, archive `resource_id`), role, `combine_feedback?`, layer-parent list at map
  level;
- **local operations**: directives the driver performs on this screen — answer directives
  (family, version, mode, values/predicates) and **gates** (`carousel_view`, `flashcard_flip_all`,
  `video_start`) as a separate list, not under answers;
- **grading expectations**: what the evaluation payload must satisfy — usually derived from the
  screen's own directives, but expressible independently for the two measured cross-screen
  screens (empty `partsLayout`, rule reads another screen's part): the expectation names the
  owning screen's part path and is resolved against `runContext`, while local operations stay
  empty. `detect → null` on such screens is legal; the check-click still happens; the receipt
  is transaction-built (§3.6).

**Predicates as a typed AST with a CLOSED operator set** — the framework's enumeration, complete
(anything outside it fails manifest validation by name):
`equal | notEqual | contains | notContains | containsAnyOf | notContainsAnyOf | containsOnly |
greaterThan | greaterThanInclusive | lessThan | lessThanInclusive | minLength | maxLength |
selectedCountEqual | selectedCountNotEqual`.
Names follow the PRODUCTION surface verbatim — the numeric comparisons are json-rules-engine
default operators (`rules-engine.ts:40-53` registers module operators on top of the engine's
defaults), so the AST uses `greaterThanInclusive`/`lessThanInclusive`, never
`greaterThanOrEqual` synonyms; archive operator → AST is an identity mapping, no translation
layer to drift. Falsy-input behaviour is inherited from the normative modules; empty condition
arguments are forbidden at manifest validation, never silently passing.
Argument types per operator declared in the schema (string / number / boolean / list);
normalization rules fixed: `selectedChoices` values normalize from BOTH measured encodings —
stringified array `"[1,2,3]"` and native list — to a number list before comparison; text
comparisons trim and case-fold; length operators apply to the normalized string. Conjunction
is the explicit `all: [...]` node only — no implicit AND/OR (disjunction lives inside
`containsAnyOf`-class operators). Measured need covered: `contains 'disaster' AND contains
'hazard'`, `numberOfSelectedChoices` constraints, the six multi-select operators, carousel
`greaterThan`, climate-sim `notEqual`. **Truth conditions are NORMATIVE from the product's own
operator modules** (`assets/src/adaptivity/operators/*.ts`) — matcher implementations mirror
them, never re-derive; the divergent list-op semantics pinned here so implementations cannot
disagree: `contains` = every condition element present in the input; `notContains` = its
negation (`contains.ts:52`); `containsAnyOf` = intersection non-empty; `notContainsAnyOf` =
intersection empty; `containsOnly` = same elements with equal cardinality. The manifest schema
declares a per-operator argument-type table; an unknown operator or type-mismatched argument
fails validation by name.

**Scenario** (per run): ordered check-steps `{screen_ref, expected_verdict, operation_refs}`.
`operation_refs` REFERENCE the screen definition's local operations by id — never inline copies
or overrides; values and predicates live only in screen definitions, so map and scenario cannot
drift. Contract, validated at manifest build: every local operation declares an `id`, unique
within its screen; refs are unique, and resolve within the referenced screen only; execution
order is screen-definition order regardless of ref order; the default (refs omitted) expands to
every local operation exactly once. **Completeness is validated against the ARCHIVE, not the
map itself** (scenario-only coverage is self-referential — the historical 4-of-22 failure
class would survive it): the reachable screen inventory derived from the archive's transition
graph must map 1:1 onto screen definitions, and the scenario must hold exactly one step per
screen ON ITS ROUTE; any screen off the route is explicitly classified in the manifest, never
silent. **Measured 2026-08-04 (dev DB, all 43 + 34 activities): greenhouse and d-orbitals are
NOT strictly linear** — Plate Tectonics is (0 of 22 non-`next` targets), but both Real Chem
lessons fork at Title on session state (`correct new` → Welcome New, `correct exists` →
Welcome, converging 2 screens later), and greenhouse's `Predicting Greenhouse Gases` correct
rule skips a screen. A fresh seeded run is deterministic — always the new-student branch — so
each lesson still has ONE fixed happy-path route, but the scenario encodes that route, not the
sequence order, and the skipped screens (`Welcome` in both; greenhouse position 13) are the
classified exclusions. This also partially explains the 33-vs-43 / 30-vs-34 count gaps. For
the three lessons: one step per on-route screen, `expected_verdict: correct` throughout — but the
expectation hangs on the **step**, not the screen, which is exactly what wrong-then-correct
(MER-5670) needs; branching becomes a different scenario over the same screen definitions
(MER-5677); a directive's value slot admits `{computed: <strategy-ref>}` resolved against
`runContext` (MER-5675) — **strategy references reserved, no strategy implemented; branching
scenarios representable, only single-fixed-route ones executable; expected_verdict only `correct`
accepted by the executor in the framework's initial scope.** Skeletal shape now, implementations later.

### 3.9 Round-4 findings — recovered and mapped

List recovered verbatim from the 2026-07-31 session transcript (design-pass blocker 8). Rounds
5–9 (2026-08-03, `reviews/mer-5674-round-{5..9}.md`) already resolved two of them in shipped
code. Full mapping:

| # | Finding (2026-07-31) | Fate |
|---|---|---|
| R4-B1 | nav single-attempt audit ran before the held-observer boundary/settle; second nav evaluation's GUID never joined the audit | **already fixed** rounds 5–7: `assertNavigationEvaluations` runs post-settle over all records (`AdaptiveHappyPathTask.ts:230-232, 332-403`); C re-states it as the §3.4 navigation sequence rule — oracle test carries it |
| R4-B2 | nav evaluations never checked usable (2xx/parsed/kind) | **already fixed** round 5 (`AdaptiveHappyPathTask.ts:352-367`); generalised in §3.5 "every counted evaluation usable" — oracle test |
| R4-B3 | observer handoff blind gap (dispose → next arm) + next-screen init check misclassified as foreign; also `AdaptiveDeckPO.ts:53` swallows the footer-readiness timeout | **seam deleted**: lesson-wide journal has no handoff; §3.3 windows own the transition interval explicitly. Footer swallow: replaced by §3.6's expectation-specific readiness contract, with test |
| R4-B4 | `part_id` scopes receipts but not interaction; native dropdowns bypass `needOwningPart` when `part_id` omitted | **survives the move** — registry contract §3.6 makes interaction scoping structural; regression test per affected family (dropdowns, fib_labels) |
| R4-SF1 | fake deck not timing-faithful (PUTs awaited, `fireLate` awaited, no-op readiness) — "post-boundary" tests weren't | new test harness requirement (§8): async responses, genuinely late traffic, settle() tested with in-flight and post-zero-check arrivals |
| R4-SF2 | uncovered paths: end-to-end LLM-feedback, PATCH `awaitSaved` gate, mixed-prefix contamination, multi-part `part_id`, duplicate-label `min_count` | explicit oracle/registry test list (§8) |
| R4-SF3 | `min_count` counts array entries, not distinct paths — one duplicated blank satisfies `min_count: 2` | **still live in shipped code** (`AdaptiveStrictContract.ts:327-334`). Fixed in the oracle's payload matcher: count distinct matching paths; regression test |

### 3.10 What dies where

| Seam | Dies because |
|---|---|
| per-screen observer lifecycle (late arming, handoff gap, settle ordering) | journal is lesson-wide; windows are data |
| walker-inline licensing (`expectedEvaluations` mutation, `onSecondEvaluation`, nav special-case) | permits + planner-derived cardinality + oracle rules |
| duplicated transition judgement (walker `followTransition` vs oracle re-derivation) | one pure planner, driver and oracle both call it |
| duplicated auditing (inline bails vs `assertLedger` vs `verifyScreenEvaluation`) | one `auditRun`; the driver stops on planner/permit failure and reports via the oracle |

## 4. Migration plan per lesson

Common shape: manifest (map + scenario) authored and statically validated → key uploaded →
registry entries live-verified per family (§6) → spec on the strict entry point → canary → 3×
fresh-seed green runs, traces kept.

Order: **LotE → d-orbitals → greenhouse** (design-pass should-fix 3: at migration stage
d-orbitals dominates greenhouse-first — smaller integration, no external-owner gate, proves the
architecture generalises before the broadest lesson switches; etx risk is already exposed by
step 0 and the family gates).

### 4.1 LotE Plate Tectonics — engine swap, refactor regression proof

Manifest v2: 246-char invented strings → `minLength 50/30` predicates; `combine_feedback` flags
(4 screens); layer-parent whitelist; scenario split. Re-upload `mer-5674/answers.json`
(policy: open question 3), spec on new engine, canary + 3× runs. Baseline 4.5–4.8 min.

### 4.2 Dazzling d-Orbitals (MER-5673) — first compat→strict migration

Own spec, no external coordination. Families: `janus-fill-blanks` (3), `drag-and-drop-component`
(S3, 2), `flashcard`, `janus-image-carousel`, `janus-video` (gating), `janus-input-text`;
non-answering: `progress-bar` (6), `janus-popup` (2), `etx-scripts` (4, none graded). Screen
count 30 (ticket) vs 34 (§3g DB read) resolved at manifest authoring (step 4). Compat baseline
4.8 min.

### 4.3 Greenhouse Molecules (MER-5672) — last, broadest, externally owned

Families: `janus-fill-blanks` (7), `janus-dropdown` (10), `grouping` v1, `order-list` v5,
`matching` v2, `janus-input-text`, `janus-navigation-button`, **`etx-scripts` (2 graded — gated
on the §5 spike outcome)**, gates climate sim (1 graded); non-answering/gating: `progress-bar`,
`janus-video`, PhET, `janus-popup`, carousel. Count 33 vs 43 resolved at authoring. **Santi owns
MER-5672** — coordination before the switch commit (open question 2). Compat baseline 5.6 min.

## 5. etx-scripts spike — step 0

**Risk:** 2 graded greenhouse screens run self-grading black-box sims (rule:
`stage.<id>.Correct equal true`); drive method unknown.

Plan, increasing cost: (1) static — fetch the sims' JS from widget src URLs, read the CAPI
variable surface, diff graded vs ungraded configs; (2) one manual live run — interact by hand
until `Correct: true` appears in a PATCH save on the wire; (3) scripted drive attempt,
wire-verified.

**Exit criteria** (design-pass blocker 9 — hardened):

- **Success** = both graded instances driven *mechanically* (no human in the loop),
  wire-verified (`Correct: true` in state, evaluation verdict true), **repeatable — 2
  consecutive scripted successes** within the approved run budget.
- **Failure** = anything less. On failure, **implementation of the greenhouse migration halts**
  and the human amends the framework goal explicitly — options prepared (exclude-with-weaker-
  contract, upstream fix request, drop greenhouse from this ticket), but none is a silent default:
  each contradicts "strict migration + compat deletion" as stated, so the goal statement itself
  must change. The refactor and the LotE/d-orbitals migrations are NOT gated on this.

Output: `etx-scripts-spike.md`. Timebox one session; live-run budget = open question 4.

## 6. Drive work list (write-drive-verify loop per family)

Loop per new family: registry entry → live screen → PATCH save on the wire shows the expected
state key → evaluation `partInputs` carries it → `actions.correct: true`. UI appearance is never
evidence. Two consecutive successes before the family's map entries are trusted.

| Family | Lessons | Derive (done, §3g) | Drive risk |
|---|---|---|---|
| `etx-scripts` sims | GH 2 graded | rule only | **highest — spike, §5** |
| `janus-fill-blanks` (shadow DOM) | GH 7, dOrb 3 | `custom.elements[].{key, correct, options[]}` | **high** — never driven, highest volume |
| `drag-and-drop-component` (S3) | dOrb 2 | rule + `CorrectRelations` | high — third DnD flavor |
| gates climate sim | GH 1 graded | change `Sim.Params.*.Abundance` | medium |
| `grouping` v1 / `order-list` v5 | GH 1 each | config | medium — existing untested code moves |
| `flashcard` (gating) | dOrb 1 | `All Modified equal true` | medium |
| `janus-dropdown` | GH 10 | rule `selectedIndex equal N` | low |
| `matching` v2 | GH 1 | same schema as LotE's verified | low |
| `janus-input-text` | GH 1, dOrb 1 | length constraints | low |
| carousel / `janus-image-carousel` (gating) | GH / dOrb | `Viewed Images Count` | low — assert the count |
| `janus-video` (gating) | dOrb 1 | `hasStarted` | low |
| `janus-navigation-button` | GH | non-answering | low |
| `progress-bar`, `janus-popup`, PhET | GH, dOrb | non-answering confirmed | none |

## 7. Implementation order (each step = proposed commit(s), human gates every one)

0. **etx spike** (§5) — doc output. Gates only the greenhouse migration.
1. **Journal + attribution** — modules + stub tests, **plus passive shadow capture**: journal
   armed during current-code LotE strict runs. Captured raw journals contain answer values —
   **private and ephemeral** (scratchpad/bucket, never repository fixtures; repo tests use
   synthetic journals only). No behaviour change.
2. **Planner + permits + oracle + reporter** — `auditRun` over synthetic AND captured journals;
   port all 64 stub negatives; add new ones (edge-less evaluation, split-rotation navigation
   sequences, savedBarrier temporal, distinct-path `min_count`, combineFeedback derivation).
   No behaviour change.
3. **Shadow differential gate** — current LotE spec still on the old walker; journal + oracle
   run in shadow on ≥2 live runs. "Agree" is defined as a **compared projection over fields the
   shipped `LedgerEntry` actually exposes** — per screen: `(screenId sequence, role,
   evaluationCount, expectedEvaluations, folded verdict, folded payloadMatch, transition
   kind)`, where the oracle's transition folds as the shipped ledger does — the FINAL fulfilled
   plan (on a feedback re-check, the second evaluation's) — plus outcome equivalence: a
   shipped-green run must audit to zero violations, and a shipped bail must map to ≥1 violation
   from the failure-sealed journal (§3.2) naming the same screen. Per-evaluation verdicts and
   foreign/contamination counts are NOT compared — the shipped ledger folds the former and
   bails on the latter without storing them (`AdaptiveHappyPathTask.ts:183-228`); instrumenting
   the old observer to expose them is rejected — it modifies the code under replacement for
   throwaway value, and the folded fields plus zero-violation equivalence carry the same
   signal. Differences must be on the
   **intentional-delta list**: pre-entry traffic (invisible to the observer; must be present in
   the journal AND legal under the §3.4 navigation sequence rule — its absence FAILS the gate,
   it does not pass it), and provenance strictness differences from the per-screen ancestor
   whitelist (each occurrence explained, none auto-accepted). **Mandatory live evidence:** the
   Cover pre-entry sequence, the mint chain, save-barrier saves, the combineFeedback screens'
   derivations, the page-lifecycle finalization, **and ≥1 deliberate shipped-bail run**
   (poisoned answer; the old walker bails, the sealed journal must audit to a same-screen
   violation — without this the gate exercises only green outcomes). **Harness-injected
   evidence** (not required live): delayed duplicates, post-freeze arrivals, unresolved
   evaluation candidates, and seal races (traffic starting after the zero-pending observation;
   arrivals between seal, audit, and detach). Any unexplained divergence = stop
   before any seam is removed (design-pass blocker 7). No behaviour change.
3-bis. **Review gate B0 (amendment, human-approved 2026-08-09, round-1 SF3):** narrow
   cross-model review of the step-3 shadow evidence — the equivalence projection, the
   intentional-delta occurrences, and the bail-run mapping — BEFORE step 4 consumes it. The
   equivalence evidence is independently reviewed before it governs the replacement driver.
4. **Registry + new driver as a parallel entry point** (old strict walker untouched) + LotE
   manifest v2 (provides the family+version metadata the registry keys on) + **LotE spec
   switched** — canary + 3× runs. First behaviour change. Old strict walker deleted once green.
5. **Author + statically validate d-orbitals AND greenhouse manifests** (before family work:
   resolves 30-vs-34 / 33-vs-43, cross-screen owners, full family inventory; specs stay on
   compat) — design-pass should-fix 2.
6. **New registry entries** (§6), one commit per family/group, each with its wire evidence.
6-bis. **Checkpoint C1 (amendment, human-approved 2026-08-09, round-1 SF3):** cross-model
   review of the validated manifests + registry entries BEFORE either migration consumes
   them — manifest/registry defects must not compound across both migrations.
7. **d-orbitals migration** — canary + 3× runs.
8. **Greenhouse migration** (Santi coordination; etx per spike outcome) — canary + 3× runs.
   Checkpoint C2 follows this step (the former checkpoint C).
9. **Delete compat path** — `completeAdaptiveHappyPath`, `LessonAnswers`, heuristic
   `scanScreen` (grep-verified: only the two migrated specs import them today).
10. **Docs** — skill matrix updates, CHANGELOG, this spec's outcome record.

## 8. Verification

- **Shadow differential gate** (step 3) is the refactor's equivalence evidence — synthetic
  tests alone don't prove the journal reproduces live evidence.
- **Test harness requirement** (R4-SF1): the fake deck fires genuinely async responses and
  late traffic; `settle()` covered with in-flight and post-zero-check arrivals.
- **Deterministic contract matrices** (pass 6 blocker 3) — each v6/v7 contract gets an
  exhaustive stub matrix, mutation-style (every branch provably reject- and accept-tested):
  finalization acceptance (each correlation field wrong × each outcome × `already_submitted`);
  committed-prior-state lineage (later save, later attempt mint, mutation committing inside
  the request→response window, wrong-lineage state); every seal/window state in the §3.2
  matrix including `seal_incomplete`; navigate-off-sequence qualifiers (each disqualifying
  target, successor-exists); bijection failures (screen missing from map, from scenario, from
  both, unclassified exclusion); typed driver-operation failures (every union member → its
  violation, including `identity-unresolved`'s expected-step attribution); completed-failure
  freeze lifecycle (each reason × terminalization of a response-less finalization ×
  post-freeze immutability); seal-boundary membership (pre-cutoff request completed during
  sealing retained vs post-cutoff request marker excluded); the full predicate matrix (every
  operator accept + reject, unknown operator, type-invalid argument, both `selectedChoices`
  encodings); redaction non-leakage (a raw journal with known answer values → emitted report
  provably contains none of them); multi-part cross-screen dependency (per-part_id newest
  selection vs a single-newest-row mistake); the combined freeze STATE MACHINE (accepted and
  completed-failure flavors × ordering violations × persistent-mode terminalization arrivals);
  request-time classification precedence (each record kind × each mismatched row);
  operation-reference validation (duplicate id, dangling ref, cross-screen ref, default
  expansion); combineFeedback selection (all four §3.5 branches); entry-stamp fencing (request
  before vs after the identity-read fence); underdeclared cross-screen expectations (rule
  reference with no matching expectation → build failure).
- **Explicit coverage list** (R4-SF2 + design pass): end-to-end LLM-feedback plan, savedBarrier
  temporal audit, mixed-prefix contamination, multi-part ownership per family, duplicate-label
  distinct-path `min_count`, pre-entry navigation sequences (accept + reject + split-rotation
  bypass attempt), planner/oracle
  replay agreement.
- Per lesson: canary + 3 consecutive fresh-seed green runs, traces retained.
- Per family: wire evidence ×2 before its map entries are trusted.
- tsc/eslint/prettier scoped to diff files; 2 known pre-existing liveSocket tsc errors excluded.
- Baselines recorded, not targeted: LotE 4.5–4.8, dOrb 4.8, GH 5.6 min.

## 9. Hard constraints carried

- Human authorises every commit; single-line subjects, no body, no Co-Authored-By; ticket
  number before commit 1.
- **`AutomationSetupTask.ts` and `AdaptiveLessonTask.ts` untouched** (PRs #6750/#6752, both
  OPEN, re-verified 2026-08-03; #6752 rewrites the latter).
- Keys/archives never in the repo; redaction by construction everywhere.
- Stash stack holds old entries — never `stash pop` blind.

## 10. Open questions

| # | Question | For |
|---|---|---|
| 1 | ~~MER ticket number for this work~~ **Resolved 2026-08-05: MER-5865** | human, before commit 1 |
| 2 | Santi coordination for the greenhouse switch — who raises it, does his QA-stage ticket constrain timing? | human |
| 3 | Bucket key policy: overwrite `answers.json` or side-by-side `answers-strict.json` until each switch commit (side-by-side proposed — keeps every commit runnable) | human (cheap) |
| 4 | Spike + shadow-run budget (each seeded run leaks a project, TRIAGE-2419) | human |

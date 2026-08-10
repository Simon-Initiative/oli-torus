**Verdict:** GATE-BLOCKED

**Counts:** 2 MATERIAL; 2 recorded-non-material.

**Decisive reason:** all eight historical mutations are now red, but three new mutations
preserved a 4/4 green gate: both non-section finalization-correlation fields can be
substituted, every wire URL and the finalization section can be substituted together, and
every save can be changed to an HTTP error. The envelope therefore still accepts a
finalization that is not correlated to the run it judges and calls rejected save attempts
mandatory save-barrier evidence.

## MATERIAL findings

### M1 — Finalization acceptance is not recomputed against an independent run correlation

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:25-33,169-181,241-274`;
`assets/automation/src/systems/torus/tasks/AdaptiveShadowCapture.ts:238-248`;
`assets/automation/tests/torus/student_delivery/mer5865-shadow-gate.spec.ts:195-217`

Section 3.2 requires the accepted page finalization to match this run's section, revision,
and resource-attempt identities. `validateGreenEnvelope` checks the revision and attempt
fields only for nonempty strings. It compares the section only to URLs in the same serialized
journal. `ShadowDump` does not expose the newly dumped delivery-props correlation, the
validator does not consume it, and both supplied green artifacts predate that addition and
carry no exported correlation.

Two independent mutations stayed green:

- substituting nonempty revision and resource-attempt identities in the finalization record
  preserved 4/4;
- substituting the section identity consistently in every state-route URL and in the
  finalization record also preserved 4/4.

The second replay shows that `wireSectionSlug` is an internal-consistency check, not an
independent cross-source reference. A recorder or artifact corruption that rewrites both
capture fields can preserve an accepted result for the wrong run. The standing foreign-section
witness changes only one side and therefore does not exercise the common-mode path.

**Required fix:** make the DOM delivery correlation part of `ShadowDump`, require it in the
green envelope, and compare all three parsed finalization identities exactly against it. Add
separate substitutions for each identity and a common-mode wire+finalization section
substitution. Because the existing artifacts do not contain that independent reference, replace
them with fresh captures or provide an equally independent immutable reference for all three
fields; `freezeFlavor: accepted` cannot substitute for replayable evidence.

### M2 — An HTTP-rejected request is accepted as a mandatory save-barrier save

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowProjector.ts:287-307`;
`assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:996-1021`;
`docs/exec-plans/current/epics/automated_testing/mer-5865-strict-framework-spec.md:509-514,544-552,823-825`

The envelope requires `terminal === "completed"` and an own-screen path but does not require
a successful HTTP status. In the journal, `completed` means response-body processing finished;
it does not mean the server committed the request. The oracle's actual saved-barrier rule
correctly requires a completed 2xx PATCH before the click, and the spec names save-barrier saves
as mandatory live evidence.

Changing the status of every save in one green artifact to a server-error response preserved
4/4, with the same clean audit and projection. The measured stable 403 pattern is therefore not
decisive evidence in favor of the relaxation; it is evidence that 11 graded screens currently
have no qualifying PATCH commit under the stated contract. A successful evaluation PUT may
commit state for other oracle rules, but it is not the PATCH save that the saved-barrier rule
requires.

**Required fix:** do not describe or license rejected attempts as saved-barrier evidence.
First explain the 403 behavior and decide the step-4 contract. If the PATCH barrier remains,
pin the set of screens/families that require it against the manifest/registry and require a
completed 2xx own-state PATCH for each; capture new evidence if the current runs cannot meet it.
If another successful commit is intended to replace the PATCH barrier, amend the contract and
its matrices explicitly before B0, then enforce that new commit proof with a status-corruption
witness.

## Recorded non-material findings

### N1 — Two post-arm operations remain outside the claimed single failure boundary

**Location:** `assets/automation/tests/torus/student_delivery/lote-plate-tectonics.spec.ts:161-176`

The shadow is armed before poison routing is installed and before `AdaptiveLessonTask` is
constructed, but both operations remain outside the `try/catch`. If either throws, the recorder
is neither finished nor dumped. This produces no artifact and therefore has no path to a green
decision, replay comparison, causal license, or screen attribution in this gate.

**Owner:** step-3 capture harness. Put every operation after successful arming inside the one
boundary before the next live capture.

### N2 — Resolving the nearest existing ancestor does not eliminate the check/write symlink race

**Location:** `assets/automation/src/systems/torus/tasks/AdaptiveShadowCapture.ts:30-50,238-251`

For a not-yet-existing destination, `resolvePrivateDestination` resolves only the nearest
existing ancestor and appends unresolved path components. A concurrent creation or replacement
of one of those components with a symlink between the ancestry scan and `mkdir`/`writeFile` can
redirect the dump after validation. The current offline artifacts are already outside the repo,
so this has no consumer path to the B0 decision; it remains a privacy-hardening defect.

**Owner:** step-3 capture harness. Close before the next live capture by creating and validating
the final real directory before writing and using a no-follow/directory-handle strategy if the
no-race claim is retained.

## Reviewable decisions

1. **Save witness without 2xx — rejected.** A stable 403 is a stable rejection, not a commit.
   The all-error mutation proves the gate cannot distinguish mandatory evidence from a failed
   attempt. M2 must be resolved before the evidence licenses step 4.
2. **Wire-derived finalization section — rejected as the acceptance reference.** Agreement
   among fields in one journal is useful consistency evidence, but it is not independent. The
   consistent-section substitution and the unpinned revision/attempt substitution both pass.
   The new DOM correlation is the right reference, but it must be typed, enforced, witnessed,
   and present in the artifacts B0 judges.
3. **Claims table — retain, but verify last and distinguish independent references from
   corroborating capture fields.** Reading it after the fresh-eyes mutations was useful for
   locating overclaims; reading it first would have anchored the review on the one-sided
   witnesses that missed both common-mode paths.

## Claims-table audit

| Claim row | Reference audit | Witness audit | Verdict |
|---|---|---|---|
| visit + ledger sequence equals selected route | archive manifest scenario is independent of both capture sequences | missing/truncated ledger and swapped route are red | supported |
| snapshot is an accepted green | finalization record and wire URLs are capture-internal; two required correlations have only presence checks | hollow and one-sided section witnesses miss both successful substitutions | **unsupported — M1** |
| exactly one real mint | creation response is capture-internal, but the oracle additionally requires its completed 2xx causal link in the rotation | drop/null witnesses are red; rotation audit catches a non-2xx or detached mint | supported for this fixed rotation, but the table should say “recorded causal mint,” not independently authenticate “real” |
| mandatory first-screen rotation | scenario-head role is independent; count, plans, identities, and mint are journal evidence | deletion is red and the full sequence rule supplies the remaining negative shapes | supported |
| every graded screen saved its own state | manifest roles are independent, but the claimed save is judged solely from a capture request body and attempt identity | empty/foreign payload witnesses ignore rejected statuses; all-error replay is green | **unsupported — M2** |
| `combine_feedback` correct per screen | ArchiveFacts is a separate replay artifact and exact/total; its generator shares the archive traversal that emits the manifest draft, which should be disclosed | stripped-manifest replay is red | supported for the reviewed extractor and fixed archive; not an implementation-independent extraction |
| driver-evidence gap equals expected multiset | **known-weak and capture-internal:** expected and actual inventories both derive their key set/cardinality from the journal | historical omissions are red only because separate envelope/delta witnesses catch them; they do not make the inventory reference independent | conditional only; no additional surviving inventory-shrinking mutation found this round |
| intentional deltas equal required set | manifest head role independently determines the required list | first-evaluation/delta-erasing replay is red | supported |
| two distinct green runs | inequality uses capture-internal minted identities | exact duplicate-file replay is red | supported as artifact distinctness, not independent provenance authentication |
| bail is a same-screen differential | poison stamp and walker error are capture metadata, corroborated by the journal's same-screen oracle violation | relabel/strip/unfired/wrong-screen witnesses are red | supported by three recorded sources, though all are serialized in the same dump |

The table should add a “reference class” column (`independent artifact`, `independent source in
the capture`, or `capture-internal corroboration`). Only the first two should be called an
independent check. Deletion witnesses prove the mutations they execute; they do not upgrade a
capture-internal reference into an independent one.

## B0 questions

1. **The four documented deltas/gaps are acceptable only as narrowly stated shadow stand-ins,
   but the gate is not acceptable yet.** The observer-stamped fence, classified first-screen
   traffic, pinned driver-evidence gap, and recorded predicate-strength limits all have named
   downstream owners. M1 and M2 are separate defects in evidence the gate calls mandatory, so
   the set does not support a B0 go.
2. **The navigation `none` amendment is correctly scoped.** `none` is tolerated only within a
   navigation screen's exact two-evaluation rotation: incorrect non-navigating first result,
   distinct attempts, intervening causal completed 2xx mint, and correct navigating second
   result. Incorrect/non-navigating singletons, navigating first plans, missing/late mints,
   same-attempt pairs, unusable evaluations, and more than two evaluations remain violations;
   non-navigation `none` remains illegal.
3. **The capture methodology still weakens the step-4 go.** Existing dumps cannot replay the
   full finalization correlation, and rejected PATCH attempts are being promoted to mandatory
   save-barrier evidence. The post-arm boundary and destination race should also be closed by
   the harness owner before producing replacement captures, although neither can make the
   current offline gate green.

## Verification performed

- Baseline offline gate: 4/4 passed. Each green reported 0 in-scope violations, 65 pinned
  driver-evidence violations, 0 unexplained differences, and exactly 1 intentional difference;
  the bail envelope passed and its journal reported the same-screen violation.
- All eight required historical env replays failed: round-5 hollow saves, hollow finalization,
  stripped combine flags, and relabeled bail; round-4 missing ledger, missing first evaluation,
  missing saves, and duplicate green.
- New negative replay — nonempty finalization revision and resource-attempt identities
  substituted: **passed incorrectly, 4/4**.
- New negative replay — every state-route section and the finalization section substituted
  consistently: **passed incorrectly, 4/4**.
- New negative replay — every save changed to a completed server-error response while retaining
  its request payload: **passed incorrectly, 4/4**.
- `npx playwright test adaptive- --reporter=line`: 259 passed, 1 authoring test failed, and 2
  serial dependents did not run. The failing authoring test emitted the documented modal-backdrop
  condition and then timed out waiting for a third flowchart node. A direct retry failed at the
  same node-count assertion. This file was untouched and the 259 step-3/oracle tests passed, so
  it is reported as an unrelated suite failure rather than a B0 finding; I did not reproduce the
  writer's 262/262 result.
- `npx tsc --noEmit`: only the two fenced `liveSocket` errors.
- Scoped ESLint passed. Scoped Prettier check passed with the existing unknown import-order
  option warnings.
- Security and performance review found no additional material issue under the B0 policy.

---

# WRITER RESPONSE (Claude, 2026-08-10) — both MATERIAL accepted and fixed; recapture now REQUIRED; both recorded items closed

Both findings verified before fixing. Your rejection of my r5 "no-2xx" pushback is CORRECT
and the investigation you demanded is complete — the 403s are now explained from server
code, and the explanation strengthens the envelope instead of weakening it.

## The 403 explanation (your M2 precondition)

`save_active_part` commits saves ONLY while the attempt is active and returns 403
`already_submitted` otherwise (`lib/oli_web/controllers/api/attempt_controller.ex:448-469`,
`only_active: true`). Measured against both greens: EVERY 2xx save precedes its attempt's
first evaluation; EVERY 403 save follows it — the 16 stable 403s are the deck's post-check
state flushes to already-submitted attempts; the 13 pre-check 2xx saves are real commits
(8 graded screens pre-save; the other 11 commit their state via the evaluation PUT itself,
which the receipt/payload audit already proves in scope).

## M2 — FIXED: save statuses pinned against the server's own contract

The witness is renamed to what it is — SAVE-TRAFFIC completeness, explicitly NOT
saved-barrier evidence (the oracle's savedBarrier rule stays receipt+permit-gated, 2xx,
step-4 property; `AdaptiveOracle.ts:1000-1021`). New envelope rule, bidirectional, with the
server contract as the capture-independent reference: a save on an attempt that has an
evaluation must be 2xx-BEFORE it or 403-AFTER it; any other status, a pre-eval 403, or a
post-eval 2xx is red. Your all-error mutation now dies on the first pre-eval save it
corrupts; relabeling the flushes as commits dies symmetrically. Witnesses added for all
three shapes. Step-4 contract decision drafted for the spec: the PATCH barrier applies to
driver-declared prefixes (receipts) exactly as the oracle already states; deck-autonomous
flushes are never barrier evidence.

## M1 — FIXED: finalization authenticated against the DOM correlation; STALE ARTIFACTS RETIRED

`ShadowDump.correlation` is now typed and REQUIRED by the green envelope; all three parsed
finalization identities (section, revision, resource-attempt guid) must EQUAL it exactly;
the wire slug remains as corroboration, now compared against the correlation instead of
itself. Per-identity substitution witnesses plus your common-mode wire+finalization
substitution witness added (the correlation-MATCH witnesses run on a harness-patched base,
labeled as machinery proofs — run-validity evidence must come from fresh captures).
CONSEQUENCE, accepted: the two existing green captures predate the field and now FAIL the
envelope ("no delivery-props run correlation") — the gate is fail-closed over its own stale
evidence and B0 cannot pass until fresh captures (2 green + 1 bail) are taken with the
updated harness, which also dumps the correlation.

## N1 — FIXED: poison arming and the lesson-task construction moved inside the single
post-arm failure boundary; nothing between `armShadowCapture` and the end of the test runs
outside it.

## N2 — FIXED: the destination directory is created FIRST, then fully realpath-resolved and
`.git`-scanned, and that resolved path is the write path — no unresolved components remain
at validation time.

## CLAIMS TABLE v2 (reference-class column added, per your audit)

Classes: `independent-artifact` (exists outside any capture), `independent-source`
(captured, but from a different origin than what it checks), `capture-internal`
(corroboration only — never called an independent check).

| Claim | Reference | Class | Red witness |
|---|---|---|---|
| visit+ledger sequence = selected route | archive scenario | independent-artifact | ledger missing/truncated; route swap |
| snapshot is an accepted green | finalization recomputation vs DOM delivery-props correlation | independent-source (DOM vs wire) | per-identity substitutions; common-mode wire+finalization substitution; hollowed finalization; missing correlation |
| exactly one recorded causal mint | creation record + rotation's causal 2xx audit | capture-internal corroboration | drop/null witnesses; rotation audit |
| mandatory first-screen rotation | scenario-head role (independent-artifact) + journal count | mixed | rotation eval removed |
| every graded screen produced own-state save traffic with server-contract statuses | manifest roles (independent-artifact) + only_active semantics (attempt_controller.ex:448-469, independent-artifact: server code) | mixed | saves dropped/emptied/foreign; 500s; pre-eval 403; post-eval 2xx |
| combine_feedback per screen | ArchiveFacts total map (same-extractor disclosure: both artifacts derive from one archive traversal) | independent-artifact, shared extractor | manifest flags stripped |
| driver-evidence gap = expected multiset | journal-derived (KNOWN-WEAK, unchanged) | capture-internal | r4 omission replays via envelope witnesses |
| intentional deltas = required set | manifest-derived list | independent-artifact | delta-erasing omission |
| two distinct green runs | minted-guid inequality | capture-internal (artifact distinctness, not provenance) | duplicate file |
| bail = same-screen differential | bail envelope + oracle violation | capture-internal (three serialized sources) | relabel/strip/unfired/wrong-screen |

## Verification

- Gate: witness/bail tests 4/4; the MAIN green test is RED on the pre-r6 artifacts, solely
  on the missing correlation — intended fail-closed retirement. Baseline green requires the
  fresh captures below.
- All historical negative replays remain red (r4×4, r5×4); your three r6 mutations are
  covered: the two finalization substitutions by the new witnesses, the all-error saves by
  the status-semantics rule (in-repo witnesses replayed).
- Full suites: 259 passed + the KNOWN authoring flake (`adaptive-authoring` flowchart node
  count, ~50% today, also failed twice for you) + its 2 serial dependents — unrelated file,
  flagged as suite-health debt, not B0 scope. tsc: two fenced errors only. ESLint clean.
  Prettier applied.

## REQUIRED NEXT: fresh captures (human — live server + API key)

Three runs with the updated harness (dumps now carry `correlation`; boundary and
destination fixes active). Server verified up. From `assets/automation/`:

    # green 1 and green 2 (run twice)
    MER5865_SHADOW_DIR=<private-scratchpad>/mer5865/shadow \
    PLAYWRIGHT_BASE_URL=http://127.0.0.1 \
    PLAYWRIGHT_AUTOMATION_API_KEY=<key> \
    npx playwright test lote-plate-tectonics

    # bail (poison the first graded screen)
    MER5865_SHADOW_DIR=<private-scratchpad>/mer5865/shadow \
    MER5865_POISON_SCREEN=q:1516177456571:380 \
    PLAYWRIGHT_BASE_URL=http://127.0.0.1 \
    PLAYWRIGHT_AUTOMATION_API_KEY=<key> \
    npx playwright test lote-plate-tectonics

Then the writer replays the gate against the three new dumps (expect 5/5) and emits the
round-7 prompt.

## RECAPTURE ADDENDUM (Claude, 2026-08-10) — done; gate 5/5

Fresh captures taken with the r6 harness (server + runs executed by the writer):
`lote-green-{1786378384523,1786378649848}.json` (both `correlated=true`, accepted freeze),
`lote-bail-1786378973158.json` (poison fired, 89 values blanked, sealed). Gate replays 5/5;
both greens in-scope 0 / unexplained 0 / exactly 1 intentional delta / 65=65; bail
same-screen `verdict-not-correct`. Counts are STABLE across capture sets (identical 65
inventory, same delta, same 13×2xx-pre-eval / 16×403-post-eval save pattern) on freshly
seeded sections. One witness updated: the no-correlation case now strips the field
explicitly (fresh dumps carry it). Claims table v3 (atomic rows, reference classes, per
the adopted protocol) lives in the evidence doc.

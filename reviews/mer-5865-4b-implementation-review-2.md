# MER-5865 unit 4b implementation re-review — raw archive reader + predicate equivalence gates

## Blocker

1. **The stringified B4-PRED leg bypasses the product state-assignment pipeline and feeds the engine a fact representation that this MCQ path does not produce**

   `assets/automation/src/systems/torus/tasks/AdaptivePredicateEquivalence.ts:176`
   `assets/automation/src/systems/torus/tasks/AdaptivePredicateEquivalence.ts:241`
   `assets/automation/src/systems/torus/tasks/AdaptivePredicateEquivalence.ts:243`
   `assets/src/adaptivity/rules-engine.ts:483`
   `assets/src/adaptivity/rules-engine.ts:496`
   `assets/src/adaptivity/capi.ts:55`
   `assets/src/adaptivity/scripting.ts:253`

   `mcqStates` now emits `"[1,2]"`, but `archiveVerdict` passes that string directly to
   `Engine.run`. The product does not: `check()` first runs `evalAssignScript`, whose type inference
   recognizes a bracketed string as `CapiVariableTypes.ARRAY`; the array branch then `parseArray`s
   it before `env.toObj()` supplies facts to `Engine.run`. For the generated numeric MCQ values,
   the product engine therefore receives `[1, 2]`, not `"[1,2]"`.

   This is not merely an extra conservative state. The added leg is supposed to prove the measured
   string-on-input path, but it bypasses the preprocessing that converts that input into the actual
   rule-engine fact. A defect or semantic change in assignment/type inference can alter the live
   fact while this gate remains green because it continues to hand the original string directly to
   the operator modules. The file's stated preprocessing bound covers condition values only; it
   does not close this fact-preprocessing seam. Drive each enumerated input through the product's
   assignment path before the archive engine runs (while keeping the manifest matcher on the raw
   measured representation), or add an independently corroborated preprocessing leg that proves
   the exact engine fact produced from each encoding.

## Should-fix

1. **Malformed cap overrides bypass both cap checks**

   `assets/automation/src/systems/torus/tasks/AdaptivePredicateEquivalence.ts:211`
   `assets/automation/src/systems/torus/tasks/AdaptivePredicateEquivalence.ts:218`
   `assets/automation/src/systems/torus/tasks/AdaptivePredicateEquivalence.ts:335`
   `assets/automation/src/systems/torus/tasks/AdaptivePredicateEquivalence.ts:337`

   The default path now checks the correct bound before allocation: radio is
   `2 * (choiceCount + 1)`, checkboxes is `2 * 2^choiceCount`, and the later assertion uses the
   same 4,096 default. However, both exported APIs accept any JavaScript `number` as `maxStates`.
   `Number.NaN` makes both `>` comparisons false, and `Infinity` permits an arbitrarily large
   allocation. The current private gate does not override the default, so this is not a present
   B4-PRED false green, but it leaves a public path that can allocate before any effective bound.
   Require a finite positive integer in both entry points before deriving or inspecting the state
   collection, and add NaN/Infinity rejection cases.

2. **The new MCQ mode check is not regression-locked on the no-`part_id` ownership branch**

   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:87`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:93`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:102`
   `assets/automation/tests/torus/student_delivery/mer5865-archive-gates.spec.ts:720`
   `assets/automation/tests/torus/student_delivery/mer5865-archive-gates.spec.ts:730`

   The implementation correctly invokes `assertModeMatchesArchive` after both named ownership and
   unique-candidate inference. The only negative witness, however, keeps `part_id: "Pick"`, as do
   the positive fixtures. Removing the call on line 102 leaves the complete reviewed suite green,
   even though a valid directive that relies on the registry's single-candidate ownership path can
   then declare the wrong mode. Add a unique-MCQ directive without `part_id` and mutate its mode;
   a radio-archive/checkbox-manifest case would also lock the reverse data shape requested in the
   first review.

3. **Two gate-kind mappings and the ambiguity/unknown rejection branches have no build-gate witnesses**

   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:39`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:41`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:42`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:165`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:167`
   `assets/automation/tests/torus/student_delivery/mer5865-archive-gates.spec.ts:736`

   The mappings themselves are correct against the registered product elements:
   `janus-image-carousel`, `janus-flashcards`, and `janus-video`; unknown kinds also fail, and the
   exact-one check correctly rejects ambiguity. But the additive suite exercises only a missing
   `carousel_view` control. Deleting or changing the flashcard/video rows, or weakening
   `owned.length !== 1` to a presence check, is not killed by this suite. Add positive plus
   absent/ambiguous cases for all three kinds and a direct invalid-kind case (post-validation
   mutation is sufficient to reach the defensive unknown branch).

## Nit

None.

## Prior-finding discharge audit

- **B1 role not archive-corroborated — DISCHARGED.** `deriveScreenRole` gives navigation precedence for both measured navigation shapes, otherwise derives graded from an enabled correct rule's `stage.*` fact, otherwise content, and `validateArchiveCoverage` compares that result for every screen.
- **B2 MCQ mode not archive-corroborated — DISCHARGED.** `mcqPartSpec` owns mode from `multipleSelection`, and `assertModeMatchesArchive` compares it after both named and inferred ownership paths; the missing branch witness is the separate should-fix above.
- **B3 B4-PRED witness optional/caller-selected — DISCHARGED.** The screen and part are fixed to `q:1516197466626:752` / `Metacognition`; once the private-artifact suite is active, absent archive screen, manifest screen, part, wrong part type, or mismatched expectation fails rather than skipping or selecting another MCQ.
- **B4 stringified `selectedChoices` omitted — DISCHARGED AS STATED.** Every selection is now emitted in native and stringified form and counted in the preallocation bound; the replacement leg's failure to traverse product preprocessing is the new blocker above.
- **SF1 known d-orbitals/greenhouse fork refused — DISCHARGED BY RECORDED DISPOSITION.** The reader remains strictly fail-closed; it has not become worse than the accepted debt and still invents no selected route.
- **SF2 gate operations not archive-corroborated — DISCHARGED.** All closed gate kinds are mapped to their real archive part types, unknown kinds fail, and exactly one owner is required; missing mutation coverage is the separate should-fix above.
- **SF3 cap checked after allocation — DISCHARGED FOR THE CONTRACT PATH.** The archive-derived cardinality, including both encodings, is checked before `mcqStates` allocates; the malformed override hole is narrower and recorded separately above.

## Other adversarial conclusions

- Role derivation is total for every successfully parsed `RawScreen` and matches the round-2
  classifier. The two navigation identifiers are the actual measured shapes for the three lessons;
  navigation precedence is necessary because LotE Cover also carries a stage-conditioned rule.
  No known in-scope shape is silently assigned the wrong role.
- The role equality check subsumes the older gradable check for a manifest-graded screen: deriving
  `graded` requires a stage leaf under a non-empty correct-rule condition tree, so the old
  `conditions.children.length > 0` predicate necessarily holds. A session-only conditioned rule
  is intentionally `content` under the recorded classifier and fails a manifest `graded` role at
  the earlier equality check.
- MCQ mode corroboration is present on every implementation path into native ownership. CAPI
  ownership returns earlier by design and cannot resolve to either registered `janus-mcq` entry.
- The state-count arithmetic is correct for both modes, doubling composes correctly with the later
  cap, all generated states carry the same fact-key shape, and doubling does not weaken the
  discriminating or referenced-fact checks.
- The B4-PRED identity is no longer controlled by environment variables. The suite-wide skip still
  represents absence of the private artifact in ordinary repository runs; it cannot substitute a
  different witness once gate mode supplies those artifacts.
- No additional security issue was found. Archive paths are local build inputs, errors do not emit
  answer values, unknown registry/gate identifiers fail closed, and no new live authorization
  surface is involved.

## Verification

- Targeted `mer5865-archive-gates.spec.ts`: **38 passed / 2 skipped**.
- Full discovery is the writer-reported **328 tests**: 324 in student delivery plus four in course
  authoring. The first student-delivery replay produced **321 passed / 2 skipped / 1 failed** at
  the timing-sensitive `adaptive-journal.spec.ts:1022`, including a Playwright trace-artifact
  `ENOENT`; its exact isolated rerun passed **1/1**. The first authoring replay hit the contract's
  recorded `adaptive-authoring.spec.ts:133` flake; its one permitted retry passed **4/4**. Across
  those replays every executable case passed: **326 passed / 2 private-artifact skips**.
- ESLint on all requested TypeScript files: clean.
- Prettier check on all requested files: clean (with the repository's existing ignored-option
  warnings).
- `tsc --noEmit`: only the two intentionally excluded `window.liveSocket` errors in
  `CourseManagePO.ts:130` and `ProductsPO.ts:93`.

## Summary

1 blocker, 3 should-fix, 0 nits. Verdict: **BLOCKED**. All seven prior findings are discharged on
their original terms, but B4-PRED still does not prove the measured stringified-input path through
the product pipeline because its archive leg begins after—and bypasses—the relevant preprocessing.

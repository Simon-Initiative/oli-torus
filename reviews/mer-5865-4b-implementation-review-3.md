# MER-5865 unit 4b implementation re-review — round 3

## Blocker

None.

## Should-fix

1. **The round-3 preprocessing fix and its same-fact invariant are not regression-locked at the composition seam**

   `assets/automation/src/systems/torus/tasks/AdaptivePredicateEquivalence.ts:415`
   `assets/automation/src/systems/torus/tasks/AdaptivePredicateEquivalence.ts:438`
   `assets/automation/tests/torus/student_delivery/mer5865-archive-gates.spec.ts:409`
   `assets/automation/tests/torus/student_delivery/mer5865-archive-gates.spec.ts:816`

   The implementation is correct: `engineFactOf` uses the product's type inference and array
   coercion, and line 438 supplies the resulting facts to the archive engine while leaving the
   declared leg on the raw wire values. The new test, however, only calls `engineFactOf` directly.
   It does not prove that `assertPredicateEquivalence` uses the helper on its archive leg, nor does
   it exercise the rejection at lines 415–431.

   I replayed both relevant deletions. Replacing
   `archiveVerdict(screen.rules, engineFacts(state.facts))` with
   `archiveVerdict(screen.rules, state.facts)` — exactly the round-2 blocker — left the complete
   targeted spec green at **43 passed / 2 skipped**. Deleting the same-engine-fact assertion also
   left it green at **43 passed / 2 skipped**. The direct helper examples therefore protect the
   helper but not either critical use of it.

   Add an end-to-end equivalence case whose archive verdict changes if a bracketed selection is
   passed directly instead of being preprocessed, and a negative pair whose two encodings share a
   selection identity but preprocess to different facts. Those witnesses must fail on the two
   deletions above.

2. **The malformed-cap regression witness covers the generator entry point but not the checker entry point**

   `assets/automation/src/systems/torus/tasks/AdaptivePredicateEquivalence.ts:253`
   `assets/automation/src/systems/torus/tasks/AdaptivePredicateEquivalence.ts:376`
   `assets/automation/tests/torus/student_delivery/mer5865-archive-gates.spec.ts:805`

   Both implementation paths now call `requireCap` before inspecting or deriving their state
   collections, so the round-2 code defect is fixed. The test at line 805 sends NaN, Infinity and
   zero only to `mcqStatesFromArchive`; it never passes a malformed cap to
   `assertPredicateEquivalence`. Replacing line 376 with the former unvalidated
   `input.maxStates ?? DEFAULT_MAX_STATES` left the full targeted spec green at **43 passed / 2
   skipped**. Add asynchronous NaN/Infinity/zero/non-integer rejection cases for the checker entry
   point so both exported guards are independently locked.

## Nit

None.

## Round-2 finding discharge audit

- **B1 — stringified B4-PRED leg bypasses product state assignment: DISCHARGED.** For the exact generated domain, integer scalar facts remain numbers and native/bracketed numeric arrays both take the product's `getCapiType` → `parseArray` path; the archive leg receives those preprocessed facts and the declared leg intentionally receives the raw wire representation.
- **SF1 — malformed cap overrides bypass both checks: DISCHARGED.** `requireCap` rejects every non-finite/non-integer/non-positive value before either exported entry point examines or derives the state collection; the missing checker-entry witness is the separate should-fix above.
- **SF2 — no MCQ mode witness for inferred ownership/reverse shape: DISCHARGED.** The new no-`part_id` checkbox-archive/radio-manifest case kills deletion of the inferred-ownership mode check, and the radio-archive/checkbox-manifest case kills deletion of the named-ownership check.
- **SF3 — incomplete gate-kind/ambiguity/unknown witnesses: DISCHARGED.** All three real part-type mappings have positive, absent and ambiguous cases, and unknown kinds have a direct case; replayed deletion of a mapping, weakening exact-one to presence-only, and deletion of the unknown guard all turned the test red.

## Fresh-eyes conclusions

- **`engineFactOf` is faithful for every fact shape this enumerator can produce.** The generated values are integer `numberOfSelectedChoices`/`selectedChoice` scalars and flat numeric `selectedChoices` arrays or bracketed strings. Product assignment parses the scalars as numbers and applies `parseArray` to both array encodings. `shouldConvertNumbers: true` is therefore the product behavior for this numeric MCQ domain. The function would not model every possible CAPI value wrapper or arbitrary object, but none can be emitted by `mcqStatesFromArchive`, so that broader difference cannot affect B4-PRED.
- **The narrower coercion is sufficient; importing full `evalAssignScript` is not required for this bounded proof.** Its expression, object-wrapper, BOOLEAN and STRING branches are inert over the generated domain, while its NUMBER and ARRAY results are exactly the values produced here. Full assignment is therefore dominated for this unit by the narrower product-owned inference/coercion path: it adds no observable coverage over the bounded facts and would add the disclosed third TypeScript error.
- **The split proof is sound.** The archive leg must judge the fact after product assignment because that is what `Engine.run` receives; the declared leg must judge the raw request value because that is what the oracle's payload matcher receives. Keeping both encodings in the enumeration tests the manifest normalization without inventing a string-valued archive-engine state.
- **The same-engine-fact check is semantically strong enough on the contract path.** `mcqStatesFromArchive` owns the labels and emits exactly `selected=[…] (native|stringified)`, so stripping the controlled suffix groups the intended pair. Caller-controlled labels could bypass grouping, but B4-PRED supplies this generator directly and does not admit caller-selected states. A structural selection key would be more robust, but the current label derivation creates no false green in the fixed gate; its missing negative witness is covered above.
- **Cap placement and arithmetic are correct.** The generator validates the cap, derives radio as `2 * (choiceCount + 1)` and checkboxes as `2 * 2^choiceCount`, rejects the projected size, and only then constructs states. The checker validates its cap before reading `states.length` or allocating preprocessed fact maps. Doubling is reflected in the later state count and does not weaken referenced-fact or discriminating-space checks.
- **Role derivation remains total and correctly ordered for the three in-scope lesson shapes.** `janus-navigation-button` and the measured buttonwidget family take navigation precedence; otherwise an enabled correct rule reading part state derives graded; otherwise content. Navigation precedence is required for the measured Cover shape. For a manifest-graded screen, role equality subsumes the older gradable check because archive-derived `graded` necessarily implies an enabled correct rule with a non-empty condition tree; no case passes role equality and then uniquely fails the older check.
- **MCQ mode corroboration reaches every applicable ownership path.** Native named ownership and unique-candidate inference both call `assertModeMatchesArchive`; zero or ambiguous unnamed candidates fail earlier. CAPI ownership returns separately and cannot resolve to either native `janus-mcq` registry entry.
- **Gate corroboration remains fail-closed.** The three mappings match the registered product elements (`janus-image-carousel`, `janus-flashcards`, `janus-video`); zero or multiple owners fail, and an unknown gate fails before any part lookup.
- **B4-PRED's identity is unskippable once private-artifact mode is active.** The screen and part are constants (`q:1516197466626:752` / `Metacognition`), archive and manifest absence are asserted red, part absence is asserted red, and a non-MCQ or incompatible declaration fails in the subsequent archive-derived enumeration/equivalence checks. The suite-level skip only covers ordinary runs where the private artifacts are not supplied; it cannot select a substitute witness.
- **No new security issue was found.** Inputs are local build artifacts, unknown metadata fails closed, error messages disclose identities/counts rather than answer values, and this unit adds no runtime authorization surface.

## Verification

- Targeted `mer5865-archive-gates.spec.ts`: **43 passed / 2 skipped**.
- Student-delivery `adaptive-*` plus the targeted gate: **327 passed / 2 skipped**.
- `adaptive-authoring.spec.ts`: **4 passed**. Total across the requested set: **331 passed / 2 skipped**.
- ESLint on the four requested TypeScript files: clean.
- Prettier on the five requested files: clean, with the existing ignored-option warnings.
- `tsc --noEmit`: only the two intentionally excluded `window.liveSocket` errors in `CourseManagePO.ts:130` and `ProductsPO.ts:93`.
- Mutation replays: inferred-mode call deletion **killed**; named/reverse-mode call deletion **killed**; flashcard mapping deletion **killed**; exact-one weakening **killed**; unknown-kind guard deletion **killed**; archive preprocessing bypass **survived**; same-engine assertion deletion **survived**; checker cap-guard deletion **survived**. All source files were restored byte-for-byte after replay.

## Summary

**0 blockers, 2 should-fix, 0 nits. Verdict: NOT BLOCKED — fold the two regression-lock should-fixes before declaring unit 4b closed.**

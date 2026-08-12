# MER-5865 unit 4b implementation review — raw archive reader + predicate equivalence gates

## Blocker

1. **B4-BIJ never corroborates the manifest role, so changing a graded screen to content disables the graded oracle while both raw-archive gates stay green**

   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveReader.ts:442`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveReader.ts:462`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:87`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:125`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:144`
   `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:710`

   The round-2 disposition makes role an archive-derived field (navigation part → navigation;
   stage-conditioned correct rule → graded; otherwise content), but `deriveArchiveFacts` emits no
   role map. Both gates instead branch on the manifest's own `screen.role`. For example, changing
   the synthetic `s:pick` definition from `graded` to `content` while leaving its operation and
   expectations intact passes `validateAdaptiveManifest`, `validateRegistryMetadata`, and
   `validateArchiveCoverage`: the operation still resolves, the rule references remain covered,
   and the only raw “is gradable” check is skipped because it too trusts the changed manifest role.
   At runtime that change is material: `auditRun` enters its receipt/verdict/payload checks only for
   `role === 'graded'`. This is exactly a green-while-false classification seam. Derive the complete
   role map from the raw parts/rules and compare it exactly, with role-swap mutations for all three
   roles.

2. **B4-MAN accepts a radio/checkboxes registry mode that contradicts the archive**

   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveReader.ts:268`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveReader.ts:280`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:58`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:66`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:106`

   Registry mode is part of the manifest key, and the raw archive carries the authoritative MCQ
   mode in `custom.multipleSelection`; `mcqPartSpec` already reads it. However, the native-family
   ownership check only compares `partTypes` and optional `part_id`. Both `janus-mcq@1:radio` and
   `janus-mcq@1:checkboxes` therefore corroborate the same `janus-mcq` part regardless of the raw
   flag. A manifest can switch mode (and reshape the directive so that its selected validator
   accepts it) while the archive is unchanged, and B4-MAN stays green even though the registry
   entry will drive and read back the wrong interaction contract. Compare every archive-declarable
   key component, including MCQ mode, and add both mode-direction mutations.

3. **The B4-PRED witness is optional and caller-selected instead of being bound to the contract's one required screen**

   `assets/automation/tests/torus/student_delivery/mer5865-archive-gates.spec.ts:689`
   `assets/automation/tests/torus/student_delivery/mer5865-archive-gates.spec.ts:712`
   `assets/automation/tests/torus/student_delivery/mer5865-archive-gates.spec.ts:713`
   `assets/automation/tests/torus/student_delivery/mer5865-archive-gates.spec.ts:718`
   `docs/exec-plans/current/epics/automated_testing/mer-5865-step4-driver-swap-contract.md:18`
   `docs/exec-plans/current/epics/automated_testing/mer-5865-step4-driver-swap-contract.md:251`

   Section 6.3 fixes B4-PRED to `q:1516197466626:752` (“Reflect”), and the top-level predicate says
   a missing or unexecuted conjunct is red. The test instead trusts `MER5865_PRED_SCREEN` and
   `MER5865_PRED_PART` without checking either identity; when they are absent it skips, and when
   they name any other convenient MCQ it proves that screen and reports B4-PRED green. Thus the
   required divergent-rule screen can remain completely untested while the named gate passes.
   Bind the witness to the contract identity (and its archive-owned part) and make absence/mismatch
   red in gate mode; an unrelated-screen and missing-variable mutation must kill the gate.

4. **The “exhaustive” MCQ space omits the explicitly required stringified-array encoding**

   `assets/automation/src/systems/torus/tasks/AdaptivePredicateEquivalence.ts:221`
   `assets/automation/src/systems/torus/tasks/AdaptivePredicateEquivalence.ts:224`
   `assets/automation/src/systems/torus/tasks/AdaptivePredicateEquivalence.ts:231`
   `docs/exec-plans/current/epics/automated_testing/mer-5865-strict-framework-spec.md:724`

   The strict spec fixes `selectedChoices` normalization over both measured representations:
   native lists and stringified arrays such as `"[1,2,3]"`. `mcqStates` emits only a native
   `number[]` for every subset. The production operators have representation-sensitive branches
   (`Array.isArray`/array-literal parsing), as does the committed mirror, so agreement over native
   lists does not prove agreement over the second product representation. A regression confined to
   stringified submissions would leave every current state green. Enumerate both encodings for each
   selection (with the same count fact), and include a mutation that changes only the stringified
   leg's truth condition.

## Should-fix

1. **The reader deliberately rejects the known d-orbitals and greenhouse route shape**

   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveReader.ts:319`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveReader.ts:333`
   `assets/automation/tests/torus/student_delivery/mer5865-archive-gates.spec.ts:334`
   `docs/exec-plans/current/epics/automated_testing/mer-5865-strict-framework-spec.md:750`

   `routeSuccessors` requires every enabled correct rule on a screen to have one
   answer-independent target, and the synthetic test permanently specifies rejection when correct
   rules differ. Section 3.8 records that d-orbitals and greenhouse both fork at the title on
   session state, with the fresh-seed route taking one fixed branch. Consequently this reader cannot
   produce B4-BIJ facts for two of the three lessons it is intended to support at steps 5–8. This is
   fail-closed rather than a false green, so it does not weaken LotE's present proof, but the route
   derivation needs a separately corroborated selected-route input before those manifests can be
   statically validated; the current “refusal” test should not stand as the final contract for the
   known lessons.

2. **Raw coverage ignores all gate operations, allowing future manifests to name controls the archive does not render**

   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:21`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:87`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:125`
   `assets/automation/src/systems/torus/tasks/AdaptiveArchiveGates.ts:128`

   `answerOperations` discards `kind: 'gate'`, and `validateArchiveCoverage` adds raw-part checks
   only for navigation actions plus a generic conditioned-rule check for graded screens. A
   `carousel_view`, `flashcard_flip_all`, or `video_start` operation therefore passes B4-MAN/B4-BIJ
   on a screen with no corresponding archive part. These operations are specifically required by
   the d-orbitals/greenhouse manifests, so this would let the map claim a nonexistent control until
   the later live driver fails. Corroborate every gate kind against an unambiguous owning raw part
   and add absent/wrong-screen/ambiguous mutations.

3. **The state cap is checked only after the full power set has already been allocated**

   `assets/automation/src/systems/torus/tasks/AdaptivePredicateEquivalence.ts:236`
   `assets/automation/src/systems/torus/tasks/AdaptivePredicateEquivalence.ts:243`
   `assets/automation/src/systems/torus/tasks/AdaptivePredicateEquivalence.ts:306`
   `assets/automation/tests/torus/student_delivery/mer5865-archive-gates.spec.ts:435`

   `mcqStatesFromArchive` eagerly builds `2^choiceCount` states before
   `assertPredicateEquivalence` can compare `states.length` with the 4,096 cap. A 13-choice part
   already allocates an oversized result only to reject it; a larger authored MCQ can consume
   extreme CPU/memory or never reach the promised fail-loudly check. The existing test constructs
   only eight states and lowers `maxStates` to four, so it does not exercise this ordering bug.
   Reject from the archive-derived choice count before enumeration (or enumerate lazily with a
   hard bound), and test an archive whose natural space exceeds the default cap.

## Nit

None.

## Summary

4 blockers, 3 should-fix, 0 nits. Verdict: **BLOCKED**.

Fresh verification reproduced the stated local result: 33 synthetic tests passed and the two
private-archive tests skipped without private environment variables; `tsc --noEmit` reported only
the two explicitly excluded `liveSocket` errors. The archive reader itself has no direct or
transitive dependency on the extractor's facts/manifest outputs, and the predicate archive leg
really imports the product's `contains`/`equality` modules and uses the same `json-rules-engine`
construction and correctness fold. The four `tsconfig` aliases are therefore load-bearing but
fail-loudly: moving those product modules or their transitive absolute imports will break
type-check/test resolution rather than silently switching semantics. No additional security issue
was found; the material performance issue is the pre-cap power-set allocation above.

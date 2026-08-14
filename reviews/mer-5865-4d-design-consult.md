# MER-5865 4d design consult

Narrow one-pass ruling on the three writer judgment calls and the SUITE artifact disposition. This is not the frozen-revision gate-B pass and does not execute the four contract §7 reviewer derivations.

## 1. Decision 1 — attached-state readiness

**Ruling: SOUND**

`attached` preserves the fail-closed readiness contract for this family. `widgetControlReady` still requires the matching iframe to be visible and then waits on the declared, screen-specific selector; changing the locator state from `visible` to `attached` changes only the fact being proved for a control that is hidden by design. An absent or detached backing control still times out, returns `false`, and is promoted by the registry to the typed readiness failure (`assets/automation/src/systems/torus/pom/delivery/AdaptiveDeckPO.ts:163`; `assets/automation/src/systems/torus/tasks/AdaptiveFamilyRegistry.ts:166`).

This does not re-open the `widgetFrame` swallow class: the registry's readiness leg calls `widgetControlReady` directly, not `widgetFrame`. The later fill-in-the-blanks answer path also remains fail-closed over operability: strict `fillFrameSelects` waits for the exact select cardinality and drives the visible jQuery-UI proxy, while answer/readback and the audited payload still reject a wrong or unusable resolution. The family-specific `readyState: 'attached'` therefore narrows readiness to the real product semantic without turning iframe presence alone into evidence (`assets/automation/src/systems/torus/tasks/AdaptiveFamilyRegistry.ts:315`).

## 2. Decision 2 — retire `savedBarrier` for one family

**Ruling: SOUND**

Family-level retirement is the correct grain. The contract makes `savedBarrier` a named deliberate strengthening, not the license, and the oracle applies it only when a receipt actually declares one or more prefixes. An empty prefix list therefore withdraws an unsupportable strengthening; it does not bypass the local submitted-payload matcher, usable/true server verdict, causal evaluation rules, or transition replay (`docs/exec-plans/current/epics/automated_testing/mer-5865-strict-framework-spec.md` §3.5; `assets/automation/src/systems/torus/tasks/AdaptiveOracle.ts:1160`).

The archive identifies both drag-drop instances at the same family and major and supplies no archive-derived discriminator for save-on-change behavior. A per-directive opt-out would let authored manifest content license its own omission, contrary to B4-MAN's raw-archive derivation. A screen special case would move a product-instance exception into the oracle and create a narrower but still non-derivable escape. Retiring the claim at `spr-widget-general-drag-drop@6`, while retaining all answer-state evidence, is the conservative statement the available source can support (`assets/automation/src/systems/torus/tasks/AdaptiveFamilyRegistry.ts:370`).

## 3. Decision 3 — verdict boundary shape

**Ruling: SOUND-WITH-AMENDMENT**

The intended two-conjunct boundary is sound. `violations.length === 0` is the exact zero test over the unmodified `auditRun` result. The independent `flavor === 'accepted'` check belongs in the boundary because ACCEPT and B4-C3 require the zero audit to occur under the journal's own accepted freeze. It is not a transformation or filter of `auditRun`, so it does not need W-W7c transformation treatment; it is a second raw boundary dependency and must appear in W-W7a and receive its own W-W7d licensing-state subcase (accepted flavor while `auditRun` returns a violation must remain red).

The implementation is not currently limited to those two conjuncts: the completion-text visibility assertion after them can still turn the test red (`assets/automation/tests/torus/student_delivery/lote-plate-tectonics.spec.ts:274`). That makes page state plus `lesson.completion_text` a third effective green dependency and contradicts B4-C15's claimed `iff` boundary. It is also redundant with the oracle's lesson-end and accepted-finalization obligations.

**Exact amendment:** remove the post-boundary completion-text assertion from the gated spec's pass/fail path. In the W-W7a declaration, inventory the complete remaining data/control-flow closure: the `auditRun(manifest, outcome.runRecord, snapshot)` producer path; `violations` and its zero-length access; the journal-produced `flavor` and `strict.finish` path; `expect` and the rejection-only `formatViolations` diagnostic; the null guard; and all exception/fallback or mutable outer-state paths that can alter assertion reachability. Instantiate W-W7d for `flavor` as described above. Do not classify `flavor` as an audit-result transformation.

## 4. Disposition — SUITE reconciliation

**Ruling: SOUND**

Attribute-and-justify is the sound disposition. The mismatch made W-U1 red while it existed, but it does not permanently invalidate the artifact: the frozen half remains derived from immutable revision `f9f9982874`, the additive identities are reconstructable against their introducing commits, and §6.7 explicitly permits additive step-4 identities plus individually justified removals or renames. The artifact records 271 frozen identities, 228 additive identities, and the one frozen removal with its four named replacements; after applying that disposition, the expected current set is 498 identities and the JSON's declared counts equal its actual array lengths.

The reconciliation must not be represented as though the additive manifest had remained continuously current. The artifact and gate evidence already disclose the post-hoc reconciliation and its commit attribution, which preserves the audit trail. This inventory still cannot prove semantic sufficiency by itself; the later bidirectional CONFORMANCE-MAP and its reviewer semantic check remain mandatory and are what prevent a current-discovery copy from laundering an omitted contract subcase.

**Summary: 4 rulings — SOUND: 3; SOUND-WITH-AMENDMENT: 1; UNSOUND: 0.**

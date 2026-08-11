# MER-5865 step-4 proof-contract design read — reopened v5

## Blockers

1. **EXIT-TOTAL / B4-EXIT-INV / W-E1 — the site set is independent only after accepting a writer-fixed file universe.** Section 1 fixes a source-file list in gate evidence, then asks the reviewer to derive the exit-site set from that same list (`mer-5865-step4-driver-swap-contract.md:40-49,99,146-148`). The set equality therefore closes sites *within* the declared files, but not the file scope itself. A helper imported by the new driver or fixture can contain a rejecting await/catch/cleanup exit whose failure crosses the outer boundary; omitting that helper from the gate-evidence scope lets the reviewer-derived site set and writer artifact agree exactly, and W-E2/E3 never inject the omitted file. Add a first, independent scope-closure step: at the gate revision the reviewer derives the source universe from the real switched entry point and fixture dependency/call graph (including every reachable file whose failure can cross the boundary), compares it bidirectionally with the declared scope, and individually justifies any exclusion. Only then may W-E1 compare sites within that independently closed universe. Otherwise the scope list becomes a higher-level version of the self-selected exit inventory it was meant to replace.

2. **B4-VERDICT / W-W6–W-W7 — the fixed alternate list does not close post-build dependencies or selective consumption of violation classes.** V5 adds the right two ingredients—static input-domain closure and per-alternate licensing mutations—but it does not define how the static procedure enumerates the assertion boundary's actual post-build dependencies (`mer-5865-step4-driver-swap-contract.md:53-56,87,165-166`). A captured/global/env/helper signal introduced during build can be absent from the fixed list `{driver flag, ledger, projection, swallowed exception}` while the listed mutations all go red. Separately, a verdict can have no alternate input yet filter one violation class before testing zero; W-W6 can force a different class and pass while that filtered class licenses a false green. Require an independently derived, bidirectional data-flow inventory at the gate revision covering parameters, free/captured variables, imports/helpers, exception/fallback paths, environment/config, and mutable outer state. The assertion must consume the unmodified `auditRun` result with the exact `violations.length === 0` semantics, or every transformation/violation class needs a discriminating mutation. Every discovered non-audit dependency—not only the four anticipated now—must receive the licensing-state mutation.

3. **CONFORMANCE-MAP / W-U6–W-U7 — mapping an ID to a test does not prove that the test implements the full witness, and the inner-case reference can still common-mode with the emitted inventory.** The map requires row/W-ID coverage but records no semantic equality between the fixed mutation/locus and the mapped test's assertions (`mer-5865-step4-driver-swap-contract.md:25-34,117-120,172-178,230-233`). Several W-IDs themselves contain multiple mandatory variants: W-J4 has three fields, W-W3 has bypass and substitution, W-W7 has every alternate signal, and the W-ST/W-D/W-X ranges carry several cases. A passing test that exercises only one weaker variant can still carry the aggregate ID and satisfy the stated map. For runtime case inventories, “pre-fixed expected set” has no fixed provenance or timing: expected and actual can be derived from the same case array, so deleting an element shrinks both. Give every cardinality-bearing variant a stable subcase ID; make the map record test/case ID, exact mutation parameters, expected locus, observed locus, and replay result; and require the gate reviewer to verify semantic conformance of the assertions, not only ID presence. Store each expected case set in a pre-build gate artifact derived from this contract or the pre-step source, with no shared constant/helper with the runtime emitter. Then the emitted inventory may be capture-internal actual evidence without manufacturing its own reference.

4. **B4-C5 / W-J9–W-J10 — the witness matrix proves mint ordering but not the sourced parsed-success boundary.** The row requires lineage to extend only from a parsed successful server creation, while the strict spec states that a failed, unparsed, missing-GUID, or temporally later creation confers nothing (`mer-5865-step4-driver-swap-contract.md:94,130-131`; `mer-5865-strict-framework-spec.md:463-466`). W-J9 and W-J10 cover only the two temporal directions. A lineage implementation can count a failed or unparsed creation record carrying an apparent GUID; both ordering witnesses remain green, yet the second evaluation is falsely licensed. Add C5 deletion/hollowing cases and explicit non-2xx, parse-error, and absent/empty response-GUID mutations through the real entry point, with the consuming evaluation still present; each must fail at the lineage/rotation locus. CONFORMANCE-MAP cannot repair a claim for which no full-strength witness ID exists.

## Should-fix

1. **B4-VERDICT / §3 class conformance — the row combines an IA static subclaim and CI live mutations under one CI label.** W-W7's assertion-boundary/API-shape closure is a static relationship, while W-W6 and the per-signal replays are capture-internal (`mer-5865-step4-driver-swap-contract.md:77-87,165-166`). Labeling the compound row CI is conservative and §5 prevents it from borrowing independent licensing force, so this is not an additional false-green path. It still violates the adopted atomic-row rule of one subject/reference relationship per class. Split VERDICT-S (static dependency and exact-zero shape, IA) from VERDICT-L (forced and alternate-signal mutations, CI), and require both in WIRE.

## Nits

None.

## Round-4 discharge audit

- **r4-B1 — NOT-DISCHARGED:** site identity, kinds, per-site injection, pinned-producer exclusivity, and site-set equality are now precise, but the reviewer derives that set from a file scope fixed by the submission rather than independently closing the source universe first.
- **r4-B2 — NOT-DISCHARGED:** W-W7 closes the four anticipated alternates, but has no post-build dependency-set equality rule and does not exclude selective filtering/transformation of returned violation classes.
- **r4-B3 — NOT-DISCHARGED:** CONFORMANCE-MAP and W-U7 close missing IDs and discovered-identity limits, but ID presence does not prove full witness semantics, compound W-IDs can lose variants, and the pre-fixed case reference is not yet independent of the runtime emitter.
- **r4-SF1 — DISCHARGED:** W-S5 explicitly mutates `data-react-props` on the same retained node after capture, requires the value triple to remain unchanged, and rejects a finalization matching only the mutated props.
- **r4-SF2 — DISCHARGED:** the witness plan is now a stable-ID matrix with mutations, expected loci, and honest `PENDING-BUILD` status; replay claims moved to the future submission and fold history moved to Appendix A.

## Class and composition conformance

- **One-label syntax — PASS:** every §3 row carries exactly one of IA, IS, or CI.
- **EXIT-INV semantic independence — NOT YET PASS:** its reviewer-derived reference shares the submission-fixed source universe until blocker 1 adds independent scope closure.
- **VERDICT atomicity — SHOULD-FIX:** the conservative CI label does not inflate independence, but the row still mixes IA static and CI replay relationships.
- **CI-only licensing — PASS:** §5 requires the IS identity/raw-archive anchors and IA wiring, STAMP, suite/conformance, EXIT-INV, and deletion anchors in addition to every CI decision term. No CI-only route through the stated conjunction was found.

## Template conformance

All seven contract-before-build sections are present and ordered. The matrix gives stable witness IDs, exact planned mutations, rejection loci, and honest pending status; the fold history is isolated in an appendix. Although the proof inventory remains necessarily substantial, v5 is rigid and scan-oriented enough that the round-4 compactness finding is discharged.

## Summary

**Counts:** 4 blockers, 1 should-fix, 0 nits.

**Verdict:** **REDESIGN**. V5 materially improves falsifiability and presentation, and it fully closes both round-4 should-fixes. It still allows four material proof gaps: a self-selected exit-file universe, post-build or selectively consumed verdict inputs, ID-only test conformance with a potentially common-mode case reference, and failed/unparsed creations that can falsely extend lineage. This remains a proof-design verdict only—never pre-approval of implementation or gate evidence.

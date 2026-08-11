# MER-5865 step-4 proof-contract design read — reopened v6

## Blockers

None.

## Should-fix

None.

## Nits

None.

## Round-5 discharge audit

- **r5-B1 — DISCHARGED:** EXIT-SCOPE is now a mandatory IA row and step 0 of EXIT-TOTAL; the gate-B reviewer derives the real entry-point/fixture source universe before EXIT-INV, compares it bidirectionally with the declared scope, justifies every exclusion, and an omitted reachable file is RED through W-E0a.
- **r5-B2 — DISCHARGED:** VERDICT-S independently derives the complete post-build data-flow domain and fixes the exact unmodified `violations.length === 0` shape; VERDICT-L instantiates a licensing mutation for every discovered dependency and discriminates every violation class through W-W7c/d.
- **r5-B3 — DISCHARGED:** CONFORMANCE-MAP operates at mandatory-subcase granularity, records exact mutation and expected/observed loci, and makes weaker mapped assertions RED through reviewer semantic verification; inner-loop expected sets are fixed pre-build with W-U9 rejecting shared constants, arrays, or helpers.
- **r5-B4 — DISCHARGED:** W-J11–J15 cover non-2xx, parse error, absent/empty response GUID, deletion, and hollowing with the consuming evaluation retained; W-J9/J10 retain the temporal directions and C8/W-R2 retain recursive rooting/ownership.
- **r5-SF1 — DISCHARGED:** VERDICT-S is a standalone IA row, VERDICT-L a standalone CI row, and WIRE requires both.

## Deferred-reviewer confirmations

These are category **(b)** obligations correctly deferred to the named gate-B reviewer. They are confirmations, not findings: each procedure is falsifiable, has a RED condition, and an unperformed derivation is itself RED under §5.

- **(b) B4-EXIT-SCOPE / W-E0a–b — CONFIRMED:** “every reachable file” over the dependency/call graph denotes transitive reachability at the finite gate revision; a direct-import-only traversal would not satisfy the stated procedure. Third-level helpers, registry entries, and wrappers therefore cannot escape when their failures can cross the boundary. The reviewer derives the universe, reverse-checks it against the declared scope, and records exclusions individually.
- **(b) B4-VERDICT-S/L / W-W7a–d — CONFIRMED:** the reviewer derives the boundary's data-flow inventory from the implemented graph rather than a pre-build fixed list, so build-introduced captured variables, helpers, fallback paths, environment/config, or mutable state enter the inventory. W-W7d expands once per discovered dependency, W-W7b forbids transformations of the audit result unless separately witnessed, and W-W7c closes selective violation-class filtering.
- **(b) B4-SUITE / W-U7–U9 — CONFIRMED:** the expected case set is fixed before build from the contract or pre-step source, while the runtime emitter supplies only actual evidence. The no-shared-constant/array/helper rule is checkable at gate review from artifact chronology plus the implemented dependency/reference graph; shared lineage is explicitly RED at W-U9. W-U8 separately prevents truthful IDs attached to weaker assertions.
- **(b) B4-C5 / W-J9–J15 — CONFIRMED:** the witness family covers every decision-relevant clause of §3.3's mint sentence: parsed, 2xx, response-supplied nonempty GUID, response order before use, and absence/deletion/hollowing; recursive rooting remains covered by C8/W-R2. Instantiation and replay belong at gate B, not in this pre-build contract.

## Class and composition conformance

- **Atomic classes — PASS:** every §3 row carries exactly one IA, IS, or CI relationship. EXIT-SCOPE/EXIT-INV are IA; VERDICT-S is IA and VERDICT-L is CI.
- **CI-only licensing — PASS:** §5 requires the IS identity/raw-archive anchors and the IA wiring, STAMP, VERDICT-S, suite/conformance, EXIT-SCOPE/INV, and deletion anchors in addition to CI decision rows. No CI-only route through GATE-B-CLOSE was found.
- **Cross-row fail-closed composition — PASS:** failed EXIT-SCOPE cannot be masked by a green EXIT-INV; missing reviewer derivations and unexecuted witnesses are RED; DIFF remains corroborating only.

## Template conformance

All seven contract-before-build sections are present and ordered. The proof table is atomic, the witness matrix fixes stable subcase IDs and rejection loci, §5 closes missing/unexecuted evidence, §6 bounds every delta with expiry/owner where applicable, and §7 names the post-build reviewer derivations and their RED conditions. The appendix keeps fold history out of the normative proof path. V6 remains substantial but is rigid and scan-oriented rather than prose-dependent.

## Summary

**Counts:** 0 blockers, 0 should-fix, 0 nits.

**Verdict:** **SOUND-AS-DRAFTED**. V6 closes all five round-5 findings. The remaining work is correctly assigned to four named gate-B reviewer derivations that cannot exist before implementation; each has a falsifiable procedure and fail-closed RED condition. This verdict means the proof design is reviewable, never that the future implementation, witnesses, or gate evidence are pre-approved.

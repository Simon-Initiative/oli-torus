# MER-5865 remaining-gates process consult

## Evidence audit

| Question | Evidence read in this pass | Conclusion | Confidence |
|---|---|---|---|
| Were the six B0 MATERIAL findings real? | `mer-5865-gate-b0.md` and rounds 2–6, including every writer response and the recorded mutation replays | Yes. Each finding identifies a concrete false-green or same-screen-attribution path under the adopted materiality policy. | high-exhaustive for the six cited rounds |
| Did prior fixes regress? | The closure audits in rounds 4–6 and their historical negative replays | No regression is shown in the concrete mutations once they became standing witnesses. | high-exhaustive for the witnesses reported in these rounds |
| Did every claimed closure hold at its advertised scope? | Successive reviewer findings in rounds 2, 3, 5, and 6 | No. Several specific fixes held while the broader “fixed as a class” or independence claim remained unsupported. | high-exhaustive for the six cited rounds |
| Is the pattern older than B0? | Checkpoint A rounds 9–10 and the closure consult | Yes. Checkpoint A shows the same common-mode and incomplete-class-closure pattern, especially `combine_feedback` and the round-9 schema sweep. | high-within-scope for the cited earlier loop |
| Does contract-before-build duplicate §8? | Spec HANDOFF, §7 gate model, and §8 deterministic matrices | No. §8 specifies behavioral branch coverage; it does not specify the proof graph by which a gate establishes evidence completeness, independence, and final-decision composition. | high-within-scope for the remaining gate design |

## 1. Diagnosis

The diagnosis is substantially correct, with one important wording correction.

Every MATERIAL finding across B0 rounds 1–6 was real under the adopted policy. The recurring engine was overclaim in the proof boundary, not regression of previously witnessed behavior:

| Round | What the submission claimed | What remained unenforced |
|---|---|---|
| 1 | Independent shadow equivalence | Contract facts came from the shipped ledger; permits and plans were synthesized from the events they purported to validate. |
| 2 | Archive-derived contract and a closed driver-evidence gap | Roles still shared the shipped answers source; archive completeness was not exercised; a contract failure could enter the driver-only allowlist. |
| 3 | Complete archive validation and a pinned evidence inventory | Local rule references made completeness vacuous; the pin erased screen ownership. |
| 4 | Fully pinned evidence identity and fail-closed replay | Expected inventory and mandatory-evidence cardinality still shrank with the journal under judgment; the shipped ledger could disappear. |
| 5 | Mandatory sources protected by deletion witnesses | Record shells could survive without evidentiary content; `combine_feedback` was unpinned; the bail envelope was not established. |
| 6 | Cross-source finalization and save evidence | Wire-to-wire agreement was internal consistency, not independent correlation; rejected saves were described as committed barrier evidence. |

The correction is that “fixes hold under re-verification” is true for the concrete negative witnesses after they were introduced, but too strong for the writer's advertised closure scope. Round 2 is still a residual closure failure of round 1's archive-independence claim; round 3 is a residual closure failure of round 2's completeness claim; round 6 is a residual closure failure of round 5's cross-source claim. These are not regressions, but neither are they wholly new defects. They are narrower implementations being described as broader guarantees.

The loop engine is therefore more precisely:

1. a specific defect is fixed and witnessed;
2. the writer promotes that local result into a class-level guarantee;
3. the proof omits either provenance, completeness, content semantics, or a common-mode mutation;
4. fresh review finds a false-green inside the difference between the local fix and the promoted claim.

That pattern also appears at Checkpoint A: round 9's `combine_feedback` coercion allowed common-mode agreement, and round 10 disproved the writer's claimed sweep of optional schema fields by finding unvalidated nested `version` and `mode` fields. The B0 pattern is thus a continuation, not a one-gate anomaly.

## 2. Standing claims-table protocol (B)

Adopt the round-6 ordering and reference classes as the standing format, with amendments.

### Reviewer order

1. **Fresh-eyes pass first.** Derive the gate's claim inventory from the spec, implementation, test entry point, allowlists/deltas, and final green predicate without consulting the writer's claims table. Record candidate false-green mutations before reading the table.
2. **Claims table last.** Reconcile the writer's table against the reviewer's independently derived inventory. The table is a completeness and wording audit, not the source of the review plan.
3. **Conformance replay.** Verify the reference provenance and replay the named witnesses through the same entry point that makes the gate decision. A witness is not credited merely because a lower-level helper rejects it.

This order directly addresses anchoring. It should remain mandatory even when the table appears obviously complete.

### Reference classes

Retain exactly these three classes:

- `independent-artifact`: the reference exists outside the capture under judgment;
- `independent-source`: the reference is captured, but originates from a different source than the subject it checks;
- `capture-internal`: corroboration among fields from the same evidence domain.

Only the first two count as independent checks. `Independent-source` is relational, not absolute: DOM versus wire may be independent for a particular field while still sharing the recorder, serializer, dump, or run. The table must disclose that shared failure domain. Likewise, an `independent-artifact` generated by the same extractor or helper as the subject remains independent of the capture but not implementation-independent. Round 6's `combine_feedback` row is the model disclosure.

Do not use `mixed` as a class. Split a compound guarantee into atomic rows so every row has one subject, one reference relationship, and one defensible class. A capture-internal subclaim may corroborate an independent row, but it cannot silently borrow that row's class.

### Standing table columns

The standing table should be:

| ID | Atomic claimed guarantee | Spec/gate source | Subject checked | Reference and provenance | Reference class | Shared producer/failure domain | Positive witness | Red witnesses | Expected rejection locus |
|---|---|---|---|---|---|---|---|---|---|

The original four columns still allow the writer to hide too much:

- **Omitted claims.** “One row per claimed guarantee” is self-policed unless each row maps to a spec clause, mandatory source, delta/allowlist, or final-decision term. The reviewer must reconcile both directions: every source obligation has a row, and every row has a source obligation.
- **Compound or inflated language.** Words such as “real,” “authenticated,” “complete,” “correct,” and “same-screen differential” can combine several guarantees under one partial witness. Atomic rows force the exact predicate into view.
- **Shared lineage.** Storage in two artifacts does not establish independent derivation. Reference provenance and shared helpers/traversals must be explicit.
- **Witnesses that go red for the wrong reason.** Each witness must name the expected rejection stage/code or predicate. Otherwise an unrelated envelope failure can make a claimed guarantee look tested.
- **Known-mutation overfitting.** Deletion and hollowing are mandatory minima, not a complete mutation vocabulary. Each row also needs the transformations implied by its semantics: common-mode substitution, ownership swap, status corruption, ordering/boundary changes, duplication, wrong-type/coercion, or cardinality-preserving replacement as applicable.
- **Conditional capture-internal claims.** A self-derived inventory may be useful, but its row must state the independent predicates on which it is conditional. It may not independently license the final green result.
- **Unreplayed witness names.** The row should identify the canonical test/mutation and the submission should record its latest replay result. A prose claim that a witness exists is insufficient.

Deletion **and** hollowing remain mandatory per evidence source. The amendment is that the writer must additionally ask, for every claimed guarantee: “What mutation preserves presence and local consistency while changing the decision-relevant meaning?” Round 6's common-mode identity substitutions and status corruption are the canonical examples.

## 3. Contract-before-build (C)

Adopt it for gates B, C1, and C2. It is worth one additional Codex pass and does not duplicate §8.

Section 8's deterministic matrices answer: “For this implemented contract, have its accept/reject branches been exercised?” The proposed one-page contract answers earlier questions that §8 does not: “Why is this the right contract for this gate decision? Which source pins each guarantee? Is that source independent in the required dimension? How do the individual predicates compose into a fail-closed green?” B0 repeatedly failed in that gap even while its local tests passed.

The contract should be short and rigid enough to review in minutes:

1. **Decision and scope.** One sentence for what the gate licenses, one for what it does not license, and the exact final green predicate.
2. **Material false-green threats.** The small gate-specific threat list: omission, hollowing, common-mode substitution/coercion/helper use, self-derived completeness, mis-attribution, and any gate-specific status/order/provenance risk.
3. **Atomic proof table.** For each decision term: subject, reference, class, provenance/shared producer, and whether it is mandatory, corroborating, or an allowed delta. This is the design-time predecessor of the submission claims table.
4. **Witness plan.** A positive witness plus deletion and hollowing for every mandatory evidence source, then the claim-specific semantic mutations. State the expected rejection locus for each.
5. **Composition and fail-closed rules.** Show how row results combine, how missing/unknown/malformed input is treated, and state that no capture-internal row can independently turn the gate green.
6. **Allowlist/delta discipline.** Enumerate every allowed gap/delta, its independent bound, owner, and expiry gate. No open-ended class or predicate.
7. **Conformance IDs.** Give the claims stable IDs that implementation tests and the submission claims table must reuse. A material change to a predicate, reference, class, or composition rule reopens the contract; ordinary implementation detail does not.

For C1, “independence” will often concern archive facts, manifest generation, registry metadata, and shared extractors rather than live capture sources. For C2, it will concern fresh-run provenance, per-lesson/family evidence, cross-migration aggregation, and the final decision's resistance to one successful path masking another. The same compact format applies without forcing B0-specific capture concepts into those gates.

The contract pass must not be treated as advance approval of the implementation. Its output is a reviewed proof design; the later gate review still performs fresh-eyes adversarial review before checking conformance.

## 4. False-green risks introduced by this process

The proposed process reduces the observed failure mode but creates its own risks:

1. **Anchoring and confirmation bias.** A polished contract or claims table can narrow the reviewer to the writer's inventory. Fresh-eyes first and table last are mandatory mitigations.
2. **Contract omission.** A one-page proof can be internally rigorous while omitting a decision-relevant guarantee. Two-way mapping between spec/gate obligations and claim IDs is required.
3. **Taxonomy laundering.** A shared artifact, extractor, recorder, or serializer can be labeled independent without disclosing the common failure domain. Provenance and shared-producer columns prevent the class label from carrying more meaning than it has.
4. **Mutation overfitting.** A fixed suite of deletion/hollowing witnesses can become green while a cardinality-preserving, common-mode, ordering, status, or attribution mutation survives. Witness selection must derive from claim semantics, and the reviewer must still invent mutations independently.
5. **Stale-contract drift.** Implementation changes can preserve test names while changing the predicate or reference. Stable claim IDs plus an explicit material-change rule are required; contract conformance must be rechecked at submission.
6. **Fragmented correctness.** Every row can pass alone while their composition leaves a gap or one failure suppresses another. The contract must state the final decision formula, and implementation review must mutate across row boundaries.
7. **Pre-review blessing.** The implementation reviewer may relax because the contract received a Codex pass. The contract verdict must explicitly mean “reviewable design,” never “future gate expected to pass.”
8. **Reviewer fatigue.** An extra pass can reduce later adversarial attention if it expands into another long loop. Keep it to one page and one Codex pass; unresolved design questions return to the human/writer before build rather than becoming implementation assumptions.

The largest residual risk is not that the table contains a false row. It is that every listed row is true while an unlisted guarantee or cross-row composition path still permits green. The fresh-eyes inventory and final-decision composition check are therefore more important than table polish.

## 5. Verdict

**ADOPT-WITH-AMENDMENTS.**

- Adopt B as the standing submission format, preserving fresh-eyes review first, claims-table audit last, and the three reference classes.
- Amend B with atomic rows, bidirectional source coverage, provenance/shared-failure disclosure, expected rejection loci, positive witnesses, and semantic mutations beyond deletion/hollowing.
- Adopt C for B, C1, and C2 as a one-page, one-pass proof-design gate before machinery is built.
- Keep §8 matrices: they remain the implementation-level branch tests and are complementary, not redundant.
- Keep the no-round-cap rule, materiality policy, reviewer/writer separation, and human commit gates unchanged.

The evidence for adoption is unusually direct: six B0 rounds repeatedly found real false-green paths in the space between a local fix and its advertised proof scope. B and C target that space. The amendments are necessary because the round-5 claims table itself did not prevent round 6's two overclaims; a table without atomicity, provenance, claim-specific mutations, and fresh independent inventory would formalize the existing failure mode rather than remove it.

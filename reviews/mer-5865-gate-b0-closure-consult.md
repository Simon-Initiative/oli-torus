**Verdict:** ENDORSE-WITH-AMENDMENTS

The B0 equivalence conclusion is supportable and the adversarial shadow loop should remain
closed. The closure inventory is not yet complete, however, and four asserted step-4
discharges are stronger than the current step-4 contract.

## Missing residuals

| Missing residual | Closure amendment / stable step-4 obligation for gate B |
|---|---|
| **C3 — green/accepted snapshot declaration.** This is explicitly capture-internal and is absent from the residual table. | **B4-C3 — Journal-owned completion state.** The live driver cannot declare or deserialize an accepted state. The journal state machine alone must produce an immutable accepted freeze, completed-failure freeze, or seal; only the accepted-freeze branch may enter the green predicate. Gate B must reuse this ID in its state-machine and integration witnesses. |
| **C4a — run correlation.** Its table class is `independent-source`, but the disclosed shared recorder/serializer is a common failure domain; it therefore belongs in the “otherwise non-independent” inventory. | **B4-C4A — Independently rooted run correlation.** Establish section, revision, and resource-attempt identity from a run/session source that is not the finalization record being judged, then require the parsed finalization identities to match it exactly before accepted freeze. A single producer may serialize the result, but it may not manufacture both sides of the comparison from the same wire record. |
| **C15 — zero in-scope violations.** The claims table calls this a capture-internal decision term, but the residual table omits it. | **B4-C15 — Live acceptance composition.** A run is green only after `auditRun` consumes the immutable live journal and complete live `runRecord` and returns zero violations. Every non-green driver exit must be sealed or completed-failure evidence and must map to at least one positive oracle violation; a driver success flag is never an independent license. |
| **C16 — zero unexplained shipped-ledger/shadow differences.** This is another capture-internal decision term omitted from the table. | **B4-C16 — Comparison-seam retirement.** Gate B must confirm that the switched strict entry point has no shipped-ledger or shadow-projection acceptance dependency: the live journal/run-record oracle is the sole decision path. The differential harness remains swap/regression evidence, not a second production oracle. |
| **Readback-completion ordering.** The closure carries only “permit-stamp API debt,” although the accepted Checkpoint-A deferral was the **permit/readback** stamp API and §3.5 orders saved barriers from readback completion to the check permit. | **B4-STAMP — One journal sequence domain.** Entry fences, answer/readback-completed fences, check permits, acknowledgement permits, and the journal traffic they bound must all be issued by one journal-owned monotonic sequencing API. Caller-supplied or driver-local sequence values are forbidden. Gate B must exercise both request-before-fence and fence-before-request interleavings for each ordering-sensitive fence. |

## Invalid or incomplete discharges

| Residual row | Judgment | Required contract obligation |
|---|---|---|
| **C5 mint corroboration** | Invalid as worded. The driver does not “mint under a check-click permit”; §3.3–§3.4 make the mint a parsed successful server creation observed between the two navigation evaluations, and navigation evaluations are governed by the whole-sequence rule rather than a check-click causal license. Calling it first-party driver evidence weakens the required provenance. | **B4-C5 — Journal-observed causal mint.** Admit lineage extension only from the server creation response, ordered in the journal domain between the rotation evaluations, with the returned identity preceding every evaluation that uses it. Missing, failed, malformed, late, or driver-declared mints must be red. |
| **C8 lineage set** | Invalid as worded. “The driver KNOWS its attempts” is not the §3.3 contract and would recreate self-asserted causal evidence. The driver supplies a rendered-attempt root at its identity read; only causally ordered journal-observed server mints extend that root. | **B4-C8 — Derived, not declared, lineage.** Lineage roots must be bound to journal-stamped visits, and extensions must satisfy §3.3's parsed-success and temporal rules. Evaluations and saves may be checked against the derived set, but no driver declaration may insert an identity into it. |
| **C12 run distinctness** | Unsupported by the cited design. Neither §3.2–§3.5 nor §7 defines the claimed “driver-side session identity” or how it proves distinct live runs. Fresh sections are expected, but that is not the stated discharge. | **B4-C12 — Run/session identity contract.** Define the run identity, its trusted source, its binding to fresh setup and finalization correlation, and the gate-B witness that the canary and three acceptance runs are distinct. Do not infer distinctness solely from captured minted identities. |
| **Permit-stamp API debt** | Incomplete. The debt note promises journal-domain permit stamps, but §3.4 does not define the issuing API, and the closure omits the equally ordering-sensitive readback-completion stamp. | **B4-STAMP** above must be a normative step-4 contract row and a material gate-B check, not merely debt prose. |

C10 is validly discharged when real permits, plans, acknowledgements, and their obligations are
audited; its shadow-only muted-inventory comparison then disappears. C13a is validly discharged
by §3.2's closed operation-failure union plus freeze-timeout and sealed-journal evidence. The
observer-fence/first-screen row is also validly discharged by §3.3's journal-issued identity-read
fence and explicit pre-entry window.

## Deferred list

- **Presence-only/regex predicates:** the owner and closing point are wrong. Step 5 follows the
  step-4 LotE switch, so it is not “before first live use.” Before gate B, the step-4/LotE
  manifest owner must either implement the exact predicate contract or explicitly make the
  reduced matcher scope part of the live contract and stop describing it as deferred. Track this
  as **B4-PRED**.
- **LLM-capable screens:** acceptable. The manifest/registry design owns the future contract,
  and fail-closed validation supplies a real closing point: no capable screen can reach live use
  until an independent runtime reference is specified and validated.
- **Destination ancestor-swap race:** acceptable at its stated scope. The capture-harness owner
  must close it before the first capture on a shared machine; it is not a gate-decision license.
- **`adaptive-authoring` flake:** “suite health, candidate ticket” is not a named owner or closing
  point. Move it out of the step-4 residual list into an actual suite-health ticket with an
  accountable owner. Before gate B cites “264 tests” as a mechanical net, it must report the
  exact executed strict subset and must not let this serial flake prevent that subset from
  running.

Closing B0 now transfers the residual risk to gate B's **single** implementation pass plus the
mechanical nets: the 264-test suite, the shadow differential harness, and the canary/live
acceptance runs. That transfer is reasonable once the stable obligations above are inserted.
**B4-STAMP is too weighty to leave implicit:** caller-local permit or readback counters can order
a save on the wrong side of a barrier, allowing mid-operation traffic to satisfy `savedBarrier`;
pure tests that reuse the same mistaken counter and ordinary green live runs may never force the
racing interleaving. **B4-C3/B4-C15 are likewise material composition obligations:** without
them, a completed-failure or sealed run can be reported green even though its journal contains a
violation. Gate B must treat those obligations as contract failures, not implementation notes.

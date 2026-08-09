# MER-5865 Checkpoint A — closure consult

## Verdict

**ENDORSE-WITH-AMENDMENTS.** Close Checkpoint A after all five round-10 findings are fixed.

## 1. Material findings remaining after the round-10 fixes

None.

That conclusion is conditional on the round-10 fixes landing as described. Three of those fixes
are material under the proposed bar:

- archive `resource_id` identity, because an incorrectly identified activity can pass the offline
  gate and preserve a false-green live result;
- an otherwise-clean sealed audit, because it can directly return a false green after an ordinary
  bail; and
- missing-key versus `undefined` stability, because a changed committed path can satisfy a
  presence expectation and produce a false-green cross-screen receipt.

The round-10 redaction type narrowing and answer-operation `version`/`mode` validation are not
material under this bar, although fixing them in the final round is appropriate.

The only explicitly deferred item from rounds 1–10 is the journal-issued permit/readback stamp
API from round 7. Round 8 accepted that deferral because no separate step-3 hazard was identified
and step 4 owns the real-driver integration. It is therefore not an open Checkpoint A defect. It
must, however, become material at the first gate that admits live driver evidence if the named
step-4 work has not closed it.

## 2. Strongest failure mode for B0/B/C1/C2

**Common-mode agreement can disguise a material defect as schema hardening or type narrowing.**
A malformed or self-asserted value may look non-material because both the driver and oracle accept
it, while that same value selects the wrong branch in both paths; replay then agrees with the live
decision for the wrong reason. Round 9's unvalidated `combine_feedback` field is the clearest
example: coercion affected planning and obligations while recorded-plan replay could still agree.
The analogous risk in later gates is a deferred field or causal stamp becoming live before its
consumer boundary is reclassified.

## 3. Amendments

1. Amend clause (a) to read: “create, preserve, or mask a false-green outcome on a live run,
   **including common-mode agreement where the driver and oracle/replay share the same malformed
   input, coercion, helper, or self-asserted causal evidence**.”

2. Amend the non-material examples to read: “Type narrowing, validation of fields not yet
   consumed, and defense-in-depth beyond the current driver contract are non-material **only when
   a traced consumer analysis shows no path to a live decision, replay comparison, causal license,
   or screen attribution in the current gate, and any deferral has a named owner that closes before
   first live use**.”

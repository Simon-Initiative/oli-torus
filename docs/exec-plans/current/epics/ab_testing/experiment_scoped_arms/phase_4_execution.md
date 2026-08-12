# Phase 4 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/experiment_scoped_arms`
Phase: `4 - Intervention-Scoped Assignment, Rendering, and Completion`

## Scope from plan.md

- Assign independently and stickily per placed intervention while retaining legacy assignment compatibility.
- Gate experiment-specific delivery work, preserve inert fallback and preview behavior, and preserve the compound intervention identity contract across copy and duplication boundaries.

## Implementation Blocks

- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed

The phase contract was amended with FR/AC-034: both Alternatives strategies may be placed inside
ordinary content containers, but no Alternatives placement may have another Alternatives placement
as an ancestor. Authoring insertion and drag/drop enforce the structural constraint and allow an
invalid legacy placement to be dragged outward for manual repair; the versioned schema rejects
direct and deep Alternatives descendants. Delivery classifies all placements in one traversal,
batches every valid experiment placement once, and gives invalid nested placements inert first-branch
fallback without assignment or exposure. Recursive assignment rounds remain unnecessary. The legacy
Missing page identity now returns inert decisions; the obsolete per-placement preparation adapter
and its legacy tests were removed so assignment preparation has one page-scoped batch path.

Whole-page duplication preserves content-element IDs. The newly created page resource ID already
makes every `(page_resource_id, content_element_id)` intervention distinct, avoiding blanket ID
rewrites that could invalidate unrelated page-local references. Same-page Alternatives copy or
reinsertion remains responsible for generating a new placement element ID.

## Review Loop

- Round 1 findings: The negative relevance gate ran after unrelated delivery reads; sticky
  assignment reads lost decision-point option mappings; positive-path preparation still performs
  per-placement assignment resolution and therefore remains an N+1 path.
- Round 1 fixes: Moved the relevance gate ahead of group/context resolution and made sticky reads
  mapping-aware.
- Round 2 findings: The initial batch implementation still recorded exposures per placement,
  repeatedly scanned joined assignment rows, and emitted assignment evidence inside the batch
  transaction. Concurrent unique-conflict recovery also needed a savepoint.
- Round 2 fixes: Added set-based page-placement assignment and exposure APIs, grouped rows by placement,
  accumulated attribution lists once per page batch, delayed assignment evidence until commit,
  and isolated recoverable inserts with savepoints. Added 2-versus-10 distinct-placement query
  proofs, rollback/no-evidence coverage, and concurrent sticky-winner coverage.
- Round 3 findings: No performance blockers remained. A final Elixir review found no blockers after
  the transaction fixes, before the final preview/completion closure pass.
- Superseded experiment-root follow-up finding: The referenced Alternatives schema still required legacy
  element strategy and did not require the authoritative group reference.
- Superseded experiment-root follow-up fix: Made `alternatives_id` required, removed strategy from newly
  authored placement data and its schema properties while retaining permissive legacy reads,
  preloaded authoritative group metadata for drag/drop validation, temporarily preserved nested
  learner-choice Alternatives, and enforced an experiment-controlled root invariant. The later
  structural-constraint follow-up replaced this strategy-dependent rule in full.
- Gate D reconciliation finding: The plan omitted AC-034 from Gate D, the detailed design described
  phase-entry behavior as current behavior, and this record claimed completion before the required
  inert-preview and visible-only completion proofs were present.
- Gate D reconciliation fix: Added AC-034 to the Phase 4 goal, proof map, and gate; labeled the old
  delivery behavior as the phase-entry baseline; and reopened the test, review, and done checks until
  all Gate D proofs pass.
- Structural constraint follow-up: Replaced the root-only experiment rule with the universal
  no-Alternatives-ancestor invariant. Removed strategy-dependent placement validation, enabled both
  insertion types in ordinary containers, added recursive schema/configuration validation, restored
  one-pass non-root discovery, and made invalid legacy nesting fail closed without persistence.

## Verification Evidence

- Preflight work-item validation passed.
- Targeted policy, assignment, rendering-decision, page-content, schema, and editor-identity tests
  passed before the final Gate D closure pass.
- Batch API and full delivery preparation both retain equal SELECT counts for 2 and 10 distinct
  placements, including discovery within ordinary containers.
- Batch rollback emits no assignment evidence, and concurrent first encounters reload one sticky
  winner.
- The generated PostgreSQL migration applied, rolled back, and reapplied successfully.
- Schema, authoring, configuration, and delivery tests prove both strategies are accepted inside
  ordinary containers, every Alternatives-within-Alternatives combination is rejected, invalid
  content can be dragged outward, and invalid delivered nesting receives inert first-branch fallback.
- Instructor Preview renders all alternatives as accessible, keyboard-operable tabs without
  assignment state; nested preview tabsets are isolated from their parents.
- Learner activity realization and completion use the prepared visible branches. Tests cover
  distinct required-activity counts, visible-only partial progress, and exact 100% completion.
- Repeated placements preserve independent local content; same-page reinsertion creates a fresh
  element ID; page duplication preserves local IDs under a new page resource without copying or
  retargeting intervention bindings.
- Thompson Sampling tests prove two interventions share one committed decision-point snapshot
  while separate decision points and experiments remain isolated.
- The actual `PageContext.create_for_visit/4` negative path performs one experiment relevance
  SELECT, performs no assignment or policy-state SELECTs, and realizes only the fallback branch.
- Final verification: `mix format --check-formatted`, `mix compile --warnings-as-errors`, and the
  145-test aggregate backend Phase 4 suite passed. The focused frontend suite passed with 18 tests;
  ESLint, Prettier, and TypeScript checks passed.
- Final security, performance, Elixir, UI/TypeScript, and requirements reviews reported no
  remaining Gate D blockers. Postflight work-item validation passed.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes

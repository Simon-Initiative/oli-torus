# Phase 1 Execution Record

Work item: `docs/exec-plans/current/epics/course_replication/course_builder_sources`
Phase: `1 — Confirm the existing My Course Sections integration and add the tag-rendering helper`

## Scope from plan.md
- Confirm the already-shipped (`MER-5831`) My Course Sections query, authorization, and row normalization are unchanged and correct.
- Add a tag-derivation helper (`TableModel.tag_variant/1`) built directly on the existing `is_product?/1`/`is_course?/1` predicates — no new query, no new row-typing abstraction, no visible UI change yet.

## Implementation Blocks
- [x] Core behavior changes — `TableModel.tag_variant/1` added (`lib/oli_web/live/new_course/table_model.ex`): returns `:template` for a product/blueprint source, `:my_section` for a course/enrollable source, `nil` otherwise. Built on the existing `is_product?/1`/`is_course?/1` predicates; no changes to those functions or to `source_title/1`/`source_description/1`/`source_identifier/1`.
- [x] Data or interface changes — none. `SectionCreation.permitted_sections/2`, `select_source.ex`'s `retrieve_all_sources/2`, and `card_listing.ex`'s selection click were read and confirmed unchanged; no code in those paths was touched.
- [x] Access-control or safety checks — confirmed by reading `lib/oli/delivery/section_creation.ex`: `permitted_sections_query/2` scopes to "active enrollable sections the actor teaches, or any of them for an administrator," institution-scoped for LTI. No change made; existing behavior preserved and regression-tested (see Test Blocks).
- [x] Observability or operational updates — none needed for this phase (no visible behavior change).

## Test Blocks
- [x] Tests added or updated:
  - New `test/oli_web/live/new_course/table_model_test.exs` (4 tests): `tag_variant/1` returns `:template` for a blueprint/product row, `:my_section` for an enrollable/course row, `nil` for an ordinary project row, and `nil` (not a raise) for unrecognized/empty row shapes.
  - No new tests added for My Course Sections eligibility/scoping (AC-004, AC-005, AC-006): existing coverage already satisfies them exactly, added by `MER-5831`:
    - AC-004 (instructor sees only sections they teach): `test/oli_web/live/new_course/select_source_test.exs`, `describe "Instructor course copy sources"` → `"shows courses where the user is an instructor and hides learner-only courses"`.
    - AC-005 (admin sees any active enrollable section): `test/oli/delivery/section_creation_test.exs`, `"T21 resolves any active enrollable section for an admin"`.
    - AC-006 (a denied section is absent from the response, not just hidden): `test/oli/delivery/section_creation_test.exs`, `"section copy listing and resolution enforce the same institution boundary"` and `"student enrollment does not authorize a section copy"` (both assert directly on `SectionCreation.permitted_sections/2`'s return value).
  - Writing near-duplicate new tests for AC-004/005/006 was deliberately avoided per the coding guideline to avoid redundant test bloat; running the existing suites below is this phase's regression proof for those three ACs.
- [x] Required verification commands run:
  - `mix test test/oli_web/live/new_course/table_model_test.exs` — 4 tests, 0 failures.
  - `mix test test/oli_web/live/new_course/select_source_test.exs` — 33 tests, 0 failures (includes the AC-004 test above).
  - `mix test test/oli/delivery/section_creation_test.exs` — 30 tests, 0 failures (includes the AC-005/AC-006 tests above).
  - `mix format --check-formatted lib/oli_web/live/new_course/table_model.ex test/oli_web/live/new_course/table_model_test.exs` — formatted OK.
- [x] Results captured — see command outputs above; all green.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged — no divergence found; `table_model.ex`/`select_source.ex`/`card_listing.ex` matched the FDD's Section 3 description exactly (already updated 2026-09-18 after the `MER-5831` merge).
- [x] Open questions added to docs when needed — the "Template" vs. "Free" tag-text discrepancy was found and documented (with an interim decision and a pending Slack question to design) across `informal.md`, `prd.md`, `fdd.md`, `plan.md`, and the `ui_workflow` brief before this phase's code was written, so `tag_variant/1` already returns `:template` (not `:free`) consistent with that decision.

## Review Loop
- Round 1 findings: `$harness-review` run against `.review/security.md`, `.review/performance.md`, `.review/elixir.md` (Elixir file changed), and `.review/requirements.md` (`prd.md` changed), via 4 parallel `reviewer` subagents per `docs/CODEREVIEW.md`.
  - Security: no findings — pure function, no DB/query/authz/rendering surface touched.
  - Performance: no findings — O(1) pure map lookup, no new N+1 or loop-query risk.
  - Elixir: no blocking findings. One non-blocking observation: `tag_variant/1` is now the 4th function in `table_model.ex` repeating the same `case {is_product?(item), is_course?(item)} do ... end` shape (alongside `source_title/1`, `source_description/1`, `source_identifier/1`); a private `classify/1` helper could de-duplicate this later. Pre-existing pattern, not introduced by this diff — logged as a follow-up, not required for this narrowly-scoped phase.
  - Requirements traceability: no findings — the `prd.md` change matches `requirements.yml`/`fdd.md`/`plan.md`, and the AC-004/AC-005/AC-006 test citations above were independently verified (existence, assertions, and pass/fail) by the reviewer, matching what this record claims.
- Round 1 fixes: none required. The Elixir reviewer's de-duplication observation is recorded as a follow-up for a later phase (when the badge/tag-rendering work in Phase 3 touches this module again), not applied now, to keep this phase's diff minimal per its approved scope.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled — 4/4 `$harness-review` checklists, no blocking findings
- [x] Validation passes (`validate_work_item.py --check all`)

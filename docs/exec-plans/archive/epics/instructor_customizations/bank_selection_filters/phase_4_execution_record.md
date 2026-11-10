# Phase 4 Execution Record

Date: 2026-06-30

Ticket: `MER-5624`

## Scope

Implemented the Learning Objective and Question Type filter phase from `implementation_brief.md`.

This phase also corrected the Phase 3 search placement so the search input now lives in the separate advanced filter bar beneath the Show All / Available / Removed controls, matching the Figma structure referenced in the brief.

## Implementation Summary

- Added server-side candidate filter option generation for the current bank selection.
- Learning Objective options are derived from the full current candidate set, including removed questions.
- Question Type options are derived from the full current candidate set, including removed questions.
- Added local multi-select dropdown controls for Learning Objectives and Question Type.
- Combined visibility, text search, LO, and question type filter families with AND semantics through the existing candidate filter contract. Multi-select values within LO and Question Type match any selected option.
- Moved the search input into a separate advanced filter toolbar below the visibility buttons.
- Preserved the existing `Showing X of Y questions` behavior for filtered totals.

## Verification

Commands run:

- `mix format lib/oli/delivery/instructor_customizations.ex lib/oli/delivery/instructor_customizations/target_resolver.ex lib/oli_web/live/delivery/instructor/bank_selection_manager_live.ex test/oli/delivery/instructor_customizations/write_api_test.exs test/oli_web/live/delivery/instructor/bank_selection_manager_live_test.exs`
- `mix test test/oli/delivery/instructor_customizations/write_api_test.exs`
- `mix test test/oli_web/live/delivery/instructor/bank_selection_manager_live_test.exs`

Results:

- Context tests passed.
- LiveView tests passed.

## Notes

- Clear All remains intentionally out of scope for this phase and is reserved for Phase 5.
- The multi-select controls are feature-local because the composed toolbar remains specific to bank selection candidate management.
- Follow-up UI review changed the advanced toolbar to size to its contents instead of forcing full width.
- Multi-select dropdowns now stay open while checkbox selections change, close on click-away, and toggle closed when the same dropdown button is clicked again.
- Learning Objective multi-select now matches any selected LO within that filter family, consistent with Question Type multi-select behavior.
- Empty candidate results now use: `No questions match the selected filters.`

### 2026-02-06 - Add import status endpoint contract to FDD
- Change: Added `GET /api/v1/imports/:id/status` response schema to interface section.
- Reason: Implementation introduced status polling endpoint not represented in spec.
- Evidence: `lib/oli_web/controllers/import_controller.ex`, `test/oli_web/controllers/import_controller_test.exs`
- Impact: Plan Phase 2 verification now includes endpoint contract + auth checks.

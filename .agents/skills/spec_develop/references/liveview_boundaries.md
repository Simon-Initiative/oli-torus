# LiveView Boundaries (Hard Rule)

LiveView modules and LiveComponents are UI-layer code (`OliWeb`).

## Non-negotiable boundary
- Never implement application business logic directly in LiveView modules/components.
- Keep business/domain logic in `Oli` contexts/services, not `OliWeb`.

## What LiveView code is allowed to do
- Handle UI events and route them to context/service calls.
- Manage UI state (`assigns`) and view-only flags (for example, button enabled/disabled state).
- Render UI, validation feedback, loading/empty/error UI states, and navigation flow.
- Translate context results (`{:ok, _}` / `{:error, _}`) into UI outcomes.

## What LiveView code must not do
- Encode business rules, policy decisions, pricing/grade/progression logic, or domain invariants.
- Perform domain data mutation orchestration that belongs in contexts.
- Duplicate domain logic that already exists in `Oli` modules.

## Testing expectations
- LiveView tests verify UI behavior and state transitions (events, assigns effects, rendering states).
- Domain rules are tested in context/service unit/integration tests.
- If a LiveView PR introduces domain logic in `OliWeb`, treat as a blocking issue and refactor.

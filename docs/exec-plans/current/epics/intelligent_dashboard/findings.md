# Intelligent Dashboard Prototype Findings

Last updated: 2026-02-17

## Prototype Scope Recap

This prototype models the data flow from oracles to snapshot to tile projections for two tiles,
including a lightweight in-process cache and a LiveDataController orchestration layer:
- Progress tile (histogram of students per unit/module at a completion threshold).
- Student Support tile (bucketed categories using progress + proficiency, with per-student lists).

It does not implement UI or charts.

## What Was Modeled

- Uniform tile interface with `required_oracles/0` and `optional_oracles/0` (map of slot => oracle module).
- Oracle modules with no inter-oracle dependencies (prototype constraint).
- Snapshot builder that unions oracle dependencies across tiles, loads oracles, and derives tile projections.
- In-process cache keyed by scope + oracle key with read-through behavior.
- LiveDataController that resolves dependencies, reads cache, loads missing oracles,
  writes back to cache, and assembles snapshots.
- Snapshot projection assembly via `project/4` for externally supplied oracle payloads/statuses.
- Tile-specific non-UI projection modules that do joins and categorization.

## Key Findings

1. **A uniform tile interface works best when it is slot-based, not tile-specific.**
   - Each tile declares `required_oracles` and `optional_oracles` as a map of slot names to oracle modules.
   - This avoids ad-hoc fields like `proficiency_oracle` and makes tile dependency introspection consistent.

2. **Snapshot should remain tile-agnostic but dependency-aware.**
   - The snapshot builder can union dependencies from visible tiles and load only those oracles.
   - Snapshot stores oracle payloads keyed by oracle key, plus per-tile projection status.

3. **Global filter should be part of the scope contract and passed to oracles + projections.**
   - The prototype scope carries `container_type`, `container_id`, and `filters`.
   - Progress tile uses this to switch axis: course -> units, unit -> modules.

4. **Cache read-through is a good fit at the LiveDataController layer.**
   - Cache keyed by `(scope, oracle_key)` removes duplicate oracle calls on repeated scope requests.
   - Cache hits vs loads are easy to track for observability and incremental UI feedback.

5. **Joins and categorization belong in tile projection modules, not UI.**
   - Student Support joins enrollments + progress + proficiency by `student_id`.
   - The category rules are evaluated in the tile’s data module, not in UI rendering code.

6. **Student Support needs a flexible rule structure to avoid repeated rule rewrites.**
   - A predicate-based rule DSL (`any`/`all` with progress/proficiency thresholds) enables: 
     - Struggling and excelling definitions,
     - Future parameter customization (MER-5256),
     - Explicit N/A handling when metrics are missing.

## Prototype Data Flow Summary

1. **DB / Analytics** (future): authoritative data sources.
2. **Oracle Layer**: `Progress`, `Proficiency`, `Enrollments`, `Contents` oracles.
3. **LiveDataController**: resolves dependencies, reads cache, loads missing oracles.
4. **Snapshot Layer**: stores oracle payloads/statuses and derives projections.
5. **Projection Layer**: tile-specific non-UI modules compute projections.
6. **Tile UI** (future): consumes projections and renders charts/lists.

## LiveDataCoordinator Fit (Recommended)

- The prototype LiveDataController maps cleanly to the production LiveDataCoordinator role.
- It accepts visible tile keys, resolves combined oracle dependencies via the registry, and performs
  cache read-through for repeated scope requests.
- It should launch oracle loads for required oracles, deliver partial updates for optional oracles,
  and emit readiness events at the tile level.
- Snapshot assembly should be driven by these oracle completion events to keep UI incremental.
- Global filter changes should be mapped to a new `Scope`, which re-triggers dependency resolution
  and snapshot builds.

## Design Recommendations

1. **Introduce a tile registry (or capability registry) that returns: 
   - Tile list
   - Required/optional oracle slots
   - Tile projection module
   This enables dependency introspection without touching UI code.**

2. **Use oracle keys as the canonical identity and keep tile slots as local aliases.**
   - Slots are for tile readability, but the snapshot/cache should key by oracle key.

3. **Keep projection modules separate from tile UI modules.**
   - The prototype data modules map cleanly to future `Oli.InstructorDashboard.DataSnapshot.Projections.*` modules.

4. **Treat rule configuration as data.**
   - Student Support thresholds should live in scope filters or tile config to support customization without code changes.

5. **Progress tile axis selection belongs in projection logic, not in oracles.**
   - The tile should decide whether to show units vs modules based on scope container type.
6. **Keep cache logic outside snapshot projection.**
   - Snapshot remains a pure projection layer; cache decisions stay in the LiveDataController.

## Open Questions

- Should optional oracles load in a separate “enrichment” pass to guarantee fast required render?
- Should Student Support rules be serialized and stored per-instructor or per-section in later phases?
- How should missing proficiency data impact the Student Support bucket definitions beyond `N/A`?

## Next Steps (if promoted to production)

- Replace prototype oracles with real `Oli.Dashboard.Oracle` implementations.
- Move tile projection modules into `Oli.InstructorDashboard.DataSnapshot.Projections.*`.
- Integrate LiveDataCoordinator to build snapshots incrementally by scope.
- Add cache support via `Oli.Dashboard.Cache` and enforce request-token stale suppression.

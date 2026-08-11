# Compatibility and Interop Slice

## Scope

This slice owns group-strategy normalization, placement schema compatibility, export/ingest ordering and rewiring, historical revision safety, and analytics compatibility across Phases 2, 6, and 7.

## Strategy Boundary

Add and document `Oli.Resources.Alternatives.normalize_strategy/1` as the only read normalization boundary:

- `experiment_controlled` -> `experiment_controlled`;
- `upgrade_decision_point` -> `experiment_controlled`;
- supported non-experiment strategies remain unchanged;
- unsupported identifiers fail closed.

New A/B Test group creation and canonical ingest persist `experiment_controlled`. Editing an existing `upgrade_decision_point` group preserves that strategy in its successor revisions. Historical revisions and deployed publications are never rewritten. Placement-local `strategy` is ignored regardless of whether it is absent, matching, conflicting, or unknown; group revision strategy is authoritative.

## Placement and Schema Contract

New placements contain `type`, stable `id`, valid `alternatives_id`, and `children`, and omit `strategy`. Update `priv/schemas/v0-1-0/content-alternatives.schema.json` so `alternatives_id` is required and valid while the legacy strategy property remains permitted but non-authoritative. Keep the parent elements-schema reference intact.

Identity behavior is defined in `design/assignment_rendering_completion.md`: content recreation regenerates element IDs but preserves `alternatives_id`; publication/revision changes and whole-page movement preserve intervention identity.

## Export and Ingest Order

Export each referenced Alternatives Group once with canonical strategy, stable option IDs/labels, and required group content. Ingest performs these steps transactionally:

1. create/normalize all groups before page content rewiring;
2. default a legacy group with no strategy to `user_section_preference`;
3. normalize imported `upgrade_decision_point` to `experiment_controlled`;
4. preserve stable option identities and labels;
5. call the existing Alternatives-group rewiring boundary for every repeated placement;
6. ignore all placement-local strategy values;
7. emit only canonical strategy on subsequent export.

The imported page receives imported group resource IDs. Repeated placements of one source group all point to the same imported group while retaining distinct placement-local content and element identity.

## Existing Content and Experiment Compatibility

- Existing `upgrade_decision_point` revisions remain discoverable, renderable, publishable, and usable by experiments through read-time normalization.
- Editing a legacy group preserves `upgrade_decision_point`; generic resource editing performs no strategy normalization.
- Existing single-decision-point experiment records remain readable during the indivisible implementation, but the old request/report API shape and any temporary adapter must be removed before Gate I.
- Legacy assignments without intervention IDs remain readable as historical decision-point assignments; new runtime writes require intervention identity.
- No feature-specific content backfill, forced author save, republication, or experiment conversion job is introduced.
- Project clone currently shares resource/revision identity. Compatibility tests must prove project and publication scoping prevents cross-project experiment capture.

## Analytics Compatibility

New xAPI attribution fields are optional, and ClickHouse columns are nullable/defaulted so old statements and rows continue to validate/query. Existing attribution role/type values remain supported. Detailed evidence additions are additive and do not change operational truth, which remains PostgreSQL.

## Test Targets

- Unit tests for canonical, legacy alias, and unsupported normalization.
- Authoring tests for implicit surface-owned strategy creation and immutable group strategy.
- Rendering tests for absent, matching, conflicting, and unknown placement-local strategy values.
- JSON Schema fixtures for required/invalid `alternatives_id` and permissive ignored legacy strategy.
- Export/ingest round trips for both strategies, repeated placements, local content, option identity, rewritten group IDs, missing legacy group strategy, and alias canonicalization.
- Historical revision/publication tests proving no mutation, forced save, or republication.
- ClickHouse/xAPI fixtures proving old rows/statements remain valid after additive fields.

## Rollback

Code rollback must continue reading both canonical and legacy aliases while database rollback removes only additive schema. Never roll back by rewriting historical content. ClickHouse rollback drops only the newly added nullable fields/indexes in dependency-safe order.

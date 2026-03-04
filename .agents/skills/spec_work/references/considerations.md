# Considerations

- Keep enhancement scope ticket-sized and explicitly state out-of-scope in chat.
- Use Jira ticket fields and engineering comments as primary requirements source.
- When epic context exists, align implementation decisions with epic constraints.
- Keep technical approach and plan intentionally short; avoid verbose spec drafting.
- Require explicit user approval before implementing.
- Preserve tenant/authz/security expectations and avoid broad refactors.
- Include test strategy and rollout/rollback notes in execution summary.
- Make an explicit scenario-testing decision for each ticket.
- If scenario coverage is needed and supported, add/update coverage with `$spec_scenario`.
- If scenario coverage is needed but unsupported, use `$spec_scenario_expand` first, then `$spec_scenario` (do not silently skip).
- Keep scenario scope at high-level workflows; do not trigger expansion for narrowly scoped one-off details better covered by unit/LiveView/integration tests.

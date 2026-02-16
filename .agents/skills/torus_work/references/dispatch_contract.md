# Dispatch Contract

For every invocation:

1. Make classification explicit with one sentence:
   - `This looks like a <lane> because <reason>.`
2. Execute the selected lane end-to-end:
   - Bug (`fixbug_tdd`): follow `$fixbug`.
   - Enhancement: follow `$spec_work`.
   - New feature: follow `$spec_analyze`.
3. If direct delegation is unavailable, run the delegated lane steps inline.
4. Preserve lane guardrails:
   - Bug lane must keep TDD-first flow.
   - Enhancement lane must keep Jira-MCP intake, brief review gate, and approval-before-implementation.
   - New feature lane must keep PRD validation gate.
5. End with concise summary:
   - lane, artifacts, validation/tests, residual risk.

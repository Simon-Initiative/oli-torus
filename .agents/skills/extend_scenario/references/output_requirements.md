# Output Requirements

When finishing a `spec_scenario_expand` run, report:

1. Gap addressed
- What required scenario coverage was blocked
- Why previous directive support was insufficient

2. Infrastructure changes
- New/updated directive semantics
- Files changed across type/parser/engine/handler/schema/docs/tests

3. Validation and tests
- Commands run
- Pass/fail outcomes
- Any follow-up gaps

4. Downstream usage
- How `spec_scenario` should now author tests using the expanded capability
- Example YAML shape (short snippet)

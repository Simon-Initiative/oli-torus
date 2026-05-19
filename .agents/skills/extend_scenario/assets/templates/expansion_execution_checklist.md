# Scenario Expansion Execution Checklist

- [ ] Gap statement documented (required workflow + unsupported area)
- [ ] Directive design approved (extend existing vs add new)
- [ ] `directive_types.ex` updated
- [ ] `directive_parser.ex` updated
- [ ] `directive_validator.ex` updated (if needed)
- [ ] `engine.ex` dispatch updated
- [ ] handler/ops implementation added or extended
- [ ] `scenario.schema.json` updated
- [ ] schema resolver/validator path updated if required
- [ ] docs updated (`test/support/scenarios/README.md` + topic doc)
- [ ] parser/handler/schema tests added and passing
- [ ] representative scenario YAML added/updated
- [ ] compile + targeted tests run and green

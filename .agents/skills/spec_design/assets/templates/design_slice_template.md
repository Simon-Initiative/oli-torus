# <Slice Name> — Detailed Design

Source Specs:
- PRD: `docs/features/<feature_slug>/prd.md`
- FDD: `docs/features/<feature_slug>/fdd.md`
- Plan (optional): `docs/features/<feature_slug>/plan.md`

## 1. Slice Summary
- Objective: <what this slice delivers>
- In scope: <bounded scope>
- Out of scope: <explicit exclusions>

## 2. AC Coverage
- AC-### (FR-###): <how this slice satisfies it>

## 3. Responsibilities & Boundaries
- Module/component responsibilities:
  - <responsibility>
- Cross-context boundaries:
  - <boundary>

## 4. Interfaces & Signatures
- `<module.function(args)> :: <return>`
- Inputs/outputs:
  - <details>
- Error contracts:
  - <errors>

## 5. Data Flow & Edge Cases
- Main flow:
  1. <step>
- Edge cases:
  - <edge case and behavior>

## 6. Test Plan
- Unit tests:
  - <tests>
- Integration tests:
  - <tests>
- Negative/failure-path tests:
  - <tests>

## 7. Risks & Open Questions
- Risks:
  - <risk -> mitigation>
- Open questions:
  - <question>

## 8. Definition of Done
- [ ] AC mappings are explicit
- [ ] Signatures and failure behavior are concrete
- [ ] Test plan covers happy and edge paths
- [ ] Validator checks pass

# Approach

1. Parse the ticket-sized request and identify intended behavior change.
2. Decide destination mode (`feature-pack` vs `mini-pack`) using routing rules.
3. Draft enhancement doc with explicit scope, ACs, risks, tests, rollout notes, and out-of-scope boundaries.
4. Run enhancement validation gates before implementation.
5. Execute implementation path:
   - Feature-pack: hand off through `spec_design` and `spec_develop`.
   - Mini-pack: complete design+develop inline with this skill.
6. Re-validate docs and summarize implementation and verification status.

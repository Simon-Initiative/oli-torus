# Stage Gates

`master_validate` enforces minimum AC status by stage:

- `fdd_only`: every AC must be at least `verified_fdd`
- `plan_present`: every AC must be at least `verified_plan`
- `implementation_complete`: every AC must be `verified`

Additional hard checks:

- proof refs must resolve to existing files
- anchored refs must resolve to headings
- line refs must point to valid line numbers
- `test` proofs must map to files containing `@ac "AC-###"`
- unknown AC IDs in test annotations fail validation
- duplicate proof objects are not allowed

# Validation

Primary command:

```bash
.agents/scripts/spec_validate.sh --feature-dir <feature_dir> --check fdd
```

This is a hard gate. If validation fails, fix the FDD and re-run before proceeding.
If validation is blocked by environment constraints, instruct the user to run it and list expected pass/fail checks.

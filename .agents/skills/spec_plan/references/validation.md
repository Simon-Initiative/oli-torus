# Validation

Primary command:

```bash
.agents/scripts/spec_validate.sh --feature-dir <feature_dir> --check plan
```

This is a hard gate. If validation fails, fix the plan and re-run before proceeding.
This check enforces numbered phases and Definition of Done coverage for each phase.

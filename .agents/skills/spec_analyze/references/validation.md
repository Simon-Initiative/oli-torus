# Validation

Primary command:

```bash
.agents/scripts/spec_validate.sh --slug <feature_slug> --check prd
```

This is a hard gate. If validation fails, fix the PRD and re-run before proceeding.
If the validator cannot be executed in the current environment, explicitly instruct the user to run the command and report failures before implementation starts.

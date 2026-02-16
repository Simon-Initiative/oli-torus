# Validation

Run spec-pack validation for each affected feature directory:

```bash
.agents/scripts/spec_validate.sh --feature-dir <feature_dir> --check all
```

Hard-gate loop:

1. Run validator.
2. If failures exist, patch docs to resolve failures.
3. Re-run validator.
4. Repeat until green for all affected feature directories.

Do not mark completion while any feature directory fails validation.

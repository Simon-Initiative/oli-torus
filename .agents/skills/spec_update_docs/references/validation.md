# Validation

Run spec-pack validation for each affected feature slug:

```bash
.agents/scripts/spec_validate.sh --slug <feature_slug> --check all
```

Hard-gate loop:

1. Run validator.
2. If failures exist, patch docs to resolve failures.
3. Re-run validator.
4. Repeat until green for all affected slugs.

Do not mark completion while any slug fails validation.

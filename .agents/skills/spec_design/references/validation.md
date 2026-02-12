# Validation

Primary command (entire feature pack):

```bash
.agents/scripts/spec_validate.sh --slug <feature_slug> --check all
```

Additional command (single slice file):

```bash
.agents/scripts/spec_validate.sh --slug <feature_slug> --check design --file docs/features/<feature_slug>/design/<slice_slug>.md
```

Validation is a hard gate. If validation fails, fix docs and re-run before proceeding.

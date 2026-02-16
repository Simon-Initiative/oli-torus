# Validation

Primary command (entire feature pack):

```bash
.agents/scripts/spec_validate.sh --feature-dir <feature_dir> --check all
```

Additional command (single slice file):

```bash
.agents/scripts/spec_validate.sh --feature-dir <feature_dir> --check design --file <feature_dir>/design/<slice_slug>.md
```

Validation is a hard gate. If validation fails, fix docs and re-run before proceeding.

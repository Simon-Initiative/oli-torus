# Input Resolution

Accept any of:

- Explicit feature directory path(s), e.g. `docs/features/docs_import` or `docs/epics/course-authoring/docs_import`.
- Changed file list.
- Branch/diff context.

Resolve feature directories with this order:

1. Use explicit feature directory input when provided.
2. Extract from changed paths matching either:
   - `docs/features/<feature_slug>/...`
   - `docs/epics/<epic_slug>/<feature_slug>/...`
3. If still unknown, infer from nearest touched feature docs or ask the user for the feature directory path.

Useful commands:

```bash
git diff --name-only <base>...HEAD
git diff --name-only -- docs/features docs/epics
```

If multiple feature directories are affected, process all of them.

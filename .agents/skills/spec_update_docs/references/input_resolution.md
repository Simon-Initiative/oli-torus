# Input Resolution

Accept any of:

- Explicit feature slug(s), e.g. `docs_import`.
- Changed file list.
- Branch/diff context.

Resolve slugs with this order:

1. Use explicit slug input when provided.
2. Extract from changed paths matching `docs/features/<slug>/...`.
3. If still unknown, infer from nearest touched feature docs or ask user for the slug.

Useful commands:

```bash
git diff --name-only <base>...HEAD
git diff --name-only -- docs/features
```

If multiple slugs are affected, process all of them.

# Routing

Use this order to choose where the enhancement doc lives:

1. If user provides an explicit feature directory path, use it.
2. Else search both `docs/features/` and `docs/epics/*/` for a confident match:
   - Ticket key appears in existing docs.
   - Folder/topic names clearly align with request keywords.
   - No competing folder with similar confidence.
3. If confidence is low or ambiguous, use mini-pack mode.

Destinations:

- Feature-pack mode:
  - `<feature_dir>/enhancements/<jira-key>.md`
  - Supported roots:
    - `docs/features/<feature_slug>/`
    - `docs/epics/<epic_slug>/<feature_slug>/`
- Mini-pack mode:
  - `docs/work/<jira-key>/enhancement.md`

Confidence is high when at least one explicit signal exists and there is no close competing candidate.

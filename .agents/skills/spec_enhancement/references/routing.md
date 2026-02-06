# Routing

Use this order to choose where the enhancement doc lives:

1. If user provides an explicit feature slug, use it.
2. Else search `docs/features/` for confident match:
   - Ticket key appears in existing docs.
   - Folder/topic names clearly align with request keywords.
   - No competing folder with similar confidence.
3. If confidence is low or ambiguous, use mini-pack mode.

Destinations:

- Feature-pack mode:
  - `docs/features/<feature_slug>/enhancements/<jira-key>.md`
- Mini-pack mode:
  - `docs/work/<jira-key>/enhancement.md`

Confidence is high when at least one explicit signal exists and there is no close competing candidate.

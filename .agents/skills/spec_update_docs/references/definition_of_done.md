# Definition of Done

Spec maintenance is done only when:

- Affected feature slug(s) are explicitly identified.
- PRD/FDD/plan changes match implementation reality.
- Each materially changed spec doc includes a decision entry.
- No unresolved `TODO` / `TBD` / `FIXME` markers are introduced.
- `.agents/scripts/spec_validate.sh --slug <feature_slug> --check all` passes for every affected slug.

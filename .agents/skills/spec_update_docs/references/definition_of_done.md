# Definition of Done

Spec maintenance is done only when:

- Affected feature directory path(s) are explicitly identified.
- PRD/FDD/plan changes match implementation reality.
- Each materially changed spec doc includes a decision entry.
- No unresolved `TODO` / `TBD` / `FIXME` markers are introduced.
- `.agents/scripts/spec_validate.sh --feature-dir <feature_dir> --check all` passes for every affected feature directory.

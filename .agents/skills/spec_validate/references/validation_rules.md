# Validation Rules

Core checks implemented by `scripts/validate_spec_pack.py`:

- Required headings exist for each artifact type.
- No unresolved `TODO` / `TBD` / `FIXME` markers.
- Acceptance criteria count is greater than zero for PRD and design docs.
- Plan phases are numbered (`Phase <n>`) and each phase includes a `Definition of Done` block.
- Markdown links are validated:
  - Local file links must resolve.
  - Local anchors must exist.
  - External links are syntax-checked by default and can be network-checked with `--check-external-links`.

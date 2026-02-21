# Validation Rules

Core checks implemented by `scripts/validate_spec_pack.py`:

- Required headings exist for each artifact type.
- No unresolved `TODO` / `TBD` / `FIXME` markers.
- PRD requirements traceability is present:
  - either inline `AC-###` IDs exist, or
  - sections `6` and `7` both contain `Requirements are found in requirements.yml` and `<feature_dir>/requirements.yml` exists.
- Design docs must still include inline `AC-###` references.
- Plan phases are numbered (`Phase <n>`) and each phase includes a `Definition of Done` block.
- Markdown links are validated:
  - Local file links must resolve.
  - Local anchors must exist.
  - External links are syntax-checked by default and can be network-checked with `--check-external-links`.

# Validation

Primary command (all modes):

```bash
python3 .agents/skills/spec_enhancement/scripts/validate_enhancement_doc.py <enhancement_doc_path>
```

Feature-pack command (required for `<feature_dir>/...`):

```bash
.agents/scripts/spec_validate.sh --feature-dir <feature_dir> --check all
```

Rules:

- Both commands are hard gates in feature-pack mode.
- Enhancement-doc validation is a hard gate in mini-pack mode.
- If any validation fails, fix docs and re-run before proceeding.
- If commands cannot run in the environment, instruct the user to run them and do not claim completion.

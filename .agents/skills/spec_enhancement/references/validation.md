# Validation

Primary command (all modes):

```bash
python3 .agents/skills/spec_enhancement/scripts/validate_enhancement_doc.py <enhancement_doc_path>
```

Feature-pack command (required for `docs/features/<feature_slug>/...`):

```bash
.agents/scripts/spec_validate.sh --slug <feature_slug> --check all
```

Rules:

- Both commands are hard gates in feature-pack mode.
- Enhancement-doc validation is a hard gate in mini-pack mode.
- If any validation fails, fix docs and re-run before proceeding.
- If commands cannot run in the environment, instruct the user to run them and do not claim completion.

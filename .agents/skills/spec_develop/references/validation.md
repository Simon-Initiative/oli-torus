# Validation

Run technical validation first (compile/tests), then spec validation.
For this skill, spec validation is a hard gate and must run twice: preflight (before coding) and postflight (after implementation/doc updates).

Example commands:

```bash
mix compile
mix test
.agents/scripts/spec_validate.sh --slug <feature_slug> --check all
```

If either validation run fails, stop and fix docs before proceeding.
If any command cannot run in the environment, report it explicitly and instruct the user to run it.

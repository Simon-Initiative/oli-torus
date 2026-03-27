---
name: manual_testing_validate
description: >
  Validate or lint manual testing case, suite, and run documents for the automated testing experiment by calling `manual_testing/tools/manualtest.py`. Use when the agent already has explicit file paths and needs deterministic schema or lint checks before execution preparation or result handling.
---

## Purpose
Run deterministic validation or lint checks for `manual_testing/` artifacts before the advanced runtime prepares or executes a run.

## Required Inputs
- explicit file path to a case, suite, or run document
- optional explicit type override: `case`, `suite`, or `run`
- desired check mode:
  - `validate` for schema validation
  - `lint` for schema validation plus duplicate-ID and path checks

Human-to-agent message parsing is out of scope. This skill starts from explicit structured inputs only.

## Workflow
1. Confirm the target file path exists and is one of:
   - `manual_testing/cases/**/*.yml`
   - `manual_testing/suites/*.yml`
   - `manual_testing/results/**/report.json`
2. Use the repository utility directly:
   - validation:
     - `python3 manual_testing/tools/manualtest.py validate <path> [--type case|suite|run]`
   - lint:
     - `python3 manual_testing/tools/manualtest.py lint <path> [--type case|suite|run]`
3. Treat JSON stdout as the canonical machine-readable result.
4. If the command exits non-zero:
   - surface the actionable error or lint issues
   - do not continue into execution preparation or result normalization until the issue is resolved

## Output Contract
- For validation: return the JSON payload or a concise summary of the validation failure.
- For lint: return the JSON payload and call out any issues that block safe execution.

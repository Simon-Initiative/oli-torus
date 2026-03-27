# Torus Manual Test Automation (Agent-Driven) – V1 PRD

## Overview

This document defines a minimal, practical V1 system for executing manual regression test cases using an AI Agent (e.g. OpenClaw).

The goal of V1 is to:

- Execute structured manual test cases defined in YAML
- Produce structured test run reports
- Validate schemas via Python tooling
- Support importing existing spreadsheet-based test cases
- Store test run results in S3

This version is intentionally limited in scope to enable rapid prototyping and iteration.

---

## Goals

### Primary Goals

- Replace manual execution of regression test scripts with Agent execution
- Provide a structured, machine-readable format for test cases
- Generate consistent, structured test run reports
- Enable batch execution via test suites
- Persist results to S3 for later inspection

### Non-Goals (V1)

- No real-time monitoring UI
- No credential management system
- No CI/CD integration
- No parallel orchestration (single-agent execution is acceptable)
- No advanced environment modeling

---

## Core Concepts

### Test Case

A structured definition of a manual test, including:
- steps to perform
- expected outcomes
- metadata

### Test Case Run

A structured record of a single execution of a test case.

### Test Suite

A collection of test cases to be executed together.


---

### Ideal, Envisioned Workflow

- Agent is set up with read only access to this GitHub repository, containing docs and test cases and test case utilities
- Agent is given a set of user credentials for staging and dev servers used for testing
- Agent receives a command from Slack, Telegram or GitHub workflow to perform a test case suite run
- Agent checks out corresponding tag or branch of repository
- Agent executes each test, by driving a browser, on the target staging or dev server
- Agent captures results in a "test case run" for each test case and uploads it into S3 bucket

---

## System Components

### 1. Test Case Definitions (YAML)

Stored in repository.

### 2. Agent Skills

- Execute test case
- Execute test suite
- Convert CSV/spreadsheet to test case YAML
- Validate test cases

### 3. Python CLI Tooling

Provides:
- schema validation
- linting
- conversion utilities
- report generation

### 4. S3 Storage

Stores:
- test run results (JSON)
- artifacts (screenshots optional in V1)

---

## File Structure (Proposed)

```
manual_testing/
  schemas/
    test_case.schema.json
    test_run.schema.json
    test_suite.schema.json

  cases/
    authoring/
    delivery/

  suites/
    regression.yml

  tools/
    manualtest.py

  results/ (local temp)
```


---

## Schema Definitions (Minimal V1)

### Test Case Schema (YAML)

```
id: string
title: string
description: string (optional)

tags:
  - string

preconditions:
  - string

steps:
  - id: string
    instruction: string

expected:
  - id: string
    description: string

notes:
  - string (optional)
```

---

### Test Case Run Schema (JSON)

```
{
  "run_id": "string",
  "test_id": "string",
  "status": "passed | failed | blocked | error",
  "started_at": "ISO timestamp",
  "completed_at": "ISO timestamp",
  "duration_seconds": number,

  "steps": [
    {
      "step_id": "string",
      "instruction": "string",
      "status": "passed | failed | skipped",
      "notes": "string (optional)"
    }
  ],

  "assertions": [
    {
      "assertion_id": "string",
      "description": "string",
      "status": "passed | failed | unverified",
      "observed": "string (optional)"
    }
  ],

  "agent_notes": [
    "string"
  ],

  "confidence": number
}
```

---

### Test Suite Schema (YAML)

```
id: string
title: string

tests:
  - path/to/test_case_1.yml
  - path/to/test_case_2.yml

tags:
  - string (optional)
```

---

## Agent Skills

### 1. Execute Test Case

Input:
- test case file path
- target base URL
- Pointers to key Torus docs (from this repo) so that the Agent understand the system, the concepts, key user classess and key flows

Responsibilities:
- read repository documentation
- read test case YAML
- execute steps in browser
- evaluate expected outcomes
- capture structured results
- output test run JSON

---

### 2. Execute Test Suite

Input:
- suite file

Responsibilities:
- iterate through test cases
- execute each test case sequentially
- collect results

---

### 3. Convert CSV → Test Case

Input:
- CSV file (exported spreadsheet)

Responsibilities:
- parse rows
- convert to YAML test cases
- preserve raw text
- split steps and expected results

---

### 4. Validate Test Case

Responsibilities:
- validate against schema
- ensure required fields present
- ensure IDs are unique
- detect malformed structures

---

### 5. Lint Test Case (Optional but Recommended)

Responsibilities:
- detect vague steps
- detect missing expected assertions
- warn about overly large tests
- suggest improvements

---

## Python CLI Tooling

manualtest <command>

Commands:

Validate:
manualtest validate case <file.yml>
manualtest validate suite <file.yml>

Lint:
manualtest lint <file.yml>

Convert CSV:
manualtest from-csv input.csv --out cases/

Run Test Case:
manualtest run case <file.yml> --base-url <url>

Run Suite:
manualtest run suite <suite.yml> --base-url <url>

---

## Execution Flow

Single Test Case:
1. Load YAML
2. Validate schema
3. Agent executes steps
4. Agent evaluates expected outcomes
5. Generate test run JSON
6. Upload to S3

Suite Execution:
1. Load suite
2. Validate suite schema
3. Iterate tests
4. Execute each test case
5. Upload results per test

---

## S3 Storage Design

s3://torus-manual-tests/
  runs/
    <run_id>/
      test-results/
        AUTH-001.json
        AUTH-002.json

Behavior:
- Each test produces one JSON file
- Upload immediately after execution

---

## Run Identification

Example:
2026-03-26_run_001

---

## Error Handling

Statuses:
- passed
- failed
- blocked
- error

Agent should:
- capture notes
- continue execution

---

## Minimal Success Criteria (V1)

- Agent executes 10+ real tests
- JSON reports generated
- Results uploaded to S3
- CSV conversion works
- Schema validation enforced

---

## Future Work

- Credential management (Secrets Manager, Vault)
- GitHub CI integration
- Parallel execution
- Static monitoring UI
- Environment modeling
- Flake detection
- Improved test authoring tools

---

## Summary

This V1 system provides:

- YAML test definitions
- Agent execution
- structured JSON results
- schema validation
- S3 persistence

Designed for fast iteration and proof of concept.

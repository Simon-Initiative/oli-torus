# <Feature Name> — Delivery Plan

Scope and guardrails reference:
- PRD: `<feature_dir>/prd.md`
- FDD: `<feature_dir>/fdd.md`

## Scope
<concise delivery scope>

## Scenario Testing Contract
- Status: <Required | Suggested | Not applicable>
- Infrastructure Support Status: <Supported | Unsupported>
- Scenario Infrastructure Expansion Required: <Yes | No>
- Scope (AC/workflows): <what scenario tests must/should cover, or `N/A`>
- Planned Artifacts: <`.scenario.yaml` files and runner modules, or `N/A`>
- Validation Commands: <schema + parser/test commands, or `N/A`>
- Skill Handoff: <if expansion required: `Use $spec_scenario_expand first, then $spec_scenario`>

## LiveView Testing Contract
- Status: <Required | Suggested | Not applicable>
- Scope (events/states): <what LiveView tests must/should cover, or `N/A`>
- Planned Artifacts: <LiveView test module(s), or `N/A`>
- Validation Commands: <targeted `mix test ...`, or `N/A`>

## Non-Functional Guardrails
- <budget/constraint>

## Clarifications & Default Assumptions
- <assumption>

## Phase 1: <Name>
- Goal: <goal>
- Tasks:
  - [ ] <task>
- Testing Tasks:
  - [ ] <tests to write/run>
  - Command(s): `<mix test ...>`
  - [ ] <scenario authoring/validation tasks when contract is Required or Suggested>
  - [ ] <LiveView test authoring/validation tasks when contract is Required or Suggested>
- Definition of Done:
  - <phase completion conditions>
- Gate:
  - <gate condition>
- Dependencies:
  - <none or prerequisite phases/tasks>
- Parallelizable Work:
  - <safe concurrent tasks>

## Phase 2: <Name>
- Goal: <goal>
- Tasks:
  - [ ] <task>
- Testing Tasks:
  - [ ] <tests to write/run>
  - Command(s): `<mix test ...>`
  - [ ] <scenario authoring/validation tasks when contract is Required or Suggested>
  - [ ] <LiveView test authoring/validation tasks when contract is Required or Suggested>
- Definition of Done:
  - <phase completion conditions>
- Gate:
  - <gate condition>
- Dependencies:
  - <prerequisite phases/tasks>
- Parallelizable Work:
  - <safe concurrent tasks>

## Parallelisation Notes
- <parallel tracks and dependencies>

## Phase Gate Summary
- Gate A: <condition>
- Gate B: <condition>

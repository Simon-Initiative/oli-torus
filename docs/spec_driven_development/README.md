# Spec-Driven Development (SDD)

## Purpose

We now build software in an AI-agentic environment.

In this environment:
- Output quality is determined by input clarity.
- Ad hoc prompting produces inconsistent results.
- Ephemeral prompts create no durable knowledge.
- Planning and implementation can drift without structure.

Spec-Driven Development (SDD) formalizes intent into structured,
version-controlled artifacts that guide LLM-powered implementation.

SDD is our standard workflow for feature development.

## Core Workflow

SDD converts informal intent into durable artifacts and structured
implementation.

``` mermaid
%%{init: {'flowchart': {'nodeSpacing': 5, 'rankSpacing': 20}}}%%
flowchart TD

J[Informal Description]

J --> SA([`spec_analyze`])
SA --> PRD[/prd.md/]

PRD --> RPRD[Review / Revise]
RPRD --> SAR([`spec_architect`])
SAR --> FDD[/fdd.md/]

FDD --> RFDD[Review / Revise]
PRD --> SP([`spec_plan`])
RFDD --> SP
SP --> PLAN[/plan.md/]
PLAN --> RPLAN[Review / Revise]

PRD --> SD([`spec_develop`])
RFDD --> SD
RPLAN --> SD
SD -->|repeat for each plan phase| SD
SD --> REVIEW[Review]
REVIEW --> QA[QA]
QA --> OPEN[Open PR]

classDef artifact fill:#fff7d1,stroke:#cfa74a,stroke-width:2px,color:#3b2b00;
class PRD,FDD,PLAN artifact;
classDef skill fill:#dff5df,stroke:#2e7d32,stroke-width:2px,color:#1b5e20;
class SA,SAR,SP,SD skill;
classDef manual fill:#f8e1ff,stroke:#8e44ad,stroke-width:2px,color:#4a235a;
class RPRD,RFDD,RPLAN,REVIEW,QA,OPEN manual;
```

Legend: Yellow nodes are artifacts, green nodes are spec skills, and light magenta nodes are manual steps.

### Workflow Summary

-   `spec_analyze` → Informal description → PRD
-   `spec_architect` → PRD → FDD
-   `spec_plan` → PRD + FDD → Phased Plan
-   `spec_develop` → Plan (with PRD + FDD context) → Code


Each step:
- Produces a durable artifact.
- Increases structure.
- Reduces ambiguity.
- Improves LLM output quality.

Artifacts are checked into the repository. Informal description is JIRA description + comments, Figma links, your additional commentary.

## Artifact Structure

All artifacts live under `docs/`.

### Features

    docs/
      features/
        feature-slug/
          prd.md
          fdd.md
          plan.md

-   Directory names use a descriptive feature slug (not a Jira ticket
    number).
-   Artifacts remain permanently discoverable.
-   Code and documentation evolve together.

### Epics

    docs/
      epics/
        epic-slug/
          feature_slug1/
          feature_slug2/
          overview.md
          plan.md
          edd.md

Epic plans organize stories into lanes and define execution structure.

## Lanes Model

A lane is a cohesive set of related stories owned end-to-end by a single
engineer.  Lanes are documented at the epic level in `overview.md` and `plan.md`

Purpose:
- Preserve context.
- Reduce cross-ticket cognitive reload.
- Improve execution velocity.
- Clarify dependencies.

``` mermaid
%%{init: {'flowchart': {'nodeSpacing': 5, 'rankSpacing': 16}}}%%
flowchart TB
subgraph Lanes[" "]
  direction LR
Lane1["Lane 1"]
Lane2["Lane 2"]
Lane3["Lane 3"]
Lane4["Lane 4"]
Lane5["Lane 5"]

Lane1 -->|depends on| Lane2
Lane2 --> Lane4
Lane3 --> Lane4
Lane4 --> Lane5
end

classDef immediate fill:#dff5df,stroke:#2e7d32,stroke-width:1px,color:#1b5e20;
class Lane1,Lane3 immediate;
style Lanes fill:transparent,stroke:transparent;
```


**Note:** Engineers take ownership of lanes, not isolated tickets.

Legend: Light green lane nodes indicate lanes with no inbound dependencies and can be started immediately.


## Skills Overview

Core Workflow:

-   `spec_analyze` -- Converts informal feature description into
    structured PRD.
-   `spec_architect` -- Converts PRD into Feature Design Document (FDD).
-   `spec_plan` -- Converts PRD + FDD into phased implementation plan.
-   `spec_develop` -- Implements a specific phase using all prior
    artifacts.

Supporting Skills:

-   `spec_validate` -- Validates artifact structure and completeness.
-   `spec_work` -- Lightweight plan + implement workflow for small
    tickets.
-   `spec_fixbug` -- TDD-first targeted bugfix workflow from Jira.
-   `spec_update_docs` -- Ensures documentation reflects implemented code.
-   `spec_review` -- Does a detailed code review using CI review guidelines
-   `spec_prototype` -- Build a quick, throwaway prototype, with no docs, no tests

To be developed (soon) Skills:
- `spec_scenario` -- Creates an `Oli.Scenarios` based non-UX integration test
- `spec_playwright` -- Creates a UI based Playwright automation test
- `spec_epic` -- Supports epic planning, epic docs creation from JIRA tickets

Other upcoming existing Skill enhancements:
- Improve requirements traceability
- Better support for feature flag, canary deployment
- Cleaner story for telemetry and AppSignal reporting needs


Skills are reusable, version-controlled capabilities defined at the
project level (under `.agents/skills`). They replace ad hoc prompting with structured, shared workflows.

## Ticket Classification

During pre-planning, tickets are marked as:

-   Feature → Requires full SDD workflow.
-   Non-Feature → Use `spec_work`.

Not every Jira story requires full PRD/FDD/Plan artifacts. Only
sufficiently complex or high-impact work is treated as a Feature.

This classification occurs before implementation begins.

## Required Expectations

For Features:
- PRD must exist.
- FDD must exist.
- Phased plan must exist.
- Implementation must follow defined phases.
- Documentation must remain aligned with code.

For Non-Feature Tickets:
- Use `spec_work`.
- Follow structured but lightweight execution.

Starting with Version 33, SDD is our required development model.

## Why This Matters

SDD provides:

-   Durable institutional memory.
-   Structured thinking before implementation.
-   Higher quality LLM output.
-   Clear execution ownership.
-   Reduced planning drift.
-   Better scaling across distributed teams.

We are not replacing engineering judgment. We are amplifying it through
structure.

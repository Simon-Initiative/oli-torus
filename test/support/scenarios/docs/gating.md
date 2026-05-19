# Gating and Scheduling

This document covers directives and assertions for advanced gating workflows in sections.

## Table of Contents
- [Overview](#overview)
- [gate](#gate) - Create top-level gates and student-specific exceptions
- [time](#time) - Override scenario-local current time
- [gating assertions](#gating-assertions) - Verify persisted gate config and learner access outcomes
- [Examples](#examples)
- [Current coverage notes](#current-coverage-notes)

---

## Overview

These directives support deterministic section gating workflows without dropping to hooks or UI tests.

Use them when you need to:
- create a top-level gate for a target resource
- create a student-specific exception that overrides a parent gate
- simulate schedule-based gating at exact timestamps
- assert whether a learner can access a gated resource
- assert that a persisted gate has the expected type, target, source, threshold, or schedule window

The current scenario support covers the gate types exercised by the advanced gating manual cases:
- `schedule`
- `started`
- `finished`
- `always_open`

---

## gate

Creates a gating condition for a section. A `gate` directive can either create:
- a top-level gate that applies section-wide
- a student-specific exception linked to a parent gate

### Parameters
- `name`: Scenario-local identifier for the gate (optional but recommended)
- `section`: Section name (required)
- `target`: Target resource title in the section (required for top-level gates; optional for exceptions that inherit the parent target)
- `type`: Gate type (required)
- `source`: Source resource title for `started` and `finished` gates
- `start`: Start datetime for `schedule` gates
- `end`: End datetime for `schedule` gates
- `minimum_percentage`: Threshold for `finished` gates
- `student`: Learner name for a student-specific exception
- `parent`: Parent gate name for a student-specific exception
- `graded_resource_policy`: Optional graded-resource policy, typically `allows_review`

### Supported types
- `schedule`
- `started`
- `finished`
- `always_open`

### Top-level gate example

```yaml
- gate:
    name: "schedule_gate"
    section: "gating_section"
    target: "Locked Page"
    type: "schedule"
    start: "2026-01-11T12:00:00Z"
    end: "2026-01-12T12:00:00Z"
```

### Student exception example

```yaml
- gate:
    name: "alice_exception"
    section: "gating_section"
    parent: "schedule_gate"
    student: "alice"
    type: "always_open"
```

### Override example

This replaces the parent gate semantics for one learner:

```yaml
- gate:
    name: "base_started_gate"
    section: "gating_section"
    target: "Locked Page"
    type: "started"
    source: "Source Quiz"

- gate:
    name: "alice_finished_exception"
    section: "gating_section"
    parent: "base_started_gate"
    student: "alice"
    type: "finished"
    source: "Source Quiz"
    minimum_percentage: 0.8
```

---

## time

Sets the scenario-local current time. This is required for deterministic `schedule`-gate coverage.

### Parameters
- `at`: ISO8601 datetime (required)

### Example

```yaml
- time:
    at: "2026-01-10T12:00:00Z"
```

The override applies to subsequent directive execution within the scenario run. It is reset after scenario execution completes.

---

## gating assertions

Use `assert.gating` to verify either:
- persisted gate configuration
- effective learner access to a resource

You can use the same assertion shape for either mode.

### Persisted gate checks

Supported fields:
- `gate`: Named gate from a prior `gate` directive
- `section`: Section name when resolving by filters instead of a named gate
- `type`
- `target`
- `source`
- `minimum_percentage`
- `start`
- `end`
- `student`

#### Named gate example

```yaml
- assert:
    gating:
      gate: "finished_gate"
      type: "finished"
      target: "Locked Page"
      source: "Source Quiz"
      minimum_percentage: 0.8
```

#### Filtered lookup example

```yaml
- assert:
    gating:
      section: "gating_section"
      type: "started"
      target: "Locked Page"
      source: "Warmup Page"
```

### Effective access checks

Supported fields:
- `section`: Section name
- `student`: Learner name
- `resource`: Target resource title
- `accessible`: `true` or `false`
- `blocking_types`: Expected blocking gate types when access is denied
- `blocking_count`: Expected number of blocking gates

#### Access example

```yaml
- assert:
    gating:
      section: "gating_section"
      student: "alice"
      resource: "Locked Page"
      accessible: false
      blocking_types: ["started"]
      blocking_count: 1
```

### Failure behavior

`assert.gating` produces normal scenario verification failures when:
- no matching gate can be resolved
- multiple gates match a filtered lookup
- persisted gate properties do not match
- learner access or blocking details do not match

This keeps gating checks readable in YAML-driven scenario failures.

---

## Examples

### Schedule gate workflow

```yaml
- time:
    at: "2026-01-10T12:00:00Z"

- gate:
    name: "schedule_gate"
    section: "gating_section"
    target: "Locked Page"
    type: "schedule"
    start: "2026-01-11T12:00:00Z"
    end: "2026-01-12T12:00:00Z"

- assert:
    gating:
      section: "gating_section"
      student: "alice"
      resource: "Locked Page"
      accessible: false
      blocking_types: ["schedule"]
      blocking_count: 1

- time:
    at: "2026-01-11T18:00:00Z"

- assert:
    gating:
      section: "gating_section"
      student: "alice"
      resource: "Locked Page"
      accessible: true
      blocking_count: 0
```

### Started gate workflow

```yaml
- gate:
    name: "started_gate"
    section: "gating_section"
    target: "Locked Page"
    type: "started"
    source: "Warmup Page"

- assert:
    gating:
      section: "gating_section"
      student: "alice"
      resource: "Locked Page"
      accessible: false
      blocking_types: ["started"]
      blocking_count: 1

- visit_page:
    student: "alice"
    section: "gating_section"
    page: "Warmup Page"

- assert:
    gating:
      section: "gating_section"
      student: "alice"
      resource: "Locked Page"
      accessible: true
      blocking_count: 0
```

### Finished gate workflow

```yaml
- gate:
    name: "finished_gate"
    section: "gating_section"
    target: "Locked Page"
    type: "finished"
    source: "Source Quiz"
    minimum_percentage: 0.8

- visit_page:
    student: "alice"
    section: "gating_section"
    page: "Source Quiz"

- complete_scored_page:
    student: "alice"
    section: "gating_section"
    page: "Source Quiz"
    score: 4
    out_of: 5

- assert:
    gating:
      section: "gating_section"
      student: "alice"
      resource: "Locked Page"
      accessible: true
      blocking_count: 0
```

### Always-open exception workflow

```yaml
- gate:
    name: "schedule_gate"
    section: "gating_section"
    target: "Locked Page"
    type: "schedule"
    start: "2026-01-11T12:00:00Z"
    end: "2026-01-12T12:00:00Z"

- gate:
    name: "alice_exception"
    section: "gating_section"
    parent: "schedule_gate"
    student: "alice"
    type: "always_open"

- assert:
    gating:
      section: "gating_section"
      student: "alice"
      resource: "Locked Page"
      accessible: true
      blocking_count: 0
```

---

## Current coverage notes

The current representative scenario suite for advanced gating is in:
- `test/scenarios/gating/`

Current scenario coverage focuses on the manual advanced gating cases documented for:
- schedule gates
- started gates
- finished gates with thresholds
- always-open exceptions
- student-specific override exceptions

Broader `progress`-gate scenario coverage is not part of this slice.

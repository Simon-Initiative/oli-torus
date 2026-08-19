# Automation Workflows

This document defines the v1 workflow contract for Playwright automation that alternates scenario-driven setup/assertions with browser-driven actions.

## Purpose

The workflow layer exists for cases where a single browser spec needs more than a one-time scenario seed. The primary pattern is:

1. run one scenario to create deterministic state
2. run one or more Playwright browser actions
3. run one or more scenarios to validate the resulting state

The first intended consumer was mixed-content authoring coverage, but the contract is reusable for later automation slices.

## Relationship To Existing Fixtures

The existing `seedScenario(...)` helper remains supported for tests that only need one scenario setup step.

The workflow layer extends the fixture surface with a new helper, expected to be named `runWorkflow(...)`, rather than replacing `seedScenario(...)`.

This keeps:

- simple setup-only tests simple
- workflow-driven tests explicit
- backwards compatibility intact for existing specs

## v1 Constraints

The v1 workflow runner is intentionally narrow.

Supported:

- linear ordered execution
- arbitrary number of steps
- fail-fast behavior
- serializable per-step outputs
- step parameter interpolation from global params and prior outputs

Not supported in v1:

- branching
- loops
- parallel execution
- top-level `hook` workflow steps
- arbitrary shell commands
- arbitrary Playwright spec-name execution by string

If custom logic is needed in a scenario phase, use the existing `hook:` directive inside the scenario file rather than adding a top-level workflow hook step.

## Step Types

### `scenario`

Executes a scenario YAML file through the existing internal scenario test endpoint.

Shape:

```yaml
scenario:
  file: 'setup.scenario.yaml'
  params:
    run_id: '${RUN_ID}'
```

### `playwright_action`

Executes a named browser action from a local TypeScript action registry.

Shape:

```yaml
playwright_action:
  action: 'author_image_group'
  params:
    project_slug: '${setup.outputs.projects.authoring_project}'
```

The workflow contract deliberately refers to an action name, not an arbitrary Playwright spec or test string. This keeps the DSL stable even if file organization changes.

## Workflow Shape

Top-level shape:

```yaml
workflow:
  - id: setup
    scenario:
      file: 'setup.scenario.yaml'

  - id: author_image
    playwright_action:
      action: 'author_image_group'

  - id: assert_preview
    scenario:
      file: 'assert_author_preview.scenario.yaml'
```

Rules:

- `workflow` is an ordered list
- each step must have an `id`
- each step must declare exactly one step type
- step ids must be unique within the workflow

## Arbitrary Step Count

`runWorkflow(...)` is not restricted to a fixed three-step shape such as `before -> browser -> after`.

These are all valid design intents:

- one step
- three steps
- fifteen steps

Example:

```yaml
workflow:
  - id: setup
    scenario:
      file: 'setup.scenario.yaml'

  - id: author_inline
    playwright_action:
      action: 'author_inline_group'

  - id: assert_inline
    scenario:
      file: 'assert_inline.scenario.yaml'

  - id: author_table
    playwright_action:
      action: 'author_table_group'

  - id: assert_table
    scenario:
      file: 'assert_table.scenario.yaml'
```

The only v1 restriction is that execution is linear and sequential.

## Shared State And Outputs

The runner owns a serializable workflow state made of:

- global params
- per-step outputs

Conceptually:

```ts
type WorkflowState = {
  params: Record<string, unknown>;
  steps: Record<string, { outputs: Record<string, unknown> }>;
};
```

Each step can emit small outputs that later steps consume.

Examples:

- scenario setup outputs:
  - `projects.authoring_project`
  - `sections.delivery_section`
  - `users.author_email`
- Playwright action outputs:
  - `page_slug`
  - `page_title`
  - `variant`

Avoid returning large or non-serializable payloads.

## Interpolation

Step params may reference:

- workflow-global params
- outputs from prior steps

Examples:

```yaml
params:
  run_id: '${RUN_ID}'
  section_slug: '${setup.outputs.sections.delivery_section}'
  page_slug: '${author_image.outputs.page_slug}'
```

Interpolation in v1 is intentionally simple:

- placeholder substitution only
- no computed expressions
- no conditional logic

Missing references are treated as configuration errors and should fail the workflow before step execution.

## Failure Behavior

The runner is fail-fast by default.

If any step fails:

- the workflow stops
- later steps do not run
- the error should report:
  - workflow path or id
  - step id
  - step type
  - resolved params where safe to print
  - underlying scenario or browser error

## Recommended Usage

Use a workflow when:

- a test needs more than a one-time scenario setup
- browser actions must be followed by scenario-based assertions
- state must move across several setup/mutate/assert phases

Use `seedScenario(...)` directly when:

- a test only needs deterministic setup before browser interaction
- there is no scenario-based post-browser assertion phase

## Example Mixed Content Pattern

Representative shape:

```yaml
workflow:
  - id: setup
    scenario:
      file: 'mixed_workflow/setup.scenario.yaml'

  - id: author_codeblock
    playwright_action:
      action: 'author_codeblock_group'

  - id: assert_codeblock
    scenario:
      file: 'mixed_workflow/assert_codeblock.scenario.yaml'

  - id: author_image
    playwright_action:
      action: 'author_image_group'

  - id: assert_image
    scenario:
      file: 'mixed_workflow/assert_image.scenario.yaml'
```

This proves:

- repeated alternation between scenario and browser steps
- arbitrary linear step count
- reusable outputs between phases
- browser-independent assertions after authoring mutations

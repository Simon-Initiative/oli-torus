---
description: Create a new Scenario based integration test
---

`Oli.Scenarios` is a YAML based DSL for authoring complex integration
style unit tests in the Torus codebase.  The core implementation is found
in directory `./test/support/scenarios`.  For a complete understanding of
`Oli.Scenarios` and the directives available you must read and carefully study
`./test/support/scenarios/README.md`.  Consult the core implementation also if needed.

Scenario based unit tests are used to test the following types of workflows:
- Publishing changes from a project to course section built from them
- Course section remix functionality
- Course section customization functionality
- Creation of course sections from products
- And also more complex patterns involving combinations of any or all of the above

Good examples of real Scenarios that you can consult are:
- `./test/oli/delivery/major_updates/product_section_update_restriction.scenario.yaml`
- `./test/oli/delivery/major_updates/add_new_content.scenario.yaml`

When creating a new Scenario, you must create a file name with a `.scenario.yaml`
ending, which allows the "universal runner" that must also exist in that directory to find and execute the scenario. If the "universal runner" test file does not exist
in the directory where you are creating the scenario, you will need to create that also.  Universal runners look like this:

```
defmodule Oli.Delivery.MajorUpdatesTest do
  @moduledoc """
  Test runner for major update scenarios.
  Automatically discovers and runs all .scenario.yaml files in this directory.
  """

  use Oli.Scenarios.ScenarioRunner
end
```

The key in the above example is the `use Oli.Scenarios.ScenarioRunner`

More complex scenarios - only if needed -  can be created by inlining the YAML (or reading it from a standalone file), executing it, and then executing additional custom code. Here is an example:

```
test "can create a product from a project" do
  yaml = """
  - project:
      name: "source_project"
      title: "Source Project"
      root:
        children:
          - page: "Page 1"
          - container: "Module 1"
            children:
              - page: "Lesson 1"
              - page: "Lesson 2"

  - product:
      name: "my_product"
      title: "My Product Template"
      from: "source_project"
  """

  result = TestHelpers.execute_yaml(yaml)
  assert %ExecutionResult{errors: []} = result

  # Now we can execute any other code here for me complex
  # assertions:
  assert product = TestHelpers.get_product(result, "my_product")
  assert product.title == "My Product Template"
end
```

IMPORTANT: Never try to extend the `Oli.Scenarios` implementation and infrastructure. Never change any production code under `./lib`.  Your job is ONLY to author a test scenario.

Think hardest and author a new `Oli.Scenarios` based unit test for the following workflow:

@$ARGUMENTS



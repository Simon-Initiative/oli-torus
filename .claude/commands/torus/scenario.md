---
description: Create a new Scenario based integration test
---

`Oli.Scenarios` is a YAML based DSL for authoring complex integration
style unit tests in the Torus codebase.  The core implementation is found
in directory `./oli/scenarios` and the test support portion is in
`./test/support/scenarios`.

For a complete understanding of
`Oli.Scenarios` and the directives available you must read and carefully study
`./test/support/scenarios/README.md` and all of the sub documents
linked from that file.  Consult the core implementation also if needed.

Scenario test files are all stored under `./test/scenarios`.

Scenario based unit tests are used to test complex workflows such as:
- Publishing changes from a project to course section built from them
- Course section remix functionality
- Course section customization functionality
- Creation of course sections from products
- Student metrics calculations after activity answering

Good examples of real Scenarios that you can consult are:
- `./test/scenarios/cloning/independent_publishing.scenario.yaml`
- `./test/scenarios/delivery/major_updates/apply_major_updates_from_product.scenario.yaml`

When creating a new Scenario, you must create a file name with a `.scenario.yaml`
ending, which allows the "universal scenario runner" to find and execute the scenario.

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

IMPORTANT: When authoring a new scenario, never try to extend the
`Oli.Scenarios` implementation and infrastructure. Never change any production code under `./lib`.  Your job is ONLY to author a test scenario.

Think hardest and author a new `Oli.Scenarios` based unit test for the following workflow. Determine which sub dir under `./test/scenarios` to store the scenario in.

The workflow is:

@$ARGUMENTS



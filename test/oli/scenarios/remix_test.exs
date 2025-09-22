defmodule Oli.Scenarios.RemixTest do
  use Oli.DataCase

  alias Oli.Scenarios.TestHelpers
  alias Oli.Scenarios.DirectiveTypes.ExecutionResult

  describe "remix directive" do
    test "can remix a page from project into section container" do
      yaml = """
      - project:
          name: "source"
          title: "Source Project"
          root:
            children:
              - page: "Page to Copy"
              - container: "Module"
                children:
                  - page: "Nested Page"

      - project:
          name: "dest"
          title: "Destination Project"
          root:
            children:
              - container: "Target Module"
                children:
                  - page: "Existing Page"

      - section:
          name: "section"
          from: "dest"

      # Verify initial structure
      - assert:
          structure:
            to: "section"
            root:
              children:
                - container: "Target Module"
                  children:
                    - page: "Existing Page"

      # Remix page into the Target Module
      - remix:
          from: "source"
          resource: "Page to Copy"
          section: "section"
          to: "Target Module"

      # Verify page was added
      - assert:
          structure:
            to: "section"
            root:
              children:
                - container: "Target Module"
                  children:
                    - page: "Existing Page"
                    - page: "Page to Copy"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: verifications} = result
      assert length(verifications) == 2
      assert Enum.all?(verifications, & &1.passed)
    end

    test "can remix a container with children into section" do
      yaml = """
      - project:
          name: "source"
          title: "Source Project"
          root:
            children:
              - container: "Module to Copy"
                children:
                  - page: "Lesson 1"
                  - page: "Lesson 2"

      - project:
          name: "dest"
          title: "Destination Project"
          root:
            children:
              - container: "Existing Module"
                children:
                  - page: "Original Content"

      - section:
          name: "section"
          from: "dest"

      # Remix container into existing module
      - remix:
          from: "source"
          resource: "Module to Copy"
          section: "section"
          to: "Existing Module"

      # Verify container with children was added
      - assert:
          structure:
            to: "section"
            root:
              children:
                - container: "Existing Module"
                  children:
                    - page: "Original Content"
                    - container: "Module to Copy"
                      children:
                        - page: "Lesson 1"
                        - page: "Lesson 2"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed
    end

    test "can remix into root container" do
      yaml = """
      - project:
          name: "source"
          title: "Source Project"
          root:
            children:
              - page: "Page to Add"

      - project:
          name: "dest"
          title: "Destination Project"
          root:
            children:
              - page: "Existing Page"

      - section:
          name: "section"
          from: "dest"

      # Remix page into root
      - remix:
          from: "source"
          resource: "Page to Add"
          section: "section"
          to: "root"

      # Verify page was added to root
      - assert:
          structure:
            to: "section"
            root:
              children:
                - page: "Existing Page"
                - page: "Page to Add"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed
    end

    test "fails when source project doesn't exist" do
      yaml = """
      - project:
          name: "dest"
          title: "Destination Project"
          root:
            children:
              - container: "Target"

      - section:
          name: "section"
          from: "dest"

      - remix:
          from: "nonexistent"
          resource: "Some Page"
          section: "section"
          to: "Target"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: errors} = result
      assert length(errors) > 0
      assert {_directive, reason} = hd(errors)
      assert reason =~ "Source project 'nonexistent' not found"
    end

    test "fails when resource doesn't exist in source" do
      yaml = """
      - project:
          name: "source"
          title: "Source Project"
          root:
            children:
              - page: "Real Page"

      - project:
          name: "dest"
          title: "Destination Project"
          root:
            children:
              - container: "Target"

      - section:
          name: "section"
          from: "dest"

      - remix:
          from: "source"
          resource: "Nonexistent Page"
          section: "section"
          to: "Target"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: errors} = result
      assert length(errors) > 0
      assert {_directive, reason} = hd(errors)
      assert reason =~ "Resource 'Nonexistent Page' not found"
    end

    test "fails when target container doesn't exist" do
      yaml = """
      - project:
          name: "source"
          title: "Source Project"
          root:
            children:
              - page: "Page to Copy"

      - project:
          name: "dest"
          title: "Destination Project"
          root:
            children:
              - page: "Just a Page"

      - section:
          name: "section"
          from: "dest"

      - remix:
          from: "source"
          resource: "Page to Copy"
          section: "section"
          to: "Nonexistent Container"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: errors} = result
      assert length(errors) > 0
      assert {_directive, reason} = hd(errors)
      assert reason =~ "Target container 'Nonexistent Container' not found in section hierarchy"
    end
  end
end

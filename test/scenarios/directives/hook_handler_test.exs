defmodule Oli.Scenarios.Directives.HookHandlerTest do
  use Oli.DataCase

  alias Oli.Scenarios.DirectiveParser
  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.DirectiveTypes.ExecutionState

  describe "hook directive" do
    test "executes a simple hook function that modifies state" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"

      - hook:
          function: "Oli.Scenarios.Hooks.set_test_flag/1"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []
      assert Map.get(result.state, :test_flags, %{}) == %{hook_executed: true}
    end

    test "hook can log state without modifying it" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"

      - section:
          name: "test_section"
          title: "Test Section"
          from: "test_project"

      - hook:
          function: "Oli.Scenarios.Hooks.log_state/1"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []
      assert map_size(result.state.projects) == 1
      assert map_size(result.state.sections) == 1
    end

    test "hook can create bulk users" do
      yaml = """
      - hook:
          function: "Oli.Scenarios.Hooks.create_bulk_users/1"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []
      # Should have created 5 bulk users
      bulk_users =
        result.state.users
        |> Map.keys()
        |> Enum.filter(&String.starts_with?(&1, "bulk_user_"))

      assert length(bulk_users) == 5
    end

    test "hook can clear activities from state" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"

      - create_activity:
          project: "test_project"
          title: "Activity 1"
          type: "oli_multiple_choice"
          content: |
            stem_md: "Test question"
            choices:
              - id: "1"
                body_md: "Choice A"
              - id: "2"
                body_md: "Choice B"
            authoring:
              parts:
                - id: "1"
                  responses:
                    - rule: "input like {1}"
                      score: 1
                      feedback: "Correct!"
                    - rule: "input like {2}"
                      score: 0
                      feedback: "Incorrect"

      - hook:
          function: "Oli.Scenarios.Hooks.clear_activities/1"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []
      assert map_size(result.state.activities) == 0
      assert map_size(result.state.activity_virtual_ids) == 0
    end

    test "hook can inject error conditions" do
      yaml = """
      - hook:
          function: "Oli.Scenarios.Hooks.inject_error/1"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []
      error_info = Map.get(result.state, :error_injected)
      assert error_info != nil
      assert error_info.type == :test_error
      assert error_info.message == "Intentional error injected for testing"
    end

    test "hook with invalid function specification fails" do
      yaml = """
      - hook:
          function: "InvalidModule.nonexistent/1"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert length(result.errors) == 1
      [{_directive, error_msg}] = result.errors
      assert error_msg =~ "Failed to load module"
    end

    test "hook with wrong arity fails" do
      yaml = """
      - hook:
          function: "Oli.Scenarios.Hooks.log_state/2"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert length(result.errors) == 1
      [{_directive, error_msg}] = result.errors
      assert error_msg =~ "Hook function must have arity 1"
    end

    test "hook with invalid format fails" do
      yaml = """
      - hook:
          function: "not_a_valid_function_spec"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert length(result.errors) == 1
      [{_directive, error_msg}] = result.errors
      assert error_msg =~ "Invalid function specification format"
    end

    test "hook directive validates attributes" do
      yaml = """
      - hook:
          function: "Oli.Scenarios.Hooks.log_state/1"
          extra_field: "should fail"
      """

      assert_raise RuntimeError,
                   ~r/Unknown attributes in 'hook' directive: \["extra_field"\]/,
                   fn ->
                     DirectiveParser.parse_yaml!(yaml)
                   end
    end

    test "hook can be used multiple times in sequence" do
      yaml = """
      - hook:
          function: "Oli.Scenarios.Hooks.set_test_flag/1"

      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"

      - hook:
          function: "Oli.Scenarios.Hooks.log_state/1"

      - hook:
          function: "Oli.Scenarios.Hooks.inject_error/1"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []
      assert Map.get(result.state, :test_flags, %{}) == %{hook_executed: true}
      assert Map.get(result.state, :error_injected) != nil
      assert map_size(result.state.projects) == 1
    end
  end

  describe "custom hook module" do
    # Define a test module with hook functions
    defmodule TestHooks do
      def custom_operation(%ExecutionState{} = state) do
        Map.put(state, :custom_flag, :executed)
      end

      def transform_state(%ExecutionState{} = state) do
        # Add a transformation marker
        Map.put(state, :transformed, true)
      end
    end

    test "can call functions from custom modules" do
      yaml = """
      - hook:
          function: "Oli.Scenarios.Directives.HookHandlerTest.TestHooks.custom_operation/1"

      - hook:
          function: "Oli.Scenarios.Directives.HookHandlerTest.TestHooks.transform_state/1"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []
      assert Map.get(result.state, :custom_flag) == :executed
      assert Map.get(result.state, :transformed) == true
    end
  end
end

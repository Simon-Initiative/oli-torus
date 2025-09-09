defmodule Oli.ScopedFeatureFlags.CompileTimeValidationTest do
  use ExUnit.Case, async: true
  use Oli.DataCase
  import ExUnit.CaptureIO
  import Oli.Factory

  alias Oli.ScopedFeatureFlags

  describe "compile-time validation macro" do
    test "warns when using undefined feature with literal atom" do
      # We need to test this indirectly since compile-time warnings happen during compilation
      # This test verifies the warning function works correctly

      warning_output =
        capture_io(:stderr, fn ->
          # We'll use Code.eval_quoted to simulate compile-time usage
          Code.eval_quoted(
            quote do
              require Oli.ScopedFeatureFlags
              Oli.ScopedFeatureFlags.validate_feature_at_compile_time(:undefined_feature)
            end
          )
        end)

      assert warning_output =~ "Undefined feature flag: :undefined_feature"
      assert warning_output =~ "Available features:"
      assert warning_output =~ ":mcp_authoring"

      assert warning_output =~
               "Features must be defined in Oli.ScopedFeatureFlags.DefinedFeatures"
    end

    test "does not warn for defined features" do
      warning_output =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Oli.ScopedFeatureFlags
              Oli.ScopedFeatureFlags.validate_feature_at_compile_time(:mcp_authoring)
            end
          )
        end)

      assert warning_output == ""
    end

    test "does not warn for runtime feature names (non-atoms)" do
      warning_output =
        capture_io(:stderr, fn ->
          Code.eval_quoted(
            quote do
              require Oli.ScopedFeatureFlags
              feature_name = "undefined_feature"
              Oli.ScopedFeatureFlags.validate_feature_at_compile_time(feature_name)
            end
          )
        end)

      assert warning_output == ""
    end
  end

  describe "runtime validation" do
    setup do
      project = insert(:project)
      section = insert(:section)

      %{project: project, section: section}
    end

    test "raises for undefined atom feature names", %{project: project} do
      assert_raise ArgumentError, ~r/Undefined feature flag: :undefined_feature/, fn ->
        ScopedFeatureFlags.enabled?(:undefined_feature, project)
      end
    end

    test "raises for undefined string feature names", %{project: project} do
      assert_raise ArgumentError, ~r/Undefined feature flag: "undefined_feature"/, fn ->
        ScopedFeatureFlags.enabled?("undefined_feature", project)
      end
    end

    test "works correctly with defined features", %{project: project} do
      # This should not raise and return a boolean
      result = ScopedFeatureFlags.enabled?(:mcp_authoring, project)
      assert is_boolean(result)

      result = ScopedFeatureFlags.enabled?("mcp_authoring", project)
      assert is_boolean(result)
    end

    test "enable_feature works with defined features", %{project: project} do
      assert {:ok, _} = ScopedFeatureFlags.enable_feature(:mcp_authoring, project)
      assert {:ok, _} = ScopedFeatureFlags.enable_feature("mcp_authoring", project)
    end

    test "disable_feature works with defined features", %{project: project} do
      assert {:ok, _} = ScopedFeatureFlags.disable_feature(:mcp_authoring, project)
      assert {:ok, _} = ScopedFeatureFlags.disable_feature("mcp_authoring", project)
    end
  end
end

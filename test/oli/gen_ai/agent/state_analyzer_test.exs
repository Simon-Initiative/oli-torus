defmodule Oli.GenAI.Agent.StateAnalyzerTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.Agent.StateAnalyzer

  describe "analyze/1" do
    test "returns normal health for clean state" do
      state = %{
        steps: [
          create_step("tool", "test1", %{}),
          create_step("tool", "test2", %{}),
          create_step("tool", "test3", %{})
        ],
        goal: "Test goal",
        plan: ["step1", "step2", "step3"]
      }

      analysis = StateAnalyzer.analyze(state)

      assert analysis.health == :normal
      assert analysis.issues == []
      assert analysis.recommendation == :continue
    end

    test "detects critical health with looping" do
      state = %{
        steps: [
          create_step("tool", "test", %{}),
          create_step("tool", "test", %{}),
          create_step("tool", "test", %{}),
          create_step("tool", "test", %{}),
          create_step("tool", "test", %{}),
          create_step("tool", "test", %{})
        ],
        goal: "Test goal",
        plan: ["step1"]
      }

      analysis = StateAnalyzer.analyze(state)

      assert analysis.health == :critical
      assert analysis.recommendation == :abort
      assert Enum.any?(analysis.issues, &String.contains?(&1, "loop"))
    end

    test "detects degraded health with failures" do
      state = %{
        steps: [
          create_step_with_error("tool", "test1", %{}),
          create_step_with_error("tool", "test2", %{}),
          create_step("tool", "test3", %{}),
          create_step("tool", "test4", %{}),
          create_step("tool", "test5", %{}),
          create_step("tool", "test6", %{})
        ],
        goal: "Test goal",
        plan: ["step1", "step2"]
      }

      analysis = StateAnalyzer.analyze(state)

      assert analysis.health == :degraded
      assert Enum.any?(analysis.issues, &String.contains?(&1, "failure"))
    end

    test "detects critical health with high failure rate" do
      state = %{
        steps: [
          create_step_with_error("tool", "test1", %{}),
          create_step_with_error("tool", "test2", %{}),
          create_step_with_error("tool", "test3", %{}),
          create_step("tool", "test4", %{}),
          create_step("tool", "test5", %{})
        ],
        goal: "Test goal",
        plan: ["step1"]
      }

      analysis = StateAnalyzer.analyze(state)

      assert analysis.health == :critical
      assert analysis.recommendation == :replan
      assert Enum.any?(analysis.issues, &String.contains?(&1, "High failure rate"))
    end

    test "detects excessive steps issue" do
      steps =
        Enum.map(1..35, fn i ->
          create_step("tool", "test#{i}", %{})
        end)

      state = %{
        steps: steps,
        goal: "Complex goal",
        plan: ["step1", "step2"]
      }

      analysis = StateAnalyzer.analyze(state)

      # Should be critical due to multiple issues (excessive steps + plan deviation = 2+ issues)
      assert analysis.health in [:degraded, :critical]
      assert Enum.any?(analysis.issues, &String.contains?(&1, "Excessive steps"))
    end

    test "detects plan deviation" do
      steps =
        Enum.map(1..10, fn i ->
          create_step("tool", "test#{i}", %{})
        end)

      state = %{
        steps: steps,
        goal: "Test goal",
        plan: ["step1", "step2"]
      }

      analysis = StateAnalyzer.analyze(state)

      assert analysis.health == :degraded
      assert Enum.any?(analysis.issues, &String.contains?(&1, "deviation from original plan"))
    end

    test "recommends replan for degraded state meeting criteria" do
      steps =
        Enum.map(1..10, fn i ->
          if i <= 3 do
            create_step_with_error("tool", "test#{i}", %{})
          else
            create_step("tool", "test#{i}", %{})
          end
        end)

      state = %{
        steps: steps,
        goal: "Test goal",
        plan: ["step1", "step2", "step3"]
      }

      analysis = StateAnalyzer.analyze(state)

      # High failure rate
      assert analysis.health == :critical
      assert analysis.recommendation == :replan
    end

    test "handles empty state gracefully" do
      state = %{}

      analysis = StateAnalyzer.analyze(state)

      assert analysis.health == :normal
      assert analysis.issues == []
      assert analysis.recommendation == :continue
    end

    test "handles state with empty steps" do
      state = %{
        steps: [],
        goal: "Test goal",
        plan: ["step1"]
      }

      analysis = StateAnalyzer.analyze(state)

      assert analysis.health == :normal
      assert analysis.issues == []
      assert analysis.recommendation == :continue
    end

    test "combines multiple issues appropriately" do
      steps =
        Enum.map(1..25, fn i ->
          obs = if rem(i, 5) == 0, do: %{error: "failed"}, else: "ok"
          %{action: %{type: "tool", name: "test", args: %{}}, observation: obs}
        end)

      state = %{
        steps: steps,
        goal: "Complex goal",
        plan: ["step1", "step2"]
      }

      analysis = StateAnalyzer.analyze(state)

      assert analysis.health == :critical
      # Loop, failures, complexity, plan deviation
      assert length(analysis.issues) >= 3

      # Check for different issue types
      assert Enum.any?(analysis.issues, &String.contains?(&1, "loop"))
      assert Enum.any?(analysis.issues, &String.contains?(&1, "steps"))
      # With 5 failures out of 25 (only last 5 checked), should have failure issues
      assert length(analysis.issues) > 2
    end
  end

  # Helper functions

  defp create_step(type, name, args) do
    action = %{type: type, name: name, args: args}
    %{action: action, observation: "ok"}
  end

  defp create_step_with_error(type, name, args) do
    action = %{type: type, name: name, args: args}
    %{action: action, observation: %{error: "failed"}}
  end
end

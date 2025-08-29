defmodule Oli.GenAI.Agent.CriticTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.Agent.Critic

  describe "looping?/1" do
    test "returns false when steps list is too short" do
      steps = [
        create_step("tool", "test", %{}),
        create_step("tool", "test", %{})
      ]

      refute Critic.looping?(steps)
    end

    test "detects identical consecutive tool calls" do
      steps = [
        create_step("tool", "search", %{query: "test"}),
        create_step("tool", "search", %{query: "test"}),
        create_step("tool", "other", %{}),
        create_step("tool", "other", %{}),
        create_step("tool", "final", %{}),
        create_step("tool", "final", %{})
      ]

      assert Critic.looping?(steps)
    end

    test "detects alternating pattern loops" do
      steps = [
        create_step("tool", "B", %{id: 2}),
        create_step("tool", "A", %{id: 1}),
        create_step("tool", "B", %{id: 2}),
        create_step("tool", "A", %{id: 1}),
        create_step("tool", "C", %{}),
        create_step("tool", "D", %{})
      ]

      assert Critic.looping?(steps)
    end

    test "detects repeated identical tool calls" do
      steps = [
        create_step("tool", "fetch", %{url: "same"}),
        create_step("message", nil, nil, "thinking"),
        create_step("tool", "fetch", %{url: "same"}),
        create_step("message", nil, nil, "still thinking"),
        create_step("tool", "fetch", %{url: "same"}),
        create_step("tool", "other", %{})
      ]

      assert Critic.looping?(steps)
    end

    test "returns false for normal workflow without loops" do
      steps = [
        create_step("tool", "search", %{query: "test1"}),
        create_step("tool", "fetch", %{id: 1}),
        create_step("tool", "process", %{data: "data1"}),
        create_step("tool", "search", %{query: "test2"}),
        create_step("tool", "fetch", %{id: 2}),
        create_step("tool", "save", %{data: "final"})
      ]

      refute Critic.looping?(steps)
    end

    test "handles non-list input gracefully" do
      refute Critic.looping?(nil)
      refute Critic.looping?("not a list")
      refute Critic.looping?(%{})
    end
  end

  describe "should_replan?/1" do
    test "returns true when looping is detected" do
      state = %{
        steps: [
          create_step("tool", "test", %{}),
          create_step("tool", "test", %{}),
          create_step("tool", "other", %{}),
          create_step("tool", "other", %{}),
          create_step("tool", "test", %{}),
          create_step("tool", "test", %{})
        ],
        plan: ["step1", "step2"]
      }

      assert Critic.should_replan?(state)
    end

    test "returns true when too many failures occur" do
      state = %{
        steps: [
          create_step_with_error("tool", "test1", %{}),
          create_step("tool", "test2", %{}, "error occurred"),
          create_step_with_error("tool", "test3", %{}),
          create_step("tool", "test4", %{}, "ok"),
          create_step("tool", "test5", %{}, "failed"),
          create_step("tool", "test6", %{}, "ok")
        ],
        plan: ["step1", "step2"]
      }

      assert Critic.should_replan?(state)
    end

    test "returns true when execution exceeds planned complexity" do
      steps =
        Enum.map(1..10, fn i ->
          create_step("tool", "test#{i}", %{})
        end)

      state = %{
        steps: steps,
        plan: ["step1", "step2", "step3"]
      }

      assert Critic.should_replan?(state)
    end

    test "returns false when everything is normal" do
      state = %{
        steps: [
          create_step("tool", "test1", %{}),
          create_step("tool", "test2", %{}),
          create_step("tool", "test3", %{})
        ],
        plan: ["step1", "step2", "step3"]
      }

      refute Critic.should_replan?(state)
    end

    test "returns false when steps are too few for meaningful analysis" do
      state = %{
        steps: [
          create_step("tool", "test1", %{}),
          create_step("tool", "test2", %{})
        ],
        plan: ["step1", "step2"]
      }

      refute Critic.should_replan?(state)
    end
  end

  describe "critique/1" do
    test "returns normal progress message when no issues detected" do
      state = %{
        steps: [
          create_step("tool", "test1", %{}),
          create_step("tool", "test2", %{})
        ],
        goal: "Test goal"
      }

      assert Critic.critique(state) == "Progress appears normal"
    end

    test "detects looping issues" do
      state = %{
        steps: [
          create_step("tool", "test", %{}),
          create_step("tool", "test", %{}),
          create_step("tool", "test", %{}),
          create_step("tool", "test", %{}),
          create_step("tool", "test", %{}),
          create_step("tool", "test", %{})
        ],
        goal: "Test goal"
      }

      critique = Critic.critique(state)
      assert String.contains?(critique, "loop")
    end

    test "detects multiple failures" do
      state = %{
        steps: [
          create_step_with_error("tool", "test1", %{}),
          create_step_with_error("tool", "test2", %{}),
          create_step("tool", "test3", %{}),
          create_step("tool", "test4", %{}),
          create_step("tool", "test5", %{}),
          create_step("tool", "test6", %{})
        ],
        goal: "Test goal"
      }

      critique = Critic.critique(state)
      assert String.contains?(critique, "failures")
    end

    test "detects excessive steps" do
      steps =
        Enum.map(1..25, fn i ->
          create_step("tool", "test#{i}", %{})
        end)

      state = %{
        steps: steps,
        goal: "Complex goal"
      }

      critique = Critic.critique(state)
      assert String.contains?(critique, "many steps")
    end

    test "combines multiple issues" do
      steps =
        Enum.map(1..25, fn i ->
          obs = if rem(i, 3) == 0, do: %{error: "failed"}, else: "ok"
          %{action: %{type: "tool", name: "test", args: %{}}, observation: obs}
        end)

      state = %{
        steps: steps,
        goal: "Complex goal"
      }

      critique = Critic.critique(state)
      assert String.contains?(critique, "Issues detected")
      # Multiple issues joined
      assert String.contains?(critique, ";")
    end
  end

  describe "count_recent_failures/1" do
    test "counts error observations correctly" do
      steps = [
        create_step_with_error("tool", "test1", %{}),
        create_step_with_error("tool", "test2", %{}),
        create_step("tool", "test3", %{}),
        create_step_with_error("tool", "test4", %{}),
        create_step("tool", "test5", %{})
      ]

      assert Critic.count_recent_failures(steps) == 3
    end

    test "detects error strings in observations" do
      steps = [
        %{action: %{type: "tool", name: "test1", args: %{}}, observation: "error occurred"},
        %{action: %{type: "tool", name: "test2", args: %{}}, observation: "failed to process"},
        %{action: %{type: "tool", name: "test3", args: %{}}, observation: "success"},
        %{action: %{type: "tool", name: "test4", args: %{}}, observation: "another error"},
        %{action: %{type: "tool", name: "test5", args: %{}}, observation: "ok"}
      ]

      assert Critic.count_recent_failures(steps) == 3
    end

    test "handles empty steps list" do
      assert Critic.count_recent_failures([]) == 0
    end

    test "only counts recent steps (window of 5)" do
      steps = [
        create_step("tool", "test1", %{}, "ok"),
        create_step("tool", "test2", %{}, "ok"),
        create_step("tool", "test3", %{}, "ok"),
        create_step_with_error("tool", "test4", %{}),
        create_step_with_error("tool", "test5", %{}),
        # These should not be counted as they're beyond the window
        create_step_with_error("tool", "test6", %{}),
        create_step_with_error("tool", "test7", %{})
      ]

      assert Critic.count_recent_failures(steps) == 2
    end
  end

  describe "analyze/1" do
    test "returns comprehensive analysis with health status" do
      state = %{
        steps: [
          create_step("tool", "test1", %{}),
          create_step("tool", "test2", %{})
        ],
        goal: "Test goal",
        plan: ["step1", "step2"]
      }

      analysis = Critic.analyze(state)

      assert %{
               health: :normal,
               issues: [],
               recommendation: :continue
             } = analysis
    end

    test "detects critical health status with looping" do
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

      analysis = Critic.analyze(state)

      assert analysis.health == :critical
      assert analysis.recommendation == :abort
      assert length(analysis.issues) > 0
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

      analysis = Critic.analyze(state)

      assert analysis.health == :degraded
      assert length(analysis.issues) > 0
    end
  end

  # Helper functions

  defp create_step(type, name, args, content \\ nil) do
    action =
      case type do
        "tool" -> %{type: "tool", name: name, args: args}
        "message" -> %{type: "message", content: content}
        _ -> %{type: type}
      end

    %{action: action, observation: "ok"}
  end

  defp create_step_with_error(type, name, args) do
    action = %{type: type, name: name, args: args}
    %{action: action, observation: %{error: "failed"}}
  end
end

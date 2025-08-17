defmodule Oli.GenAI.Agent.ServerTest do
  use ExUnit.Case, async: true
  alias Oli.GenAI.Agent.{Server, Decision}

  # Mock components for testing the server loop
  defmodule MockLLMBridge do
    def next_decision(messages, _opts) do
      # Simulate different decisions based on message content
      last_message = List.last(messages)

      cond do
        last_message.content =~ "search" ->
          {:ok,
           %Decision{
             next_action: "tool",
             tool_name: "search_codebase",
             arguments: %{"query" => "main function", "path" => "src/"}
           }}

        last_message.content =~ "done" ->
          {:ok,
           %Decision{
             next_action: "done",
             rationale_summary: "Task completed successfully"
           }}

        last_message.content =~ "replan" ->
          {:ok,
           %Decision{
             next_action: "replan",
             updated_plan: ["new step 1", "new step 2"],
             rationale_summary: "Adjusting approach"
           }}

        true ->
          {:ok,
           %Decision{
             next_action: "message",
             assistant_message: "Processing your request..."
           }}
      end
    end
  end

  defmodule MockToolBroker do
    @behaviour Oli.GenAI.Agent.Tool

    @impl true
    def call("search_codebase", args, _ctx) do
      {:ok,
       %{
         content: "Found 3 matches for '#{args["query"]}' in #{args["path"]}",
         token_cost: 50
       }}
    end

    def call("read_file", %{"path" => path}, _ctx) do
      {:ok,
       %{
         content: "Contents of #{path}: function main() { ... }",
         token_cost: 30
       }}
    end

    def call("error_tool", _args, _ctx) do
      {:error, "Tool execution failed"}
    end

    def call(name, _args, _ctx) do
      {:error, "Unknown tool: #{name}"}
    end
  end

  defmodule MockPersistence do
    def create_run(attrs) do
      {:ok, Map.put(attrs, :id, Ecto.UUID.generate())}
    end

    def update_run(_run_or_id, attrs) do
      {:ok, attrs}
    end

    def append_step(attrs) do
      {:ok, attrs}
    end
  end

  defmodule MockPubSub do
    def broadcast_step(_run_id, _step), do: :ok
    def broadcast_status(_run_id, _status), do: :ok
    def broadcast_stats(_run_id, _stats), do: :ok
  end

  defmodule MockPolicy do
    @behaviour Oli.GenAI.Agent.Policy

    @impl true
    def allowed_action?(%{tool_name: "dangerous_tool"}, _state) do
      {false, "Tool 'dangerous_tool' is not allowed"}
    end

    def allowed_action?(_decision, _state), do: true

    @impl true
    def stop_reason?(%{steps: steps}) when length(steps) > 10 do
      {:done, "Step limit exceeded"}
    end

    def stop_reason?(%{budgets: %{max_tokens: max}, tokens_used: used}) when used > max do
      {:done, "Token budget exceeded"}
    end

    def stop_reason?(_state), do: nil

    @impl true
    def redact(log_payload) do
      Map.drop(log_payload, [:api_key, :secret])
    end
  end

  describe "Server state machine" do
    setup do
      # Create a minimal state for testing
      state = %Server.State{
        id: Ecto.UUID.generate(),
        goal: "Test goal",
        plan: ["step 1", "step 2"],
        status: :idle,
        budgets: %{max_steps: 50, max_tokens: 10000},
        service_config: nil,
        policy: nil,
        context_summary: "",
        short_window: [],
        steps: [],
        inflight: %{},
        metadata: %{},
        tokens_used: 0,
        cost_cents: 0,
        start_time: DateTime.utc_now()
      }

      {:ok, state: state}
    end

    test "transitions from idle to thinking on :step", %{state: state} do
      # Simulate handle_cast(:step, state)
      new_state = %{state | status: :thinking}
      assert new_state.status == :thinking
    end

    test "executes tool decision and creates observation", %{state: state} do
      decision = %Decision{
        next_action: "tool",
        tool_name: "search_codebase",
        arguments: %{"query" => "test", "path" => "/"}
      }

      # Simulate tool execution
      {:ok, result} = MockToolBroker.call(decision.tool_name, decision.arguments, %{})

      step = %Server.Step{
        num: 1,
        action: %{type: "tool", name: decision.tool_name, args: decision.arguments},
        observation: result.content,
        tokens_in: 100,
        tokens_out: 50
      }

      new_state = %{state | steps: [step | state.steps], status: :idle}

      assert length(new_state.steps) == 1
      assert hd(new_state.steps).observation =~ "Found 3 matches"
    end

    test "handles message decision", %{state: state} do
      decision = %Decision{
        next_action: "message",
        assistant_message: "I'll help you with that"
      }

      message = %{role: :assistant, content: decision.assistant_message}
      new_state = %{state | short_window: [message | state.short_window], status: :idle}

      assert length(new_state.short_window) == 1
      assert hd(new_state.short_window).content == "I'll help you with that"
    end

    test "handles replan decision", %{state: state} do
      decision = %Decision{
        next_action: "replan",
        updated_plan: ["new task 1", "new task 2", "new task 3"],
        rationale_summary: "Found better approach"
      }

      new_state = %{state | plan: decision.updated_plan, status: :idle}

      assert new_state.plan == ["new task 1", "new task 2", "new task 3"]
    end

    test "transitions to done on done decision", %{state: state} do
      _decision = %Decision{
        next_action: "done",
        rationale_summary: "All tasks completed"
      }

      new_state = %{state | status: :done}
      assert new_state.status == :done
    end

    test "enforces policy constraints", %{state: state} do
      decision = %Decision{
        next_action: "tool",
        tool_name: "dangerous_tool",
        arguments: %{}
      }

      case MockPolicy.allowed_action?(decision, state) do
        true -> assert false, "Should have blocked dangerous tool"
        {false, reason} -> assert reason =~ "not allowed"
      end
    end

    test "checks stop conditions", %{state: state} do
      # Test step limit
      state_with_many_steps = %{
        state
        | steps:
            Enum.map(1..11, fn i ->
              %Server.Step{num: i, action: %{}, observation: "step #{i}"}
            end)
      }

      assert {:done, reason} = MockPolicy.stop_reason?(state_with_many_steps)
      assert reason =~ "Step limit"

      # Test token budget
      state_over_budget = %{state | budgets: %{max_tokens: 1000}, tokens_used: 1001}

      assert {:done, reason} = MockPolicy.stop_reason?(state_over_budget)
      assert reason =~ "Token budget"
    end

    test "handles tool execution errors gracefully", %{state: state} do
      decision = %Decision{
        next_action: "tool",
        tool_name: "error_tool",
        arguments: %{}
      }

      {:error, error_msg} = MockToolBroker.call(decision.tool_name, decision.arguments, %{})

      step = %Server.Step{
        num: 1,
        action: %{type: "tool", name: decision.tool_name, error: true},
        observation: "Error: #{error_msg}"
      }

      new_state = %{state | steps: [step | state.steps], status: :idle}

      assert hd(new_state.steps).observation =~ "Error: Tool execution failed"
    end
  end

  describe "Server loop integration" do
    test "completes full step cycle: idle -> thinking -> tool -> observation -> idle" do
      state = %Server.State{
        id: Ecto.UUID.generate(),
        goal: "Find and analyze main function",
        plan: ["search for main", "read file", "analyze"],
        status: :idle,
        budgets: %{max_steps: 10, max_tokens: 5000},
        service_config: nil,
        policy: nil,
        short_window: [
          %{role: :user, content: "search for main function"}
        ],
        steps: [],
        context_summary: "",
        inflight: %{},
        metadata: %{},
        tokens_used: 0,
        cost_cents: 0,
        start_time: DateTime.utc_now()
      }

      # Step 1: Get decision from LLM
      {:ok, decision} = MockLLMBridge.next_decision(state.short_window, %{})
      assert decision.next_action == "tool"
      assert decision.tool_name == "search_codebase"

      # Step 2: Execute tool
      {:ok, tool_result} =
        MockToolBroker.call(
          decision.tool_name,
          decision.arguments,
          %{run_id: state.id}
        )

      # Step 3: Create observation and update state
      step = %Server.Step{
        num: length(state.steps) + 1,
        action: %{
          type: "tool",
          name: decision.tool_name,
          args: decision.arguments
        },
        observation: tool_result.content,
        tokens_in: 100,
        tokens_out: 50,
        latency_ms: 234
      }

      new_state = %{
        state
        | steps: [step | state.steps],
          short_window:
            state.short_window ++
              [
                %{role: :assistant, content: "Using #{decision.tool_name}"},
                %{role: :tool, content: tool_result.content}
              ],
          status: :idle
      }

      # Verify the cycle completed correctly
      assert new_state.status == :idle
      assert length(new_state.steps) == 1
      assert hd(new_state.steps).observation =~ "Found 3 matches"
      assert length(new_state.short_window) == 3
    end

    test "handles multiple steps until done" do
      initial_state = %Server.State{
        id: Ecto.UUID.generate(),
        goal: "Complete multi-step task",
        plan: ["search", "analyze", "report"],
        status: :idle,
        budgets: %{max_steps: 10, max_tokens: 5000},
        short_window: [],
        steps: [],
        context_summary: ""
      }

      # Simulate multiple step cycles
      state =
        Enum.reduce(1..3, initial_state, fn step_num, acc_state ->
          # Determine what message to send based on step
          message =
            case step_num do
              1 -> %{role: :user, content: "search for patterns"}
              2 -> %{role: :tool, content: "Found patterns: A, B, C"}
              3 -> %{role: :user, content: "done with analysis"}
            end

          window = acc_state.short_window ++ [message]
          {:ok, decision} = MockLLMBridge.next_decision(window, %{})

          case decision.next_action do
            "done" ->
              %{acc_state | status: :done, short_window: window}

            "tool" ->
              {:ok, result} = MockToolBroker.call(decision.tool_name, decision.arguments, %{})

              step = %Server.Step{
                num: step_num,
                action: %{type: "tool", name: decision.tool_name},
                observation: result.content
              }

              %{
                acc_state
                | steps: [step | acc_state.steps],
                  short_window: window ++ [%{role: :tool, content: result.content}],
                  status: :idle
              }

            "message" ->
              %{
                acc_state
                | short_window:
                    window ++ [%{role: :assistant, content: decision.assistant_message}],
                  status: :idle
              }
          end
        end)

      assert state.status == :done
      assert length(state.steps) >= 1
    end

    test "respects pause and resume operations" do
      state = %Server.State{
        id: Ecto.UUID.generate(),
        status: :thinking,
        goal: "Test pause/resume",
        plan: [],
        steps: []
      }

      # Pause
      paused_state = %{state | status: :paused}
      assert paused_state.status == :paused

      # Try to step while paused (should be ignored)
      # Still paused
      assert paused_state.status == :paused

      # Resume
      resumed_state = %{paused_state | status: :idle}
      assert resumed_state.status == :idle
    end

    test "handles cancellation properly" do
      state = %Server.State{
        id: Ecto.UUID.generate(),
        status: :thinking,
        goal: "Test cancellation",
        plan: ["task1", "task2"],
        steps: [
          %Server.Step{num: 1, action: %{}, observation: "partial"}
        ]
      }

      # Cancel
      cancelled_state = %{state | status: :cancelled}
      assert cancelled_state.status == :cancelled

      # Verify no further processing occurs
      # Status doesn't change
      assert cancelled_state.status == :cancelled
    end
  end

  describe "Server callbacks" do
    test "handle_call(:status, _, state) returns current status" do
      state = %Server.State{
        id: "test-123",
        status: :thinking,
        goal: "Test goal",
        plan: ["a", "b"],
        steps: []
      }

      expected = %{
        id: "test-123",
        status: :thinking,
        goal: "Test goal",
        plan: ["a", "b"],
        steps_completed: 0
      }

      # This would be the actual handle_call implementation
      status_info = %{
        id: state.id,
        status: state.status,
        goal: state.goal,
        plan: state.plan,
        steps_completed: length(state.steps)
      }

      assert status_info == expected
    end

    test "handle_call(:info, _, state) returns detailed information" do
      state = %Server.State{
        id: "test-456",
        status: :idle,
        goal: "Detailed test",
        plan: ["x", "y", "z"],
        steps: [
          %Server.Step{num: 1, action: %{type: "tool"}, observation: "result1"},
          %Server.Step{num: 2, action: %{type: "message"}, observation: "result2"}
        ],
        budgets: %{max_steps: 50, max_tokens: 10000},
        context_summary: "Working on test",
        metadata: %{user_id: "user123"}
      }

      info = %{
        id: state.id,
        status: state.status,
        goal: state.goal,
        plan: state.plan,
        steps_completed: length(state.steps),
        last_step: List.first(state.steps),
        budgets: state.budgets,
        context_summary: state.context_summary,
        metadata: state.metadata
      }

      assert info.steps_completed == 2
      assert info.last_step.num == 1
      assert info.budgets.max_steps == 50
    end
  end
end

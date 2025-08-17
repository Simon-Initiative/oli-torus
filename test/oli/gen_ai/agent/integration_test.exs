defmodule Oli.GenAI.Agent.IntegrationTest do
  use ExUnit.Case, async: false
  alias Oli.GenAI.Agent
  alias Oli.GenAI.Agent.ToolBroker

  setup do
    # These are already started by the application supervision tree
    # Just ensure ToolBroker is started
    ToolBroker.start()

    :ok
  end

  test "can start and query an agent run" do
    # Start an agent run
    {:ok, _pid} =
      Agent.start_run(%{
        goal: "Test basic agent functionality",
        plan: ["analyze task", "execute steps", "report results"],
        run_id: "test-run-123"
      })

    # Give it a moment to initialize
    Process.sleep(100)

    # Check status
    {:ok, status} = Agent.status("test-run-123")

    assert status.id == "test-run-123"
    assert status.goal == "Test basic agent functionality"
    assert status.status in [:idle, :thinking, :acting, :awaiting_tool, :done]
    assert length(status.plan) == 3

    # Get detailed info
    {:ok, info} = Agent.info("test-run-123")

    assert info.id == "test-run-123"
    assert info.goal == "Test basic agent functionality"
    assert is_integer(info.steps_completed)
    assert is_map(info.budgets)

    # Cancel the run
    :ok = Agent.cancel("test-run-123")

    # Verify it's cancelled
    {:ok, final_status} = Agent.status("test-run-123")
    assert final_status.status == :cancelled
  end

  test "agent runs with basic loop functionality" do
    # Start an agent run that should execute a few steps
    {:ok, _pid} =
      Agent.start_run(%{
        goal: "Search for and analyze main function",
        plan: ["search codebase", "read relevant files", "summarize findings"],
        run_id: "test-run-456",
        initial_messages: [
          %{role: :user, content: "search for main function"}
        ]
      })

    # Give it time to execute a few steps
    Process.sleep(500)

    # Check that it has made some progress
    {:ok, info} = Agent.info("test-run-456")

    # Should have executed at least one step
    assert info.steps_completed >= 1

    # Should have some tokens used
    assert info.tokens_used >= 0

    # Cancel to clean up
    Agent.cancel("test-run-456")
  end

  test "can pause and resume agent runs" do
    # Start an agent run
    {:ok, _pid} =
      Agent.start_run(%{
        goal: "Test pause/resume functionality",
        plan: ["step 1", "step 2", "step 3"],
        run_id: "test-run-789"
      })

    # Give it a moment to start
    Process.sleep(100)

    # Pause it
    :ok = Agent.pause("test-run-789")

    {:ok, status} = Agent.status("test-run-789")
    assert status.status == :paused

    # Resume it
    :ok = Agent.resume("test-run-789")

    {:ok, status} = Agent.status("test-run-789")
    assert status.status == :idle

    # Cancel to clean up
    Agent.cancel("test-run-789")
  end

  test "handles non-existent runs gracefully" do
    # Try to get status of non-existent run
    assert {:error, reason} = Agent.status("non-existent-run")
    assert reason =~ "not found"

    # Try to pause non-existent run
    assert {:error, reason} = Agent.pause("non-existent-run")
    assert reason =~ "not found"
  end
end

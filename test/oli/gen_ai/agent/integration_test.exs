defmodule Oli.GenAI.Agent.IntegrationTest do
  use ExUnit.Case, async: false
  alias Oli.GenAI.Agent
  alias Oli.GenAI.Agent.ToolBroker
  alias Oli.GenAI.Completions.{ServiceConfig, RegisteredModel}

  setup do
    # Allow database access for spawned processes (Agent Servers)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Oli.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Oli.Repo, {:shared, self()})

    # These are already started by the application supervision tree
    # Just ensure ToolBroker is started
    ToolBroker.start()

    # Create mock service config for testing (using null provider to avoid real API calls)
    service_config = %ServiceConfig{
      primary_model: %RegisteredModel{
        model: "test-primary",
        provider: :null,
        url_template: "http://localhost",
        api_key: "test-key",
        secondary_api_key: "test-org",
        timeout: 8000,
        recv_timeout: 60000
      },
      backup_model: %RegisteredModel{
        model: "test-backup",
        provider: :null,
        url_template: "http://localhost",
        api_key: "test-key-backup",
        secondary_api_key: "test-org-backup",
        timeout: 8000,
        recv_timeout: 60000
      }
    }

    {:ok, service_config: service_config}
  end

  test "can start and query an agent run", %{service_config: service_config} do
    run_id = Ecto.UUID.generate()

    # Start an agent run
    {:ok, _pid} =
      Agent.start_run(%{
        goal: "Test basic agent functionality",
        run_type: "test",
        plan: ["analyze task", "execute steps", "report results"],
        run_id: run_id,
        service_config: service_config
      })

    # Give it a moment to initialize
    Process.sleep(100)

    # Check status
    {:ok, status} = Agent.status(run_id)

    assert status.id == run_id
    assert status.goal == "Test basic agent functionality"
    assert status.status in [:idle, :thinking, :acting, :awaiting_tool, :done]
    assert length(status.plan) == 3

    # Get detailed info
    {:ok, info} = Agent.info(run_id)

    assert info.id == run_id
    assert info.goal == "Test basic agent functionality"
    assert is_integer(info.steps_completed)
    assert is_map(info.budgets)

    # Cancel the run
    :ok = Agent.cancel(run_id)

    # Verify it's cancelled
    {:ok, final_status} = Agent.status(run_id)
    assert final_status.status == :cancelled
  end

  @tag :skip
  test "agent runs with basic loop functionality", %{service_config: service_config} do
    # This test is skipped because it requires real LLM calls
    # The agent will fail when trying to make LLM calls with test API keys

    run_id = Ecto.UUID.generate()

    # Start an agent run that should execute a few steps
    {:ok, _pid} =
      Agent.start_run(%{
        goal: "Search for and analyze main function",
        run_type: "test",
        plan: ["search codebase", "read relevant files", "summarize findings"],
        run_id: run_id,
        service_config: service_config,
        initial_messages: [
          %{role: :user, content: "search for main function"}
        ]
      })

    # Give it time to execute a few steps
    Process.sleep(500)

    # Check that it has made some progress
    {:ok, info} = Agent.info(run_id)

    # Should have executed at least one step
    assert info.steps_completed >= 1

    # Should have some tokens used
    assert info.tokens_used >= 0

    # Cancel to clean up
    Agent.cancel(run_id)
  end

  test "can pause and resume agent runs", %{service_config: service_config} do
    run_id = Ecto.UUID.generate()

    # Start an agent run
    {:ok, _pid} =
      Agent.start_run(%{
        goal: "Test pause/resume functionality",
        run_type: "test",
        plan: ["step 1", "step 2", "step 3"],
        run_id: run_id,
        service_config: service_config
      })

    # Give it a moment to start
    Process.sleep(100)

    # Pause it
    :ok = Agent.pause(run_id)

    {:ok, status} = Agent.status(run_id)
    assert status.status == :paused

    # Resume it
    :ok = Agent.resume(run_id)

    {:ok, status} = Agent.status(run_id)
    assert status.status == :idle

    # Cancel to clean up
    Agent.cancel(run_id)
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

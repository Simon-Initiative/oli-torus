# Acceptance coverage: AC-012.
defmodule Oli.GenAI.ExecutionTest do
  use ExUnit.Case, async: false
  alias Oli.GenAI.Execution
  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}

  defmodule Completion do
    def generate(_, _, _, opts), do: {:ok, opts}

    def stream(_, _, _, handler) do
      handler.({:tokens_received, "hello"})
      handler.({:error, :transport_error})
      :ok
    end
  end

  defmodule SlowCompletion do
    def generate(_, _, _, _), do: Process.sleep(:infinity)
  end

  defmodule BrokenCompletion do
    def generate(_, _, _, _), do: raise("private provider response")
  end

  setup do
    provider = %Oli.GenAI.Provider{id: 2, adapter: :null}
    model = %RegisteredModel{id: 1, provider_id: provider.id, model: "local"}
    config = %ServiceConfig{id: 1, primary_model: model, secondary_model: nil, backup_model: nil}
    loaded = %{providers: [%{provider: provider, model: model}], service_configs: [config]}
    manager = start_supervised!({Oli.GenAI.PoolManager, name: nil, namespace: make_ref()})
    tasks = start_supervised!({Task.Supervisor, max_children: 1})

    start_supervised!(
      {Oli.GenAI.Runtime,
       source: fn -> loaded end, pool_manager: manager, task_supervisor: tasks, enabled: false}
    )

    assert :ok = Oli.GenAI.Runtime.reconcile()
    %{config: config}
  end

  test "forwards generation options and actual selection metadata", c do
    parent = self()
    opts = [temperature: 0.3, response_format: %{type: "json_object"}]

    assert {:ok, %{content: ^opts, metadata: %{registered_model_id: 1}}} =
             Execution.generate_with_metadata(%{}, [], [], c.config,
               provider_opts: opts,
               completions_mod: Completion,
               on_plan: fn plan -> send(parent, {:selected, plan.selected_model.id}) end
             )

    assert_received {:selected, 1}
  end

  test "a failure after output is an interrupted stream", c do
    parent = self()

    assert {:error, :interrupted_stream} =
             Execution.stream(%{}, [], [], c.config, fn event -> send(parent, event) end,
               completions_mod: Completion
             )

    assert_received {:tokens_received, "hello"}
    refute_received {:error, _}
  end

  test "application exceptions are safe errors and total waiting is bounded", c do
    assert {:error, :application_error} =
             Execution.generate(%{}, [], [], c.config, completions_mod: BrokenCompletion)

    assert {:error, :inference_deadline} =
             Execution.generate(%{}, [], [], c.config,
               completions_mod: SlowCompletion,
               total_timeout_ms: 30
             )

    assert {:error, :invalid_deadline} =
             Execution.generate(%{}, [], [], c.config, total_timeout_ms: 0)
  end
end

# Acceptance coverage: AC-019.
defmodule Oli.GenAI.ProviderTelemetryTest do
  use ExUnit.Case, async: false
  alias Oli.GenAI.{HealthMonitor, PoolManager, Provider, Runtime}
  alias Oli.GenAI.Completions.RegisteredModel

  setup do
    events = [
      [:oli, :genai, :health, :probe],
      [:oli, :genai, :health, :state_change],
      [:oli, :genai, :configuration, :reconciled],
      [:oli, :genai, :pool, :lifecycle]
    ]

    id = {__MODULE__, make_ref()}
    :ok = :telemetry.attach_many(id, events, &__MODULE__.record_event/4, self())
    on_exit(fn -> :telemetry.detach(id) end)
    :ok
  end

  test "probe and state-change events contain bounded safe categories without raw credentials or errors" do
    tasks = start_supervised!({Task.Supervisor, max_children: 1})
    provider = provider()
    model = %RegisteredModel{id: 2, provider: :open_ai, model: "probe"}

    start_supervised!(
      {HealthMonitor,
       config: %{provider: provider, model: model, enabled: true},
       task_supervisor: tasks,
       jitter_ms: 0,
       probe: fn _, _ -> {:error, %{"message" => "raw-sensitive-payload"}} end}
    )

    assert_receive {:event, [:oli, :genai, :health, :probe], measurements, metadata}, 2_000
    assert is_integer(measurements.duration_ms)
    assert metadata.provider_id == provider.id
    assert metadata.category == :probe_error
    assert metadata.outcome == :error
    refute inspect({measurements, metadata}) =~ provider.api_key
    refute inspect({measurements, metadata}) =~ "raw-sensitive-payload"

    assert_receive {:event, [:oli, :genai, :health, :state_change], %{count: 1},
                    %{state: :unavailable}},
                   2_000

    refute_receive {:event, [:oli, :genai, :health, :probe], _, _}, 30
  end

  test "successful node reconciliation emits one safe event per pass" do
    manager = start_supervised!({PoolManager, name: nil, namespace: make_ref(), poll_ms: 10})
    tasks = start_supervised!({Task.Supervisor, max_children: 1})

    config = %{
      providers: [
        %{
          provider: provider(),
          model: %RegisteredModel{id: 2, provider: :open_ai, model: "probe"}
        }
      ],
      service_configs: []
    }

    runtime =
      start_supervised!(
        {Runtime,
         name: nil,
         pool_manager: manager,
         task_supervisor: tasks,
         enabled: false,
         source: fn -> config end,
         interval_ms: 60_000}
      )

    assert_receive {:event, [:oli, :genai, :configuration, :reconciled], measurements,
                    %{outcome: :ok} = metadata},
                   2_000

    assert measurements.providers == 1
    assert measurements.service_configs == 0
    assert is_integer(measurements.duration_ms)

    refute inspect({measurements, metadata}) =~
             provider().api_key

    assert :ok = Runtime.reconcile(runtime)

    assert_receive {:event, [:oli, :genai, :configuration, :reconciled], _, %{outcome: :ok}},
                   2_000

    refute_receive {:event, [:oli, :genai, :configuration, :reconciled], _, _}, 30
  end

  @doc false
  def record_event(event, measurements, metadata, pid),
    do: send(pid, {:event, event, measurements, metadata})

  defp provider do
    %Provider{
      id: 1,
      name: "Telemetry",
      adapter: :open_ai,
      base_url: "http://127.0.0.1:9999",
      api_key: "telemetry-secret",
      failure_threshold: 1,
      probe_interval_ms: 60_000,
      probe_failure_interval_ms: 60_000
    }
  end
end

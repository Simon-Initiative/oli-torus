defmodule Oli.GenAI.AdmissionControlTest do
  use ExUnit.Case, async: false

  alias Oli.GenAI.AdmissionControl

  setup do
    ensure_started(AdmissionControl)
    clear_tables()
    :ok
  end

  test "increments and decrements request counters concurrently" do
    service_config_id = 101

    1..100
    |> Task.async_stream(
      fn _ ->
        AdmissionControl.increment_requests(service_config_id)
        AdmissionControl.decrement_requests(service_config_id)
      end,
      timeout: 5_000
    )
    |> Enum.to_list()

    assert AdmissionControl.counts(service_config_id).requests == 0
  end

  test "stream counters are tracked separately" do
    service_config_id = 102

    AdmissionControl.increment_requests(service_config_id)
    AdmissionControl.increment_streams(service_config_id)

    assert AdmissionControl.counts(service_config_id) == %{requests: 1, streams: 1}

    AdmissionControl.decrement_streams(service_config_id)
    AdmissionControl.decrement_requests(service_config_id)

    assert AdmissionControl.counts(service_config_id) == %{requests: 0, streams: 0}
  end

  defp ensure_started(mod) do
    case Process.whereis(mod) do
      nil -> start_supervised!(mod)
      _pid -> :ok
    end
  end

  defp clear_tables do
    if :ets.whereis(:genai_counters) != :undefined do
      :ets.delete_all_objects(:genai_counters)
    end

    if :ets.whereis(:genai_breaker_snapshots) != :undefined do
      :ets.delete_all_objects(:genai_breaker_snapshots)
    end
  end
end

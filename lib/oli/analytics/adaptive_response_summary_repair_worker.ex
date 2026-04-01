defmodule Oli.Analytics.AdaptiveResponseSummaryRepairWorker do
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [
      fields: [:args, :worker],
      keys: [:activity_resource_id, :repair_version],
      period: 600
    ]

  require Logger

  alias Oli.Analytics.Summary

  @repair_version 1

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"activity_resource_id" => activity_resource_id}}) do
    case Summary.rebuild_adaptive_response_summaries_for_activity(activity_resource_id) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Adaptive response summary repair failed for activity #{activity_resource_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def schedule(activity_resource_id) when is_integer(activity_resource_id) do
    %{
      activity_resource_id: activity_resource_id,
      repair_version: @repair_version
    }
    |> new()
    |> Oban.insert()
  end
end

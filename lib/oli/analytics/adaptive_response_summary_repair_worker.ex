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

  import Ecto.Query

  alias Oli.Analytics.Summary
  alias Oli.Repo
  alias Oban.Job

  @repair_version 1
  @active_states ~w(available scheduled executing retryable)

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

  def in_progress?(activity_resource_id) when is_integer(activity_resource_id) do
    from(j in Job,
      where: j.worker == ^to_string(__MODULE__),
      where: j.state in ^@active_states,
      where:
        fragment(
          "?->>'activity_resource_id' = ?",
          j.args,
          ^Integer.to_string(activity_resource_id)
        ),
      where: fragment("?->>'repair_version' = ?", j.args, ^Integer.to_string(@repair_version)),
      select: 1,
      limit: 1
    )
    |> Repo.exists?()
  end
end

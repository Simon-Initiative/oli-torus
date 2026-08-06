defmodule Oli.Delivery.Experiments.RewardHandoffWorker do
  @moduledoc """
  Processes experiment rewards after activity evaluation commits.

  Jobs contain a normalized batch of activity-attempt IDs. Reward and policy updates
  are derived from immutable evaluated-attempt state and are idempotent at the
  experiment boundary.
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 5,
    unique: [
      fields: [:args, :worker],
      keys: [:activity_attempt_ids],
      period: :infinity
    ]

  require Logger

  alias Oli.Delivery.Experiments.RewardHandoff

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"activity_attempt_ids" => [activity_attempt_id]}}) do
    RewardHandoff.record_evaluated_activity(activity_attempt_id)
  end

  def perform(%Oban.Job{args: %{"activity_attempt_ids" => activity_attempt_ids}}) do
    RewardHandoff.record_evaluated_activities(activity_attempt_ids)
  end

  def enqueue(activity_attempt_id) when is_integer(activity_attempt_id) do
    enqueue([activity_attempt_id])
  end

  def enqueue(activity_attempt_ids) when is_list(activity_attempt_ids) do
    activity_attempt_ids =
      activity_attempt_ids
      |> Enum.filter(&is_integer/1)
      |> Enum.uniq()
      |> Enum.sort()

    case activity_attempt_ids do
      [] ->
        :ok

      activity_attempt_ids ->
        activity_attempt_ids
        |> then(&new(%{activity_attempt_ids: &1}))
        |> Oban.insert()
        |> case do
          {:ok, _job} ->
            :ok

          {:error, reason} = error ->
            Logger.warning(
              "A/B testing reward handoff could not be enqueued: #{inspect(%{activity_attempt_ids: activity_attempt_ids, reason: reason})}"
            )

            error
        end
    end
  end
end

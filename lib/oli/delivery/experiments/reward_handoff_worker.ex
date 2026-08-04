defmodule Oli.Delivery.Experiments.RewardHandoffWorker do
  @moduledoc """
  Processes experiment rewards after activity evaluation commits.

  Jobs are unique per activity attempt because reward and policy updates are derived
  from immutable evaluated-attempt state and are idempotent at the experiment boundary.
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 5,
    unique: [
      fields: [:args, :worker],
      keys: [:activity_attempt_id],
      period: :infinity
    ]

  require Logger

  alias Oli.Delivery.Experiments.RewardHandoff

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"activity_attempt_id" => activity_attempt_id}}) do
    RewardHandoff.record_evaluated_activity(activity_attempt_id)
  end

  def enqueue(activity_attempt_id) when is_integer(activity_attempt_id) do
    activity_attempt_id
    |> then(&new(%{activity_attempt_id: &1}))
    |> Oban.insert()
    |> case do
      {:ok, _job} ->
        :ok

      {:error, reason} = error ->
        Logger.warning(
          "A/B testing reward handoff could not be enqueued: #{inspect(%{activity_attempt_id: activity_attempt_id, reason: reason})}"
        )

        error
    end
  end
end

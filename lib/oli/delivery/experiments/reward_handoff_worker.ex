defmodule Oli.Delivery.Experiments.RewardHandoffWorker do
  @moduledoc """
  Processes experiment rewards after scored-page evaluation commits.

  Jobs contain only a trusted resource-attempt ID. Reward and policy updates are
  derived from persisted server state and are idempotent at the experiment boundary.
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 5,
    unique: [
      fields: [:args, :worker],
      keys: [:resource_attempt_id],
      period: :infinity
    ]

  require Logger

  alias Oli.Delivery.Experiments.RewardHandoff

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"resource_attempt_id" => resource_attempt_id}}) do
    RewardHandoff.record_evaluated_resource_attempt(resource_attempt_id)
  end

  @doc "Enqueues reward processing when the attempt has an active Thompson assessment binding."
  @spec maybe_enqueue(integer(), integer()) :: :ok | {:error, term()}
  def maybe_enqueue(resource_attempt_id, section_id)
      when is_integer(resource_attempt_id) and is_integer(section_id) do
    case RewardHandoff.relevant_resource_attempt?(resource_attempt_id, section_id) do
      false ->
        :ok

      true ->
        %{resource_attempt_id: resource_attempt_id}
        |> new()
        |> Oban.insert()
        |> case do
          {:ok, _job} ->
            :ok

          {:error, reason} = error ->
            Logger.warning(
              "A/B testing reward handoff could not be enqueued: #{inspect(%{resource_attempt_id: resource_attempt_id, reason: reason})}"
            )

            error
        end
    end
  end
end

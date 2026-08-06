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

  import Ecto.Query, warn: false

  require Logger

  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.Experiments.RewardHandoff
  alias Oli.Delivery.Sections
  alias Oli.Repo

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
    activity_attempt_ids
    |> normalize_activity_attempt_ids()
    |> activity_attempt_ids_by_section()
    |> Enum.reduce_while(:ok, fn {section_id, section_activity_attempt_ids}, :ok ->
      case enqueue(section_activity_attempt_ids, section_id) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  def enqueue(activity_attempt_id, section_id) when is_integer(activity_attempt_id) do
    enqueue([activity_attempt_id], section_id)
  end

  def enqueue(activity_attempt_ids, section_id)
      when is_list(activity_attempt_ids) and is_integer(section_id) do
    activity_attempt_ids =
      normalize_activity_attempt_ids(activity_attempt_ids)

    case {activity_attempt_ids, Sections.has_experiment?(section_id)} do
      {[], _has_experiment?} ->
        :ok

      {_activity_attempt_ids, false} ->
        :ok

      {activity_attempt_ids, true} ->
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

  defp normalize_activity_attempt_ids(activity_attempt_ids) do
    activity_attempt_ids
    |> Enum.filter(&is_integer/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp activity_attempt_ids_by_section([]), do: []

  defp activity_attempt_ids_by_section(activity_attempt_ids) do
    from(activity_attempt in ActivityAttempt,
      join: resource_attempt in ResourceAttempt,
      on: resource_attempt.id == activity_attempt.resource_attempt_id,
      join: resource_access in ResourceAccess,
      on: resource_access.id == resource_attempt.resource_access_id,
      where: activity_attempt.id in ^activity_attempt_ids,
      select: {resource_access.section_id, activity_attempt.id}
    )
    |> Repo.all()
    |> Enum.group_by(fn {section_id, _activity_attempt_id} -> section_id end, fn {
                                                                                   _section_id,
                                                                                   activity_attempt_id
                                                                                 } ->
      activity_attempt_id
    end)
  end
end

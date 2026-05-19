defmodule Oli.Delivery.Attempts.ActivityAttemptState do
  @moduledoc """
  Read model for learner activity attempt state within a page attempt.

  This module exposes the delivery state that activity components render from,
  without coupling callers to activity-specific UI implementations.
  """

  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, PartAttempt, ResourceAttempt}
  alias Oli.Delivery.Attempts.PageLifecycle.Hierarchy

  defstruct [
    :activity_resource_id,
    :activity_attempt_guid,
    :activity_lifecycle_state,
    :activity_score,
    :activity_out_of,
    :part_id,
    :part_attempt_guid,
    :part_lifecycle_state,
    :part_score,
    :part_out_of,
    :response,
    :answerable
  ]

  @type t :: %__MODULE__{
          activity_resource_id: integer(),
          activity_attempt_guid: String.t(),
          activity_lifecycle_state: atom(),
          activity_score: number() | nil,
          activity_out_of: number() | nil,
          part_id: String.t() | nil,
          part_attempt_guid: String.t() | nil,
          part_lifecycle_state: atom() | nil,
          part_score: number() | nil,
          part_out_of: number() | nil,
          response: map() | nil,
          answerable: boolean()
        }

  @spec for_activity(ResourceAttempt.t(), integer(), String.t() | nil) ::
          {:ok, t()} | {:error, :not_found}
  def for_activity(%ResourceAttempt{} = resource_attempt, activity_resource_id, part_id \\ nil) do
    resource_attempt.id
    |> Hierarchy.get_latest_attempts()
    |> Map.get(activity_resource_id)
    |> case do
      {%ActivityAttempt{} = activity_attempt, part_attempts} ->
        part_attempt = select_part_attempt(part_attempts, part_id)

        {:ok, build(activity_attempt, part_attempt)}

      _ ->
        {:error, :not_found}
    end
  end

  defp select_part_attempt(part_attempts, nil) when is_map(part_attempts) do
    part_attempts
    |> Map.values()
    |> List.first()
  end

  defp select_part_attempt(part_attempts, part_id) when is_map(part_attempts) do
    Map.get(part_attempts, part_id)
  end

  defp build(%ActivityAttempt{} = activity_attempt, %PartAttempt{} = part_attempt) do
    %__MODULE__{
      activity_resource_id: activity_attempt.resource_id,
      activity_attempt_guid: activity_attempt.attempt_guid,
      activity_lifecycle_state: activity_attempt.lifecycle_state,
      activity_score: activity_attempt.score,
      activity_out_of: activity_attempt.out_of,
      part_id: part_attempt.part_id,
      part_attempt_guid: part_attempt.attempt_guid,
      part_lifecycle_state: part_attempt.lifecycle_state,
      part_score: part_attempt.score,
      part_out_of: part_attempt.out_of,
      response: part_attempt.response,
      answerable: answerable?(activity_attempt, part_attempt)
    }
  end

  defp build(%ActivityAttempt{} = activity_attempt, nil) do
    %__MODULE__{
      activity_resource_id: activity_attempt.resource_id,
      activity_attempt_guid: activity_attempt.attempt_guid,
      activity_lifecycle_state: activity_attempt.lifecycle_state,
      activity_score: activity_attempt.score,
      activity_out_of: activity_attempt.out_of,
      answerable: false
    }
  end

  defp answerable?(%ActivityAttempt{lifecycle_state: :active}, %PartAttempt{
         lifecycle_state: :active,
         date_evaluated: nil
       }),
       do: true

  defp answerable?(_activity_attempt, _part_attempt), do: false
end

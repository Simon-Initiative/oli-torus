defmodule Oli.Scenarios.LearnerActions do
  @moduledoc """
  Scenario-owned learner lifecycle operations shared by directives and course simulation.

  Callers provide resolved domain records and a session identifier. This module never
  resolves scenario names or enrolls a learner implicitly.
  """

  alias Oli.Delivery.Attempts.ActivityLifecycle
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Scenarios.Directives.AttemptSupport

  @doc "Visits a delivered page and returns its current attempt state."
  @spec visit(map(), map(), map(), String.t(), keyword()) :: {:ok, map()} | {:blocked, term()}
  def visit(section, page, user, session_id, opts \\ []) do
    case AttemptSupport.visit_page(user, section, page,
           datashop_session_id: session_id,
           password: opts[:password]
         ) do
      {:ok, {progress_state, attempt_state}} ->
        {:ok,
         %{
           progress_state: progress_state,
           attempt_state: attempt_state,
           resource_attempt: Map.get(attempt_state, :resource_attempt),
           hierarchy: Map.get(attempt_state, :attempt_hierarchy, %{})
         }}

      {:error, reason} ->
        {:blocked, reason}
    end
  end

  @doc "Evaluates the supplied active part inputs through the normal activity lifecycle."
  @spec submit_activity(map(), map(), [map()], String.t()) :: {:ok, term()} | {:error, term()}
  def submit_activity(section, activity_attempt, part_inputs, session_id) do
    Evaluate.evaluate_activity(
      section.slug,
      activity_attempt.attempt_guid,
      part_inputs,
      session_id
    )
  end

  @doc "Evaluates one active part through the delivery submit-per-part lifecycle."
  @spec submit_part(map(), map(), map(), String.t()) :: {:ok, term()} | {:error, term()}
  def submit_part(section, activity_attempt, part_input, session_id) do
    Evaluate.evaluate_from_input(
      section.slug,
      activity_attempt.attempt_guid,
      [part_input],
      session_id
    )
  end

  @doc "Saves active assessment responses for evaluation during page finalization."
  @spec save_activity([map()]) :: {:ok, term()} | {:error, term()}
  def save_activity(part_inputs) do
    inputs =
      Enum.map(part_inputs, fn %{
                                 attempt_guid: attempt_guid,
                                 input: %StudentInput{input: input, files: files}
                               } ->
        %{
          attempt_guid: attempt_guid,
          response: %{"input" => input, "files" => files || []}
        }
      end)

    ActivityLifecycle.save_student_input(inputs, only_active: true)
  end

  @doc "Requests the next hint for an active part attempt."
  @spec request_hint(map(), map()) :: {:ok, term()} | {:error, term()}
  def request_hint(activity_attempt, part_attempt) do
    ActivityLifecycle.request_hint(activity_attempt.attempt_guid, part_attempt.attempt_guid)
  end

  @doc "Resets an evaluated activity and returns the newly active activity state."
  @spec reset_activity(map(), map(), String.t()) :: {:ok, term()} | {:error, term()}
  def reset_activity(section, activity_attempt, session_id) do
    ActivityLifecycle.reset_activity(section.slug, activity_attempt.attempt_guid, session_id)
  end

  @doc "Resets one evaluated part while preserving its parent activity attempt."
  @spec reset_part(map(), map(), String.t()) :: {:ok, term()} | {:error, term()}
  def reset_part(activity_attempt, part_attempt, session_id) do
    ActivityLifecycle.reset_part(
      activity_attempt.attempt_guid,
      part_attempt.attempt_guid,
      session_id
    )
  end

  @doc "Finalizes a scored page attempt through the normal page lifecycle."
  @spec finalize(map(), map(), String.t()) :: {:ok, term()} | {:error, term()}
  def finalize(section, resource_attempt, session_id) do
    PageLifecycle.finalize(section.slug, resource_attempt.attempt_guid, session_id)
  end

  @doc "Normalizes activity attempts in the authored activity-reference order when supplied."
  @spec activities(map(), [integer()]) :: [%{activity_attempt: map(), part_attempts: [map()]}]
  def activities(hierarchy, authored_resource_ids \\ []) when is_map(hierarchy) do
    positions = authored_resource_ids |> Enum.with_index() |> Map.new()

    normalized =
      hierarchy
      |> Map.values()
      |> Enum.flat_map(fn
        {%{} = activity_attempt, part_attempts} when is_map(part_attempts) ->
          [%{activity_attempt: activity_attempt, part_attempts: Map.values(part_attempts)}]

        %{} = activity_attempt ->
          [
            %{
              activity_attempt: activity_attempt,
              part_attempts: Map.get(activity_attempt, :part_attempts, [])
            }
          ]

        _ ->
          []
      end)

    Enum.sort_by(normalized, fn %{activity_attempt: attempt} ->
      {Map.get(positions, attempt.resource_id, map_size(positions)), attempt.resource_id}
    end)
  end
end

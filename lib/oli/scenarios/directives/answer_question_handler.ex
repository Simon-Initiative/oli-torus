defmodule Oli.Scenarios.Directives.AnswerQuestionHandler do
  @moduledoc """
  Handles answer_question directives for simulating students answering questions.

  This handler retrieves the AttemptState from a previous view_practice_page call,
  finds the relevant ActivityAttempt, and delegates to
  Oli.Delivery.Attempts.ActivityLifecycle.Evaluate.evaluate_activity/4 to submit
  and evaluate the student's response.
  """

  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, AnswerQuestionDirective}
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Oli.Delivery.Attempts.Core.StudentInput

  @doc """
  Handles an answer_question directive by submitting and evaluating a student's response.

  Returns {:ok, updated_state} on success, {:error, reason} on failure.
  """
  def handle(%AnswerQuestionDirective{} = directive, %ExecutionState{} = state) do
    with {:ok, attempt_state} <- get_attempt_state(state, directive),
         {:ok, section} <- get_section(state, directive.section),
         {:ok, activity_revision} <- get_activity_revision(state, directive),
         {:ok, activity_attempt_info} <- find_activity_attempt(attempt_state, activity_revision),
         # Don't get part_id from revision, get it from the actual attempt
         {:ok, formatted_response} <- format_response(directive.response, activity_revision),
         {:ok, evaluation_result} <-
           submit_answer(
             section,
             activity_attempt_info,
             formatted_response,
             activity_revision
           ) do
      # Store the evaluation result
      key = {directive.student, directive.section, directive.page, directive.activity_virtual_id}
      updated_evaluations = Map.put(state.activity_evaluations, key, evaluation_result)

      {:ok, %{state | activity_evaluations: updated_evaluations}}
    else
      {:error, reason} ->
        {:error, "Failed to answer question: #{reason}"}
    end
  end

  # Get the AttemptState from a previous view_practice_page
  defp get_attempt_state(state, directive) do
    key = {directive.student, directive.section, directive.page}

    case Map.get(state.page_attempts, key) do
      nil ->
        {:error, "No attempt found - student must view page first"}

      {:not_started, _} ->
        {:error, "Page not started - cannot answer questions"}

      {_status, attempt_state} ->
        {:ok, attempt_state}
    end
  end

  # Get section from state
  defp get_section(state, section_name) do
    case Map.get(state.sections, section_name) do
      nil -> {:error, "Section '#{section_name}' not found"}
      section -> {:ok, section}
    end
  end

  # Get activity revision from virtual_id
  defp get_activity_revision(state, directive) do
    # We need to find the project name for this section
    # For now, we'll search all activity_virtual_ids
    activity_revision =
      state.activity_virtual_ids
      |> Enum.find_value(fn
        {{_project_name, virtual_id}, revision}
        when virtual_id == directive.activity_virtual_id ->
          revision

        _ ->
          nil
      end)

    case activity_revision do
      nil -> {:error, "Activity with virtual_id '#{directive.activity_virtual_id}' not found"}
      revision -> {:ok, revision}
    end
  end

  # Find the ActivityAttempt for the given activity
  defp find_activity_attempt(attempt_state, activity_revision) do
    resource_id = activity_revision.resource_id

    case Map.get(attempt_state.attempt_hierarchy, resource_id) do
      nil ->
        # If not found by resource_id, search for matching activity by content
        find_activity_by_content(attempt_state, activity_revision)

      # Basic page format: {%ActivityAttempt{}, part_attempts}
      {%{attempt_guid: guid} = activity_attempt, part_attempts} ->
        activity_attempt_with_parts = %{
          activity_attempt
          | part_attempts: Map.values(part_attempts)
        }

        {:ok, %{attempt_guid: guid, activity_attempt: activity_attempt_with_parts}}

      # Adaptive page format: %{attemptGuid: guid, ...}
      %{attemptGuid: guid} = thin_info ->
        {:ok, %{attempt_guid: guid, activity_attempt: thin_info}}

      _ ->
        {:error, "Unexpected attempt hierarchy format"}
    end
  end

  # Search for activity attempt by matching content properties
  defp find_activity_by_content(attempt_state, activity_revision) do
    # Try to match by activity type and question content
    activity_type = activity_revision.content["activityType"] || activity_revision.content["type"]

    matching_attempt =
      attempt_state.attempt_hierarchy
      |> Map.values()
      |> Enum.find(fn
        {%{revision: %{content: content}}, _} ->
          # Match by activity type
          (content["activityType"] || content["type"]) == activity_type

        %{revision: %{content: content}} ->
          # Adaptive format
          (content["activityType"] || content["type"]) == activity_type

        _ ->
          false
      end)

    case matching_attempt do
      {%{attempt_guid: guid} = activity_attempt, part_attempts} ->
        activity_attempt_with_parts = %{
          activity_attempt
          | part_attempts: Map.values(part_attempts)
        }

        {:ok, %{attempt_guid: guid, activity_attempt: activity_attempt_with_parts}}

      %{attemptGuid: guid} = thin_info ->
        {:ok, %{attempt_guid: guid, activity_attempt: thin_info}}

      nil ->
        # Fall back to single activity logic if only one activity exists
        case Map.values(attempt_state.attempt_hierarchy) do
          [{%{attempt_guid: guid} = activity_attempt, part_attempts}] ->
            activity_attempt_with_parts = %{
              activity_attempt
              | part_attempts: Map.values(part_attempts)
            }

            {:ok, %{attempt_guid: guid, activity_attempt: activity_attempt_with_parts}}

          [%{attemptGuid: guid} = thin_info] ->
            {:ok, %{attempt_guid: guid, activity_attempt: thin_info}}

          [] ->
            {:error, "No activity attempts found in hierarchy"}

          _ ->
            {:error, "Could not find matching activity attempt for type: #{activity_type}"}
        end
    end
  end

  # Format the response based on activity type
  defp format_response(response, activity_revision) do
    activity_type =
      activity_revision.content["activityType"] ||
        activity_revision.content["type"]

    # Simplified formatting - MCQ types get string formatting, everything else is plain
    if activity_type in ["oli_multiple_choice", "oli_multi_choice"] do
      {:ok, "#{response}"}
    else
      {:ok, response}
    end
  end

  # Submit the answer using evaluate_activity
  defp submit_answer(section, activity_attempt_info, formatted_response, activity_revision) do
    # Generate a unique datashop session ID
    datashop_session_id = "session_#{System.unique_integer([:positive])}"

    part_attempts =
      case activity_attempt_info.activity_attempt do
        %{part_attempts: part_attempts} when is_list(part_attempts) ->
          part_attempts

        _ ->
          []
      end

    if part_attempts == [] do
      {:error, "Could not find part attempt"}
    else
      part_inputs = build_part_inputs(part_attempts, formatted_response, activity_revision)

      # Call evaluate_activity
      case Evaluate.evaluate_activity(
             section.slug,
             activity_attempt_info.attempt_guid,
             part_inputs,
             datashop_session_id
           ) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> {:error, "Evaluation failed: #{inspect(reason)}"}
      end
    end
  end

  defp build_part_inputs(part_attempts, response, activity_revision) when is_map(response) do
    inputs_by_part_id = inputs_by_part_id(activity_revision.content)

    part_attempts
    |> Enum.flat_map(fn part_attempt ->
      input_ids = Map.get(inputs_by_part_id, part_attempt.part_id, [])

      value =
        Map.get(response, part_attempt.part_id) ||
          Enum.find_value(input_ids, fn input_id -> Map.get(response, input_id) end)

      case value do
        nil ->
          []

        value ->
          [
            %{
              attempt_guid: part_attempt.attempt_guid,
              input: %StudentInput{input: value}
            }
          ]
      end
    end)
    |> case do
      [] when length(part_attempts) == 1 ->
        [
          %{
            attempt_guid: hd(part_attempts).attempt_guid,
            input: %StudentInput{input: Jason.encode!(response)}
          }
        ]

      part_inputs ->
        part_inputs
    end
  end

  defp build_part_inputs([part_attempt | _], response, _activity_revision) do
    [
      %{
        attempt_guid: part_attempt.attempt_guid,
        input: %StudentInput{
          input: response
        }
      }
    ]
  end

  defp inputs_by_part_id(%{"inputs" => inputs}) when is_list(inputs) do
    Enum.reduce(inputs, %{}, fn input, acc ->
      case {Map.get(input, "id"), Map.get(input, "partId")} do
        {input_id, part_id} when is_binary(input_id) and is_binary(part_id) ->
          Map.update(acc, part_id, [input_id], &[input_id | &1])

        _ ->
          acc
      end
    end)
  end

  defp inputs_by_part_id(_), do: %{}
end

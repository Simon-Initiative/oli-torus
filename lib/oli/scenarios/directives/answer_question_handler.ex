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
  alias Oli.Scenarios.Directives.{ActivityAttemptSupport, AttemptSupport}

  @doc """
  Handles an answer_question directive by submitting and evaluating a student's response.

  Returns {:ok, updated_state} on success, {:error, reason} on failure.
  """
  def handle(%AnswerQuestionDirective{} = directive, %ExecutionState{} = state) do
    with {:ok, attempt_state} <-
           ActivityAttemptSupport.get_attempt_state(
             state,
             directive.student,
             directive.section,
             directive.page
           ),
         {:ok, section} <- AttemptSupport.get_section(state, directive.section),
         {:ok, activity_revision} <-
           ActivityAttemptSupport.get_activity_revision(state, directive.activity_virtual_id),
         {:ok, activity_attempt_info} <-
           ActivityAttemptSupport.find_activity_attempt(attempt_state, activity_revision),
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

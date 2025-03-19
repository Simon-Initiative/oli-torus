defmodule Oli.Delivery.Attempts.ActivityLifecycle.Utils do

  alias Oli.Delivery.Attempts.Core.{ActivityAttempt}
  alias Oli.Activities.Model
  alias Oli.Delivery.Evaluation.{EvaluationContext, Standard}
  alias Oli.Delivery.Evaluation.ExplanationContext
  alias Oli.Delivery.Evaluation.Explanation

  import Oli.Delivery.Attempts.Core

  # Filters out part_inputs whose attempts have already been evaluated.  This step
  # simply lowers the burden on an activity client for having to manage this - as
  # they now can instead just choose to always submit for evaluation all parts.
  def filter_already_evaluated(part_inputs, part_attempts) do
    already_evaluated =
      Enum.filter(part_attempts, fn p -> p.lifecycle_state == :evaluated end)
      |> Enum.map(fn e -> e.attempt_guid end)
      |> MapSet.new()

    Enum.filter(part_inputs, fn %{attempt_guid: attempt_guid} ->
      !MapSet.member?(already_evaluated, attempt_guid)
    end)
  end


  def do_evaluate_submissions(
         activity_attempt,
         part_inputs,
         part_attempts,
         effective_settings \\ nil
       )

  def do_evaluate_submissions(activity_attempt, part_inputs, part_attempts, nil) do
    effective_settings =
      Oli.Delivery.Settings.get_combined_settings(activity_attempt.resource_attempt)

    do_evaluate_submissions(activity_attempt, part_inputs, part_attempts, effective_settings)
  end

  def do_evaluate_submissions(
         %ActivityAttempt{
           resource_attempt: resource_attempt,
           attempt_number: attempt_number
         } = activity_attempt,
         part_inputs,
         part_attempts,
         effective_settings
       ) do
    activity_model = select_model(activity_attempt)

    {:ok, %Model{parts: parts}} = Model.parse(activity_model)

    evaluations =
      case Model.parse(activity_model) do
        {:ok, %Model{rules: []}} ->
          # We need to tie the attempt_guid from the part_inputs to the attempt_guid
          # from the %PartAttempt, and then the part id from the %PartAttempt to the
          # part id in the parsed model.
          part_map = Enum.reduce(parts, %{}, fn p, m -> Map.put(m, p.id, p) end)

          attempt_map =
            Enum.reduce(part_attempts, %{}, fn p, m -> Map.put(m, p.attempt_guid, p) end)

          # flat map the results since the results may contain an additional explanation action
          Enum.map(part_inputs, fn %{attempt_guid: attempt_guid, input: input} ->
            attempt = Map.get(attempt_map, attempt_guid)
            part = Map.get(part_map, attempt.part_id)

            context = %EvaluationContext{
              resource_attempt_number: resource_attempt.attempt_number,
              activity_attempt_number: attempt_number,
              activity_attempt_guid: activity_attempt.attempt_guid,
              part_attempt_number: attempt.attempt_number,
              part_attempt_guid: attempt.attempt_guid,
              page_id: effective_settings.resource_id,
              input: input.input
            }

            Standard.perform(attempt_guid, context, part)
            |> Explanation.maybe_set_feedback_action_explanation(%ExplanationContext{
              part: part,
              part_attempt: attempt,
              activity_attempt: activity_attempt,
              resource_attempt: resource_attempt,
              resource_revision: resource_attempt.revision,
              effective_settings: effective_settings
            })
          end)

        _ ->
          []
      end

    {:ok, evaluations}
  end

end

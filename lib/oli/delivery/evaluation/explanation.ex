defmodule Oli.Delivery.Evaluation.Explanation do
  alias Oli.Delivery.Evaluation.EvaluationContext
  alias Oli.Delivery.Evaluation.Actions.{ExplanationAction}
  alias Oli.Resources.ExplanationStrategy
  alias Oli.Activities.Model.Part
  alias Oli.Resources.Revision

  @doc """
  Determines whether an explanation should be paired along with the provided feedback using
  the given evaluation context. If an explanation condition is met, then this will return
  a 2-element list containing the given feedback and the matching explanation. If not, only
  the feedback is returned.
  """
  def maybe_pair_with_explanation(
        feedback,
        attempt_guid,
        %EvaluationContext{} = evaluation_context,
        %Part{} = part
      ) do
    case check_explanation_condition(evaluation_context) do
      {strategy, true} ->
        [
          {:ok,
           %ExplanationAction{
             type: "ExplanationAction",
             attempt_guid: attempt_guid,
             explanation: part.explanation,
             part_id: part.id,
             strategy: strategy
           }}
          | feedback
        ]

      {_strategy, false} ->
        feedback
    end
  end

  # show after max resource attempts exhausted strategy for scored pages
  # (ignore unscored pages for now)
  defp check_explanation_condition(%EvaluationContext{
         resource_revision: %Revision{
           graded: true,
           explanation_strategy: %ExplanationStrategy{
             type: :after_max_resource_attempts_exhausted
           },
           max_attempts: max_attempts
         },
         resource_attempt_number: resource_attempt_number
       }) do
    if resource_attempt_number >= max_attempts && max_attempts > 0 do
      {:after_max_resource_attempts_exhausted, true}
    else
      {:after_max_resource_attempts_exhausted, false}
    end
  end

  # show after set number of attempts strategy for scored pages
  defp check_explanation_condition(%EvaluationContext{
         resource_revision: %Revision{
           graded: true,
           explanation_strategy: %ExplanationStrategy{
             type: :after_set_num_attempts,
             set_num_attempts: set_num_attempts
           }
         },
         resource_attempt_number: resource_attempt_number
       }) do
    if resource_attempt_number >= set_num_attempts do
      {:after_set_num_attempts, true}
    else
      {:after_set_num_attempts, false}
    end
  end

  # show after set number of attempts strategy for unscored pages
  defp check_explanation_condition(%EvaluationContext{
         resource_revision: %Revision{
           graded: false,
           explanation_strategy: %ExplanationStrategy{
             type: :after_set_num_attempts,
             set_num_attempts: set_num_attempts
           }
         },
         activity_attempt_number: activity_attempt_number
       }) do
    if activity_attempt_number >= set_num_attempts do
      {:after_set_num_attempts, true}
    else
      {:after_set_num_attempts, false}
    end
  end

  # no matching strategies
  defp check_explanation_condition(_), do: {:none, false}
end

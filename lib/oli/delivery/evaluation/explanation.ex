defmodule Oli.Delivery.Evaluation.Explanation do
  alias Oli.Resources.ExplanationStrategy
  alias Oli.Resources.Revision
  alias Oli.Delivery.Evaluation.ExplanationContext
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ResourceAttempt}
  alias Oli.Delivery.Evaluation.Actions.FeedbackAction

  @doc """
  Determines whether an explanation should be paired along with the provided feedback using
  the given explanation context. If an explanation condition is met, then this will return
  a 2-element list containing the given feedback and the resulting explanation. If not,
  then a single element list containing the feedback is simply returned.
  """
  def maybe_set_feedback_explanation(
        {:ok, feedback},
        %ExplanationContext{
          part: part
        } = context
      ) do
    case check_explanation_condition(context) do
      {_strategy, true} ->
        {:ok, %FeedbackAction{feedback | explanation: part.explanation}}

      {_strategy, false} ->
        {:ok, feedback}
    end
  end

  def maybe_set_feedback_explanation(other, _), do: other

  # show after max resource attempts exhausted strategy for scored pages
  # (ignore unscored pages for now)
  defp check_explanation_condition(%ExplanationContext{
         resource_revision: %Revision{
           graded: true,
           explanation_strategy: %ExplanationStrategy{
             type: :after_max_resource_attempts_exhausted
           },
           max_attempts: max_attempts
         },
         resource_attempt: %ResourceAttempt{
           attempt_number: resource_attempt_number
         }
       }) do
    if resource_attempt_number >= max_attempts && max_attempts > 0 do
      {:after_max_resource_attempts_exhausted, true}
    else
      {:after_max_resource_attempts_exhausted, false}
    end
  end

  # show after set number of attempts strategy for scored pages
  defp check_explanation_condition(%ExplanationContext{
         resource_revision: %Revision{
           graded: true,
           explanation_strategy: %ExplanationStrategy{
             type: :after_set_num_attempts,
             set_num_attempts: set_num_attempts
           }
         },
         resource_attempt: %ResourceAttempt{
           attempt_number: resource_attempt_number
         }
       }) do
    if resource_attempt_number >= set_num_attempts do
      {:after_set_num_attempts, true}
    else
      {:after_set_num_attempts, false}
    end
  end

  # show after set number of attempts strategy for unscored pages
  defp check_explanation_condition(%ExplanationContext{
         resource_revision: %Revision{
           graded: false,
           explanation_strategy: %ExplanationStrategy{
             type: :after_set_num_attempts,
             set_num_attempts: set_num_attempts
           }
         },
         activity_attempt: %ActivityAttempt{
           attempt_number: activity_attempt_number
         }
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

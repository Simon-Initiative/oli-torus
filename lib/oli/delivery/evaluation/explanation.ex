defmodule Oli.Delivery.Evaluation.Explanation do
  alias Oli.Resources.ExplanationStrategy
  alias Oli.Resources.Revision
  alias Oli.Delivery.Evaluation.ExplanationContext
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ResourceAttempt}
  alias Oli.Delivery.Evaluation.Actions.FeedbackAction
  alias Oli.Delivery.Settings.Combined

  @doc """
  Determines whether an explanation should be shown using the given explanation context.
  If an explanation condition is met, then this will return the resulting explanation.
  Otherwise, returns `nil`.
  """
  def get_explanation(
        %ExplanationContext{
          part: part
        } = context
      ) do
    case check_explanation_condition(context) do
      {_strategy, true} ->
        part.explanation

      {_strategy, false} ->
        nil
    end
  end

  @doc """
  Determines whether an explanation should be paired along with the provided feedback using
  the given explanation context. If an explanation condition is met, then this will return
  a 2-element list containing the given feedback and the resulting explanation. If not,
  then a single element list containing the feedback is simply returned.
  """
  def maybe_set_feedback_action_explanation(
        {:ok, %FeedbackAction{} = feedback_action},
        %ExplanationContext{
          part: part
        } = context
      ) do
    case check_explanation_condition(context) do
      {_strategy, true} ->
        {:ok, %FeedbackAction{feedback_action | explanation: part.explanation}}

      {_strategy, false} ->
        {:ok, feedback_action}
    end
  end

  def maybe_set_feedback_action_explanation(other, _), do: other

  # show after max resource attempts exhausted strategy for scored pages
  # (ignore unscored pages for now)
  defp check_explanation_condition(%ExplanationContext{
         resource_revision: %Revision{
           graded: true
         },
         resource_attempt: %ResourceAttempt{
           attempt_number: resource_attempt_number
         },
         effective_settings: %Combined{
           explanation_strategy: %ExplanationStrategy{
             type: :after_max_resource_attempts_exhausted
           },
           max_attempts: max_attempts
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
           graded: true
         },
         resource_attempt: %ResourceAttempt{
           attempt_number: resource_attempt_number
         },
         effective_settings: %Combined{
           explanation_strategy: %ExplanationStrategy{
             type: :after_set_num_attempts,
             set_num_attempts: set_num_attempts
           }
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
           graded: false
         },
         activity_attempt: %ActivityAttempt{
           attempt_number: activity_attempt_number,
           part_attempts: part_attempts
         },
         part_attempt: part_attempt,
         effective_settings: %Combined{
           explanation_strategy: %ExplanationStrategy{
             type: :after_set_num_attempts,
             set_num_attempts: set_num_attempts
           }
         }
       }) do
    if length(part_attempts) > 1 do
      if part_attempt.attempt_number >= set_num_attempts,
        do: {:after_set_num_attempts, true},
        else: {:after_set_num_attempts, false}
    else
      if activity_attempt_number >= set_num_attempts,
        do: {:after_set_num_attempts, true},
        else: {:after_set_num_attempts, false}
    end
  end

  # no matching strategies
  defp check_explanation_condition(_), do: {:none, false}
end

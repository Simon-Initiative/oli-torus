defmodule Oli.Delivery.Attempts.ActivityLifecycle.Persistence do
  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Delivery.Evaluation.Actions.{
    FeedbackActionResult,
    NavigationActionResult,
    StateUpdateActionResult
  }

  alias Oli.Delivery.Attempts.Core.PartAttempt

  # Given a list of evaluations that match a list of part_input submissions,
  # persist the results of each evaluation to the corresponding part_attempt record
  # On success, continue persistence by calling a roll_up function that will may or
  # not roll up the results of the these part_attempts to the activity attempt
  #
  # The return value here is {:ok, [%{}]}, where the maps in the array are the
  # evaluation result that will be sent back to the client
  def persist_evaluations({:error, error}, _, _), do: {:error, error}

  def persist_evaluations({:ok, evaluations}, part_inputs, roll_up_fn) do
    evaluated_inputs = Enum.zip(part_inputs, evaluations)

    case Enum.reduce_while(evaluated_inputs, {:ok, []}, &persist_single_evaluation/2) do
      {:ok, results} -> roll_up_fn.({:ok, results})
      error -> error
    end
  end

  # Persist the result of a single evaluation for a single part_input submission.
  defp persist_single_evaluation({_, {:error, error}}, _), do: {:halt, {:error, error}}

  defp persist_single_evaluation(
         {_, {:ok, %NavigationActionResult{} = action_result}},
         {:ok, results}
       ) do
    {:cont, {:ok, results ++ [action_result]}}
  end

  defp persist_single_evaluation(
         {_, {:ok, %StateUpdateActionResult{} = action_result}},
         {:ok, results}
       ) do
    {:cont, {:ok, results ++ [action_result]}}
  end

  defp persist_single_evaluation(
         {%{attempt_guid: attempt_guid, input: input},
          {:ok,
           %FeedbackActionResult{
             feedback: feedback,
             score: score,
             out_of: out_of
           } = feedback_action}},
         {:ok, results}
       ) do
    now = DateTime.utc_now()

    case Repo.update_all(
           from(p in PartAttempt,
             where: p.attempt_guid == ^attempt_guid and is_nil(p.date_evaluated)
           ),
           set: [
             response: input,
             date_evaluated: now,
             score: score,
             out_of: out_of,
             feedback: feedback
           ]
         ) do
      nil ->
        {:halt, {:error, :error}}

      {1, _} ->
        {:cont, {:ok, results ++ [feedback_action]}}

      _ ->
        {:halt, {:error, :error}}
    end
  end
end

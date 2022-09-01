defmodule Oli.Delivery.Attempts.ActivityLifecycle.Persistence do
  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Delivery.Evaluation.Actions.{
    FeedbackAction,
    NavigationAction,
    StateUpdateAction,
    ExplanationAction,
    SubmissionAction
  }

  alias Oli.Delivery.Attempts.Core.PartAttempt

  @moduledoc """
  Routines for persisting evaluations for part attempts.
  """

  @doc """
  Given a list of evaluations that match a list of part_input submissions,
  persist the results of each evaluation to the corresponding part_attempt record
  On success, continue persistence by calling a roll_up function that will may or
  not roll up the results of the these part_attempts to the activity attempt

  The return value here is {:ok, [%{}]}, where the maps in the array are the
  evaluation result that will be sent back to the client.
  """

  def persist_evaluations({:error, error}, _, _, _), do: {:error, error}

  def persist_evaluations({:ok, evaluations}, part_inputs, roll_up_fn, datashop_session_id) do
    evaluated_inputs = Enum.zip(part_inputs, evaluations)

    case Enum.reduce_while(
           evaluated_inputs,
           {:ok, false, []},
           persist_single_evaluation_with_datashop_session_fn(datashop_session_id)
         ) do
      {:ok, _, results} -> roll_up_fn.({:ok, results})
      error -> error
    end
  end

  def persist_evaluations(
        {:ok, evaluations},
        part_inputs,
        roll_up_fn,
        replace,
        datashop_session_id
      ) do
    case replace do
      false ->
        persist_evaluations({:ok, evaluations}, part_inputs, roll_up_fn, datashop_session_id)

      true ->
        evaluated_inputs = Enum.zip(part_inputs, evaluations)

        case Enum.reduce_while(
               evaluated_inputs,
               {:ok, replace, []},
               persist_single_evaluation_with_datashop_session_fn(datashop_session_id)
             ) do
          {:ok, _, results} -> roll_up_fn.({:ok, results})
          error -> error
        end
    end
  end

  defp persist_single_evaluation_with_datashop_session_fn(datashop_session_id) do
    &persist_single_evaluation(&1, &2, datashop_session_id)
  end

  # Persist the result of a single evaluation for a single part_input submission.
  defp persist_single_evaluation({_, {:error, error}}, _, _), do: {:halt, {:error, error}}

  defp persist_single_evaluation(
         {_, {:ok, %NavigationAction{} = action_result}},
         {:ok, replace, results},
         _datashop_session_id
       ) do
    {:cont, {:ok, replace, results ++ [action_result]}}
  end

  defp persist_single_evaluation(
         {_, {:ok, %StateUpdateAction{} = action_result}},
         {:ok, replace, results},
         _datashop_session_id
       ) do
    {:cont, {:ok, replace, results ++ [action_result]}}
  end

  defp persist_single_evaluation(
         {_, {:ok, %ExplanationAction{} = action_result}},
         {:ok, replace, results},
         _datashop_session_id
       ) do
    {:cont, {:ok, replace, results ++ [action_result]}}
  end

  defp persist_single_evaluation(
         {%{attempt_guid: attempt_guid, input: input},
          {:ok,
           %FeedbackAction{
             feedback: feedback,
             score: score,
             out_of: out_of
           } = feedback_action}},
         {:ok, replace, results},
         datashop_session_id
       ) do
    now = DateTime.utc_now()

    query =
      from(p in PartAttempt,
        where: p.attempt_guid == ^attempt_guid
      )

    query =
      if replace === false do
        where(query, [p], is_nil(p.date_evaluated))
      else
        query
      end

    case Repo.update_all(
           query,
           set: [
             response: input,
             lifecycle_state: :evaluated,
             date_evaluated: now,
             date_submitted: now,
             score: score,
             out_of: out_of,
             feedback: feedback,
             datashop_session_id: datashop_session_id
           ]
         ) do
      nil ->
        {:halt, {:error, :error}}

      {1, _} ->
        {:cont, {:ok, replace, results ++ [feedback_action]}}

      _ ->
        {:halt, {:error, :error}}
    end
  end

  defp persist_single_evaluation(
         {%{attempt_guid: attempt_guid, input: input},
          {:ok, %SubmissionAction{} = submission_action}},
         {:ok, replace, results},
         datashop_session_id
       ) do
    now = DateTime.utc_now()

    query =
      from(p in PartAttempt,
        where: p.attempt_guid == ^attempt_guid
      )

    query =
      if replace === false do
        where(query, [p], is_nil(p.date_evaluated))
      else
        query
      end

    case Repo.update_all(
           query,
           set: [
             response: input,
             lifecycle_state: :submitted,
             date_evaluated: nil,
             date_submitted: now,
             datashop_session_id: datashop_session_id
           ]
         ) do
      nil ->
        {:halt, {:error, :error}}

      {1, _} ->
        {:cont, {:ok, replace, results ++ [submission_action]}}

      _ ->
        {:halt, {:error, :error}}
    end
  end
end

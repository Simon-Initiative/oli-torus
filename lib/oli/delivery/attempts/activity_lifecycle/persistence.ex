defmodule Oli.Delivery.Attempts.ActivityLifecycle.Persistence do
  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Delivery.Evaluation.Actions.{
    FeedbackAction,
    SubmissionAction
  }

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

  def persist_evaluations({:ok, []}, _, roll_up_fn, _), do: roll_up_fn.({:ok, []})

  def persist_evaluations({:ok, evaluations}, part_inputs, roll_up_fn, datashop_session_id) do
    right_now = DateTime.utc_now()

    {values, params, _} =
      part_inputs
      |> Enum.zip(evaluations)
      |> Enum.map(fn pair -> attrs_for(pair, datashop_session_id, right_now) end)
      |> Enum.filter(fn attrs -> !is_nil(attrs) end)
      |> Enum.reduce({[], [], 0}, fn pa, {values, params, i} ->
        {
          values ++
            [
              "($#{i + 1}, $#{i + 2}::JSONB, $#{i + 3}, $#{i + 4}::timestamp, $#{i + 5}::timestamp, $#{i + 6}::double precision, $#{i + 7}::double precision, $#{i + 8}::JSONB, $#{i + 9})"
            ],
          params ++
            [
              pa.attempt_guid,
              pa.response,
              Atom.to_string(pa.lifecycle_state),
              pa.date_evaluated,
              pa.date_submitted,
              pa.score,
              pa.out_of,
              pa.feedback,
              pa.datashop_session_id
            ],
          i + 9
        }
      end)

    case values do
      [] ->
        roll_up_fn.({:ok, Enum.map(evaluations, fn {:ok, action} -> action end)})

      _ ->
        values = Enum.join(values, ",")

        sql = """
          UPDATE part_attempts
          SET
            response = batch_values.response,
            lifecycle_state = batch_values.lifecycle_state,
            date_evaluated = batch_values.date_evaluated,
            date_submitted = batch_values.date_submitted,
            score = batch_values.score,
            out_of = batch_values.out_of,
            feedback = batch_values.feedback,
            datashop_session_id = batch_values.datashop_session_id,
            updated_at = NOW()
          FROM (
              VALUES #{values}
          ) AS batch_values (attempt_guid, response, lifecycle_state, date_evaluated, date_submitted, score, out_of, feedback, datashop_session_id)
          WHERE part_attempts.attempt_guid = batch_values.attempt_guid
        """

        case Ecto.Adapters.SQL.query(Repo, sql, params) do
          {:ok, _} -> roll_up_fn.({:ok, Enum.map(evaluations, fn {:ok, action} -> action end)})
          e -> e
        end
    end
  end

  def bulk_update_activity_attempts(_, []), do: {:ok, []}

  def bulk_update_activity_attempts(values, params) do
    sql = """
      UPDATE activity_attempts
      SET
        score = batch_values.score,
        out_of = batch_values.out_of,
        lifecycle_state = batch_values.lifecycle_state,
        date_evaluated = batch_values.date_evaluated,
        date_submitted = batch_values.date_submitted
      FROM (VALUES #{values}) AS batch_values (activity_attempt_guid, score, out_of, lifecycle_state, date_evaluated, date_submitted)
      WHERE activity_attempts.attempt_guid = batch_values.activity_attempt_guid
    """

    Ecto.Adapters.SQL.query(Oli.Repo, sql, params)
  end

  defp attrs_for(
         {%{attempt_guid: attempt_guid, input: input} = part_input,
          {:ok,
           %FeedbackAction{
             feedback: feedback,
             score: score,
             out_of: out_of
           }}},
         datashop_session_id,
         now
       ) do
    # If the timestamp is not provided, use the current time
    date_submitted = part_input[:timestamp] || now

    %{
      attempt_guid: attempt_guid,
      response: input,
      lifecycle_state: :evaluated,
      date_evaluated: now,
      date_submitted: date_submitted,
      score: score,
      out_of: out_of,
      feedback: feedback,
      datashop_session_id: datashop_session_id
    }
  end

  defp attrs_for(
         {%{attempt_guid: attempt_guid, input: input} = part_input, {:ok, %SubmissionAction{}}},
         datashop_session_id,
         now
       ) do
    # If the timestamp is not provided, use the current time
    date_submitted = part_input[:timestamp] || now

    %{
      attempt_guid: attempt_guid,
      response: input,
      lifecycle_state: :submitted,
      date_evaluated: nil,
      date_submitted: date_submitted,
      score: nil,
      out_of: nil,
      feedback: nil,
      datashop_session_id: datashop_session_id
    }
  end

  defp attrs_for(_, _, _), do: nil
end

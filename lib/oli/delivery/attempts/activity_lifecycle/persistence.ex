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

  def persist_evaluations({:ok, evaluations}, part_inputs, roll_up_fn, datashop_session_id) do
    evaluated_inputs = Enum.zip(part_inputs, evaluations)

    update_values = Enum.map(evaluated_inputs, fn pair -> attrs_for(pair, datashop_session_id) end)
    |> Enum.filter(fn attrs -> !is_nil(attrs) end)
    |> Enum.map(fn pa ->
      """
      (
        '#{pa.attempt_guid}',
        #{handle_json(pa.response)},
        '#{Atom.to_string(pa.lifecycle_state)}',
        #{null_or_now(pa.date_evaluated)},
        #{null_or_now(pa.date_submitted)},
        #{handle_num(pa.score)},
        #{handle_num(pa.out_of)},
        #{handle_json(pa.feedback)},
        '#{pa.datashop_session_id}'
      )
      """
    end)
    |> Enum.join(",")

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
          VALUES
          #{update_values}
      ) AS batch_values (attempt_guid, response, lifecycle_state, date_evaluated, date_submitted, score, out_of, feedback, datashop_session_id)
      WHERE part_attempts.attempt_guid = batch_values.attempt_guid
    """

    case Ecto.Adapters.SQL.query(Repo, sql, []) do
      {:ok, _} -> roll_up_fn.({:ok, Enum.map(evaluations, fn {:ok, action} -> action end)})
      e -> e
    end
  end

  defp attrs_for({%{attempt_guid: attempt_guid, input: input}, {:ok, %FeedbackAction{
    feedback: feedback,
    score: score,
    out_of: out_of}}}, datashop_session_id) do
    %{
      attempt_guid: attempt_guid,
      response: input,
      lifecycle_state: :evaluated,
      date_evaluated: true,
      date_submitted: true,
      score: score,
      out_of: out_of,
      feedback: feedback,
      datashop_session_id: datashop_session_id
    }
  end

  defp attrs_for({%{attempt_guid: attempt_guid, input: input}, {:ok, %SubmissionAction{}}}, datashop_session_id) do
    %{
      attempt_guid: attempt_guid,
      response: input,
      lifecycle_state: :submitted,
      date_evaluated: nil,
      date_submitted: true,
      score: nil,
      out_of: nil,
      feedback: nil,
      datashop_session_id: datashop_session_id
    }
  end

  defp attrs_for(_, _), do: nil

  defp handle_num(nil), do: "NULL::double precision"
  defp handle_num(v), do: "#{v}"

  defp handle_json(nil), do: "NULL::JSONB"
  defp handle_json(map), do: "'#{Jason.encode!(map)}'::JSONB"

  defp null_or_now(nil), do: "NULL::timestamp"
  defp null_or_now(_), do: "NOW()"

end

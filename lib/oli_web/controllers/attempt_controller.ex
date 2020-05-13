defmodule OliWeb.AttemptController do
  use OliWeb, :controller

  alias Oli.Delivery.Attempts
  alias Oli.Delivery.Attempts.StudentInput

  def save_part(conn, %{"activity_attempt_guid" => _attempt_guid, "part_attempt_guid" => part_attempt_guid, "response" => response}) do

    case Attempts.save_student_input([%{attempt_guid: part_attempt_guid, response: response}]) do
      {:ok, _} -> json conn, %{ "type" => "success"}
      {:error, _} -> error(conn, 500, "server error")
    end

  end

  def submit_part(conn, %{"activity_attempt_guid" => activity_attempt_guid, "part_attempt_guid" => attempt_guid, "input" => input}) do

    lti_params = Plug.Conn.get_session(conn, :lti_params)
    context_id = lti_params["context_id"]

    case Attempts.submit_part_evaluations(context_id, activity_attempt_guid, [%{attempt_guid: attempt_guid, input: input}]) do
      {:ok, evaluations} -> json conn, %{ "type" => "success", "evaluations" => evaluations}
      {:error, _} -> error(conn, 500, "server error")
    end

  end

  def new_part(conn, %{"activity_attempt_guid" => _, "part_attempt_guid" => _attempt_guid}) do

    json conn, %{ "type" => "success"}
  end

  def get_hint(conn, %{"activity_attempt_guid" => activity_attempt_guid, "part_attempt_guid" => part_attempt_guid}) do

    case Attempts.request_hint(activity_attempt_guid, part_attempt_guid) do
      {:ok, hint, has_more_hints} -> json conn, %{ "type" => "success", "hint" => hint, "hasMoreHints" => has_more_hints}
      {:error, {:not_found}} -> error(conn, 404, "not found")
      {:error, {:no_more_hints}} -> json conn, %{ "type" => "success", "hasMoreHints" => false}
      {:error, _} -> error(conn, 500, "server error")
    end

  end

  def save_activity(conn, %{"activity_attempt_guid" => _attempt_guid, "partInputs" => part_inputs}) do

    parsed = Enum.map(part_inputs, fn %{"attemptGuid" => attempt_guid, "response" => response} ->
      %{attempt_guid: attempt_guid, response: response} end)

    case Attempts.save_student_input(parsed) do
      {:ok, _} -> json conn, %{ "type" => "success"}
      {:error, _} -> error(conn, 500, "server error")
    end

  end

  def submit_activity(conn, %{"activity_attempt_guid" => activity_attempt_guid, "partInputs" => part_inputs}) do

    lti_params = Plug.Conn.get_session(conn, :lti_params)
    context_id = lti_params["context_id"]

    parsed = Enum.map(part_inputs, fn %{"attemptGuid" => attempt_guid, "response" => input} ->
      %{attempt_guid: attempt_guid, input: %StudentInput{input: Map.get(input, "input")}} end)

    case Attempts.submit_part_evaluations(context_id, activity_attempt_guid, parsed) do
      {:ok, evaluations} -> json conn, %{ "type" => "success", "evaluations" => evaluations}
      {:error, _} -> error(conn, 500, "server error")
    end
  end

  def new_activity(conn, %{"activity_attempt_guid" => attempt_guid}) do

    lti_params = Plug.Conn.get_session(conn, :lti_params)
    context_id = lti_params["context_id"]

    case Attempts.reset_activity(context_id, attempt_guid) do
      {:ok, attempt_state, model} -> json conn, %{ "type" => "success", "attemptState" => attempt_state, "model" => model}
      {:error, _} -> error(conn, 500, "server error")
    end

  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end

end

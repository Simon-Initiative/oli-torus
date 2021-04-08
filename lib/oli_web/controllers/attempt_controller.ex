defmodule OliWeb.AttemptController do
  use OliWeb, :controller

  alias Oli.Delivery.Attempts
  alias Oli.Delivery.Attempts.StudentInput
  alias Oli.Delivery.Attempts.ClientEvaluation

  def save_part(conn, %{
        "activity_attempt_guid" => _attempt_guid,
        "part_attempt_guid" => part_attempt_guid,
        "response" => response
      }) do
    case Attempts.save_student_input([%{attempt_guid: part_attempt_guid, response: response}]) do
      {:ok, _} -> json(conn, %{"type" => "success"})
      {:error, _} -> error(conn, 500, "server error")
    end
  end

  def submit_part(conn, %{
        "activity_attempt_guid" => activity_attempt_guid,
        "part_attempt_guid" => attempt_guid,
        "input" => input
      }) do
    section = Attempts.get_section_by_activity_attempt_guid(activity_attempt_guid)

    case Attempts.submit_part_evaluations(section.slug, activity_attempt_guid, [
           %{attempt_guid: attempt_guid, input: input}
         ]) do
      {:ok, evaluations} -> json(conn, %{"type" => "success", "actions" => evaluations})
      {:error, _} -> error(conn, 500, "server error")
    end
  end

  def new_part(conn, %{"activity_attempt_guid" => _, "part_attempt_guid" => _attempt_guid}) do
    json(conn, %{"type" => "success"})
  end

  def get_hint(conn, %{
        "activity_attempt_guid" => activity_attempt_guid,
        "part_attempt_guid" => part_attempt_guid
      }) do
    case Attempts.request_hint(activity_attempt_guid, part_attempt_guid) do
      {:ok, {hint, has_more_hints}} ->
        json(conn, %{"type" => "success", "hint" => hint, "hasMoreHints" => has_more_hints})

      {:error, {:not_found}} ->
        error(conn, 404, "not found")

      {:error, {:no_more_hints}} ->
        json(conn, %{"type" => "success", "hasMoreHints" => false})

      {:error, _} ->
        error(conn, 500, "server error")
    end
  end

  def save_activity(conn, %{"activity_attempt_guid" => _attempt_guid, "partInputs" => part_inputs}) do
    parsed =
      Enum.map(part_inputs, fn %{"attemptGuid" => attempt_guid, "response" => response} ->
        %{attempt_guid: attempt_guid, response: response}
      end)

    case Attempts.save_student_input(parsed) do
      {:ok, _} -> json(conn, %{"type" => "success"})
      {:error, _} -> error(conn, 500, "server error")
    end
  end

  def submit_activity(conn, %{
        "activity_attempt_guid" => activity_attempt_guid,
        "partInputs" => part_inputs
      }) do
    section = Attempts.get_section_by_activity_attempt_guid(activity_attempt_guid)

    parsed =
      Enum.map(part_inputs, fn %{"attemptGuid" => attempt_guid, "response" => input} ->
        %{attempt_guid: attempt_guid, input: %StudentInput{input: Map.get(input, "input")}}
      end)

    case Attempts.submit_part_evaluations(section.slug, activity_attempt_guid, parsed) do
      {:ok, evaluations} ->
        json(conn, %{"type" => "success", "actions" => evaluations})

      {:error, _} ->
        error(conn, 500, "server error")
    end
  end

  def submit_evaluations(conn, %{
        "activity_attempt_guid" => activity_attempt_guid,
        "evaluations" => client_evaluations
      }) do
    section = Attempts.get_section_by_activity_attempt_guid(activity_attempt_guid)

    client_evaluations =
      Enum.map(client_evaluations, fn %{
                                        "attemptGuid" => attempt_guid,
                                        "response" => response,
                                        "score" => score,
                                        "outOf" => out_of,
                                        "feedback" => feedback
                                      } ->
        %{
          attempt_guid: attempt_guid,
          client_evaluation: %ClientEvaluation{
            input: %StudentInput{
              input: Map.get(response, "input")
            },
            score: score,
            out_of: out_of,
            feedback: feedback
          }
        }
      end)

    case Attempts.submit_client_evaluations(
           section.slug,
           activity_attempt_guid,
           client_evaluations
         ) do
      {:ok, evaluations} -> json(conn, %{"type" => "success", "actions" => evaluations})
      {:error, _} -> error(conn, 500, "server error")
    end
  end

  def new_activity(conn, %{"activity_attempt_guid" => activity_attempt_guid}) do
    section = Attempts.get_section_by_activity_attempt_guid(activity_attempt_guid)

    case Attempts.reset_activity(section.slug, activity_attempt_guid) do
      {:ok, {attempt_state, model}} ->
        json(conn, %{"type" => "success", "attemptState" => attempt_state, "model" => model})

      {:error, _} ->
        error(conn, 500, "server error")
    end
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end
end

defmodule OliWeb.AttemptController do
  use OliWeb, :controller

  alias Oli.Delivery.Attempts

  def save_part(conn, %{"attempt_guid" => attempt_guid, "response" => response}) do

    case Attempts.save_student_input([%{attempt_guid: attempt_guid, response: response}]) do
      {:ok, _} -> json conn, %{ "type" => "success"}
      {:error, _} -> json conn, %{ "type" => "failure"}
    end

  end

  def submit_part(conn, %{"attempt_guid" => _attempt_guid, "input" => _input}) do

    json conn, %{ "type" => "success"}
  end

  def new_part(conn, %{"attempt_guid" => _attempt_guid}) do

    json conn, %{ "type" => "success"}
  end

  def get_hint(conn, %{"attempt_guid" => _attempt_guid}) do

    json conn, %{ "type" => "success"}
  end

  def save_activity(conn, %{"attempt_guid" => _attempt_guid, "partInputs" => part_inputs}) do

    parsed = Enum.map(part_inputs, fn %{"attemptGuid" => attempt_guid, "response" => response} ->
      %{attempt_guid: attempt_guid, response: response} end)

    case Attempts.save_student_input(parsed) do
      {:ok, _} -> json conn, %{ "type" => "success"}
      {:error, _} -> json conn, %{ "type" => "failure"}
    end

  end

  def submit_activity(conn, %{"attempt_guid" => _attempt_guid, "partInputs" => _part_inputs}) do

    json conn, %{ "type" => "success"}
  end

  def new_activity(conn, %{"attempt_guid" => _attempt_guid}) do

    json conn, %{ "type" => "success"}
  end


end

defmodule OliWeb.Api.ActivityBankController do
  @moduledoc """
  Endpoints to provide paged access to a course project's banked activities.
  """

  alias Oli.Authoring.Editing.ActivityBank
  alias Oli.Activities.Realizer.Query.Result

  use OliWeb, :controller

  def retrieve(conn, %{"project" => project_slug, "logic" => logic, "paging" => paging}) do
    author = conn.assigns[:current_author]

    with true <- Oli.Accounts.can_access_via_slug?(author, project_slug),
         {:ok, %Result{rows: rows, rowCount: rowCount, totalCount: totalCount}} <-
           ActivityBank.query(project_slug, author, logic, paging) do
      json(conn, %{
        "result" => "success",
        "queryResult" => %{
          rowCount: rowCount,
          totalCount: totalCount,
          rows: Enum.map(rows, &ActivityBank.serialize_revision/1)
        }
      })
    else
      false -> error(conn, 403, "Forbidden")
      _ -> error(conn, 400, "Error in paging/filtering")
    end
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end
end

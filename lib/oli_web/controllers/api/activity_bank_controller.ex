defmodule OliWeb.Api.ActivityBankController do
  @moduledoc """
  Endpoints to provide paged access to a course project's banked activities.
  """

  alias Oli.Activities.Realizer.Logic
  alias Oli.Activities.Realizer.Query.Paging
  alias Oli.Activities.Realizer.Query
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Activities.Realizer.Query.Result
  alias Oli.Publishing.AuthoringResolver

  import Oli.Authoring.Editing.Utils

  use OliWeb, :controller

  def retrieve(conn, %{"project" => project_slug, "logic" => logic, "paging" => paging}) do
    author = conn.assigns[:current_author]

    if Oli.Accounts.can_access_via_slug?(author, project_slug) do
      with {:ok, %Logic{} = logic} <- Logic.parse(logic),
           {:ok, %Paging{} = paging} <- Paging.parse(paging),
           {:ok, publication} <- AuthoringResolver.publication(project_slug) |> trap_nil(),
           {:ok, %Result{} = result} <-
             Query.execute(
               logic,
               %Source{publication_id: publication.id, blacklisted_activity_ids: []},
               paging
             ) do
        json(conn, %{"result" => "success", "queryResult" => result})
      else
        _ -> error(conn, 400, "Error in paging/filtering")
      end
    else
      error(conn, 403, "Forbidden")
    end
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end
end

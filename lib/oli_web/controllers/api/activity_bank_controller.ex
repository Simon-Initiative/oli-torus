defmodule OliWeb.Api.ActivityBankController do
  @moduledoc """
  Endpoints to provide paged access to a course project's banked activities.
  """

  alias Oli.Activities.Realizer.Logic
  alias Oli.Activities.Realizer.Query.Paging
  alias Oli.Activities.Realizer.Query
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Activities.Realizer.Query.Result
  alias Oli.Publishing

  import Oli.Authoring.Editing.Utils

  use OliWeb, :controller

  def retrieve(conn, %{"project" => project_slug, "logic" => logic, "paging" => paging}) do
    author = conn.assigns[:current_author]

    if Oli.Accounts.can_access_via_slug?(author, project_slug) do
      with {:ok, %Logic{} = logic} <- Logic.parse(logic),
           {:ok, %Paging{} = paging} <- Paging.parse(paging),
           {:ok, publication} <-
             Publishing.project_working_publication(project_slug) |> trap_nil(),
           {:ok, %Result{rows: rows, rowCount: rowCount, totalCount: totalCount}} <-
             Query.execute(
               logic,
               %Source{
                 publication_id: publication.id,
                 blacklisted_activity_ids: [],
                 section_slug: ""
               },
               paging
             ) do
        json(conn, %{
          "result" => "success",
          "queryResult" => %{
            rowCount: rowCount,
            totalCount: totalCount,
            rows: Enum.map(rows, fn r -> serialize_revision(r) end)
          }
        })
      else
        _ -> error(conn, 400, "Error in paging/filtering")
      end
    else
      error(conn, 403, "Forbidden")
    end
  end

  defp serialize_revision(%Oli.Resources.Revision{} = revision) do
    %{
      content: revision.content,
      title: revision.title,
      objectives: revision.objectives,
      resource_id: revision.resource_id,
      activity_type_id: revision.activity_type_id,
      slug: revision.slug
    }
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end
end

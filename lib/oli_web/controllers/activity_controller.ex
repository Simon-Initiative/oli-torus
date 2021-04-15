defmodule OliWeb.ActivityController do
  use OliWeb, :controller

  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Accounts
  alias OliWeb.Common.Breadcrumb

  import OliWeb.ProjectPlugs

  plug :fetch_project when action in [:edit]
  plug :authorize_project when action in [:edit]

  @moduledoc """
  The storage service allows activity implementations to read, write, update
  and delete documents associated with an activity instance.
  """

  alias OpenApiSpex.Schema

  @doc false
  def edit(conn, %{
        "project_id" => project_slug,
        "revision_slug" => revision_slug,
        "activity_slug" => activity_slug
      }) do
    author = conn.assigns[:current_author]
    is_admin? = Accounts.is_admin?(author)

    # full title, short title, link, action descriptions

    case ActivityEditor.create_context(project_slug, revision_slug, activity_slug, author) do
      {:ok, context} ->
        render(conn, "edit.html",
          active: :curriculum,
          breadcrumbs:
            Breadcrumb.trail_to(project_slug, revision_slug) ++
              [Breadcrumb.new(%{full_title: context.title})],
          project_slug: project_slug,
          is_admin?: is_admin?,
          activity_slug: activity_slug,
          script: context.authoringScript,
          context: Jason.encode!(context)
        )

      {:error, :not_found} ->
        render(conn, OliWeb.SharedView, "_not_found.html",
          breadcrumbs: [
            Breadcrumb.curriculum(project_slug),
            Breadcrumb.new(%{full_title: "Not Found"})
          ]
        )
    end
  end
end

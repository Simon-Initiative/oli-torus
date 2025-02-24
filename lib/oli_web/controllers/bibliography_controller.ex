defmodule OliWeb.BibliographyController do
  use OliWeb, :controller

  alias Oli.Accounts
  alias OliWeb.Common.Breadcrumb

  @doc false
  def index(conn, %{
        "project_id" => project_slug
      }) do
    author = conn.assigns[:current_author]
    is_admin? = Accounts.has_admin_role?(author, :content_admin)

    case Oli.Authoring.Editing.BibliographyEditor.create_context(project_slug, author) do
      {:ok, context} ->
        render(conn, "index.html",
          active: :bibliography,
          context: context,
          breadcrumbs: [Breadcrumb.new(%{full_title: "Bibliography"})],
          project_slug: project_slug,
          is_admin?: is_admin?,
          scripts: Oli.Activities.get_activity_scripts()
        )

      _ ->
        OliWeb.ResourceController.render_not_found(conn, project_slug)
    end
  end
end

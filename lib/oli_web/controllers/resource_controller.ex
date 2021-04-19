defmodule OliWeb.ResourceController do
  use OliWeb, :controller

  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Accounts
  alias Oli.Activities
  alias Oli.Publishing.AuthoringResolver
  alias OliWeb.Common.Breadcrumb

  import OliWeb.ProjectPlugs

  plug :fetch_project
  plug :authorize_project
  plug :put_root_layout, {OliWeb.LayoutView, "preview.html"} when action in [:preview]

  def edit(conn, %{"project_id" => project_slug, "revision_slug" => revision_slug}) do
    author = conn.assigns[:current_author]
    is_admin? = Accounts.is_admin?(author)

    case PageEditor.create_context(project_slug, revision_slug, conn.assigns[:current_author]) do
      {:ok, context} ->
        render(conn, determine_editor(context),
          active: :curriculum,
          breadcrumbs: Breadcrumb.trail_to(project_slug, revision_slug),
          is_admin?: is_admin?,
          context: Jason.encode!(context),
          raw_context: context,
          scripts: Activities.get_activity_scripts(),
          project_slug: project_slug,
          revision_slug: revision_slug
        )

      {:error, :not_found} ->
        conn
        |> put_view(OliWeb.SharedView)
        |> render("_not_found.html",
          title: "Not Found",
          breadcrumbs: [
            Breadcrumb.curriculum(project_slug),
            Breadcrumb.new(%{full_title: "Not Found"})
          ]
        )
    end
  end

  # Look at the revision content to determine which editor to display
  defp determine_editor(context) do
    case context.content do
      %{"advancedAuthoring" => true} -> "advanced.html"
      _ -> "edit.html"
    end
  end

  def preview(conn, %{"project_id" => project_slug, "revision_slug" => revision_slug}) do
    author = conn.assigns[:current_author]

    %{content: %{"model" => model}} =
      AuthoringResolver.from_revision_slug(project_slug, revision_slug)

    activity_ids = Oli.Authoring.Editing.Utils.activity_references(model) |> MapSet.to_list()
    activity_revisions = AuthoringResolver.from_resource_id(project_slug, activity_ids)

    case PageEditor.create_context(project_slug, revision_slug, author) do
      {:ok, context} ->
        render(conn, "page_preview.html",
          breadcrumbs: Breadcrumb.trail_to(project_slug, revision_slug),
          objectives:
            Oli.Delivery.Page.ObjectivesRollup.rollup_objectives(
              activity_revisions,
              AuthoringResolver,
              project_slug
            ),
          content_html:
            PageEditor.render_page_html(project_slug, revision_slug, author, preview: true),
          context: context,
          scripts: Activities.get_activity_scripts(),
          preview_mode: true
        )

      {:error, :not_found} ->
        conn
        |> put_view(OliWeb.SharedView)
        |> render("_not_found.html",
          title: "Not Found",
          breadcrumbs: [
            Breadcrumb.curriculum(project_slug),
            Breadcrumb.new(%{full_title: "Not Found"})
          ]
        )
    end
  end
end

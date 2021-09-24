defmodule OliWeb.ResourceController do
  use OliWeb, :controller

  import OliWeb.ProjectPlugs
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Accounts
  alias Oli.Activities
  alias Oli.Publishing.AuthoringResolver
  alias OliWeb.Common.Breadcrumb
  alias Oli.PartComponents
  alias Oli.Delivery.Hierarchy

  plug :fetch_project
  plug :authorize_project
  plug :put_root_layout, {OliWeb.LayoutView, "preview.html"} when action in [:preview]

  def edit(conn, %{"project_id" => project_slug, "revision_slug" => revision_slug}) do
    author = conn.assigns[:current_author]
    is_admin? = Accounts.is_admin?(author)
    project = conn.assigns.project

    case PageEditor.create_context(project_slug, revision_slug, conn.assigns[:current_author]) do
      {:ok, context} ->
        render(conn, determine_editor(context),
          active: :curriculum,
          breadcrumbs:
            Breadcrumb.trail_to(project_slug, revision_slug, Oli.Publishing.AuthoringResolver),
          is_admin?: is_admin?,
          context: Jason.encode!(context),
          raw_context: context,
          scripts: Activities.get_activity_scripts(:authoring_script),
          part_scripts: PartComponents.get_part_component_scripts(:authoring_script),
          project_slug: project_slug,
          revision_slug: revision_slug,
          activity_types: Activities.activities_for_project(project),
          part_component_types: PartComponents.part_components_for_project(project),
          graded: context.graded
        )

      {:error, :not_found} ->
        render_not_found(conn, project_slug)
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
    project = conn.assigns.project

    case AuthoringResolver.from_revision_slug(project_slug, revision_slug) do
      nil ->
        render_not_found(conn, project_slug)

      %{content: %{"advancedDelivery" => true}} = revision ->
        put_root_layout(conn, {OliWeb.LayoutView, "chromeless.html"})
        |> render("advanced_page_preview.html",
          revision: revision,
          additional_stylesheets: Map.get(revision.content, "additionalStylesheets", []),
          activity_types: Activities.activities_for_project(project),
          scripts: Activities.get_activity_scripts(:delivery_script),
          part_scripts: PartComponents.get_part_component_scripts(:delivery_script),
          user: author,
          project_slug: project_slug,
          title: revision.title,
          preview_mode: true
        )

      revision ->
        {_, activity_revisions, transformed_content} =
          Oli.Delivery.ActivityProvider.provide(
            revision,
            %Source{
              blacklisted_activity_ids: [],
              section_slug: project_slug,
              publication_id: Oli.Publishing.project_working_publication(project_slug).id
            },
            Oli.Publishing.AuthoringResolver
          )

        case PageEditor.create_context(project_slug, revision_slug, author) do
          {:ok, context} ->
            render(conn, "page_preview.html",
              breadcrumbs:
                Breadcrumb.trail_to(project_slug, revision_slug, Oli.Publishing.AuthoringResolver),
              objectives:
                Oli.Delivery.Page.ObjectivesRollup.rollup_objectives(
                  activity_revisions,
                  AuthoringResolver,
                  project_slug
                ),
              content_html:
                PageEditor.render_page_html(project_slug, transformed_content, author,
                  preview: true
                ),
              context: context,
              scripts: Activities.get_activity_scripts(),
              preview_mode: true
            )

          {:error, :not_found} ->
            render_not_found(conn, project_slug)
        end
    end
  end

  def preview(conn, %{"project_id" => project_slug}) do
    # find the first page of the course and redirect to there. NOTE: this is not the most efficient method,
    # but it should suffice for now until an improved preview landing page is added
    [first | _] =
      AuthoringResolver.full_hierarchy(project_slug)
      |> Hierarchy.flatten_pages()

    conn
    |> redirect(to: Routes.resource_path(conn, :preview, project_slug, first.revision.slug))
  end

  def render_not_found(conn, project_slug) do
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

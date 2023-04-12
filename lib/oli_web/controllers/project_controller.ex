defmodule OliWeb.ProjectController do
  use OliWeb, :controller

  alias Oli.Authoring.Course
  alias Oli.Qa
  alias Oli.Analytics.Datashop
  alias OliWeb.Common.Breadcrumb
  alias Oli.Authoring.Clone
  alias OliWeb.Insights

  def unpublished(pub), do: pub.published == nil

  def resource_editor(conn, _project_params) do
    render(conn, "resource_editor.html", title: "Resource Editor", active: :resource_editor)
  end

  def download_analytics(conn, _project_params) do
    project = conn.assigns.project

    conn
    |> send_download({:binary, Insights.export(project)},
      filename: "analytics_#{project.slug}.zip"
    )
  end

  def review_project(conn, _params) do
    project = conn.assigns.project
    Qa.review_project(project.slug)

    conn
    |> redirect(to: Routes.project_path(conn, :publish, project))
  end

  def insights(conn, _project_params) do
    render(conn, "insights.html",
      breadcrumbs: [Breadcrumb.new(%{full_title: "Insights"})],
      active: :insights
    )
  end

  def create(conn, %{"project" => %{"title" => title} = _project_params}) do
    case Course.create_project(title, conn.assigns.current_author) do
      {:ok, %{project: project}} ->
        redirect(conn,
          to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.OverviewLive, project.slug)
        )

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Could not create project. Please try again")
        |> redirect(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive))
    end
  end

  def download_datashop(conn, _project_params) do
    project = conn.assigns.project

    conn
    |> send_download({:binary, Datashop.export(project.id)},
      filename: "Datashop_#{project.slug}.xml"
    )
  end

  def download_export(conn, _project_params) do
    project = conn.assigns.project

    conn
    |> send_download({:binary, Oli.Interop.Export.export(project)},
      filename: "export_#{project.slug}.zip"
    )
  end

  def clone_project(conn, _project_params) do
    case Clone.clone_project(conn.assigns.project.slug, conn.assigns.current_author) do
      {:ok, project} ->
        conn
        |> put_flash(:info, "Project duplicated. You've been redirected to your new project.")
        |> redirect(
          to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.OverviewLive, project.slug)
        )

      {:error, message} ->
        project = conn.assigns.project

        conn
        |> put_flash(:error, "Project could not be copied: " <> message)
        |> redirect(
          to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.OverviewLive, project.slug)
        )
    end
  end
end

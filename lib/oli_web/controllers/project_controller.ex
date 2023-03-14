defmodule OliWeb.ProjectController do
  use OliWeb, :controller

  alias Oli.Accounts
  alias Oli.Utils
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Inventories
  alias Oli.Publishing
  alias Oli.Qa
  alias Oli.Analytics.Datashop
  alias OliWeb.Common.Breadcrumb
  alias Oli.Authoring.Clone
  alias Oli.Activities
  alias OliWeb.Insights

  def overview(conn, project_params) do
    project = conn.assigns.project

    author = conn.assigns[:current_author]
    is_admin? = Accounts.is_admin?(author)

    latest_published_publication =
      Publishing.get_latest_published_publication_by_slug(project.slug)

    params = %{
      breadcrumbs: [Breadcrumb.new(%{full_title: "Project Overview"})],
      active: :overview,
      collaborators: Accounts.project_authors(project),
      activities_enabled: Activities.advanced_activities(project, is_admin?),
      can_enable_experiments: is_admin? and Oli.Delivery.Experiments.experiments_enabled?(),
      changeset:
        Utils.value_or(
          Map.get(project_params, :changeset),
          Project.changeset(project)
        ),
      latest_published_publication: latest_published_publication,
      publishers: Inventories.list_publishers(),
      title: "Overview | " <> project.title,
      attributes: project.attributes,
      language_codes: Oli.LanguageCodesIso639.codes()
    }

    render(%{conn | assigns: Map.merge(conn.assigns, params)}, "overview.html")
  end

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
        redirect(conn, to: Routes.project_path(conn, :overview, project))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Could not create project. Please try again")
        |> redirect(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive))
    end
  end

  def update(conn, %{"project" => project_params}) do
    project = conn.assigns.project

    author = conn.assigns[:current_author]
    is_admin? = Accounts.is_admin?(author)

    case Course.update_project(project, project_params) do
      {:ok, project} ->
        conn
        |> put_flash(:info, "Project updated successfully.")
        |> redirect(to: Routes.project_path(conn, :overview, project))

      {:error, %Ecto.Changeset{} = changeset} ->
        overview_params = %{
          breadcrumbs: [Breadcrumb.new(%{full_title: "Project Overview"})],
          active: :overview,
          collaborators: Accounts.project_authors(project),
          activities_enabled: Activities.advanced_activities(project, is_admin?),
          changeset: changeset,
          latest_published_publication:
            Publishing.get_latest_published_publication_by_slug(project.slug),
          publishers: Inventories.list_publishers(),
          title: "Overview | " <> project.title,
          language_codes: Oli.LanguageCodesIso639.codes(),
          can_enable_experiments: is_admin? and Oli.Delivery.Experiments.experiments_enabled?()
        }

        conn
        |> Map.put(:assigns, Map.merge(conn.assigns, overview_params))
        |> put_flash(:error, "Project could not be updated.")
        |> render("overview.html")
    end
  end

  def delete(conn, %{"project_id" => project_slug, "title" => title}) do
    case Course.get_project_by_slug(project_slug) do
      nil ->
        error(conn, 404, "not found")

      project ->
        if project.title === title do
          delete_project(conn, project)
        else
          error(conn, 404, "not found")
        end
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
        |> redirect(to: Routes.project_path(conn, :overview, project))

      {:error, message} ->
        project = conn.assigns.project

        conn
        |> put_flash(:error, "Project could not be copied: " <> message)
        |> redirect(to: Routes.project_path(conn, :overview, project))
    end
  end

  defp delete_project(conn, project) do
    author = conn.assigns[:current_author]
    is_admin? = Accounts.is_admin?(author)

    case Course.update_project(project, %{status: :deleted}) do
      {:ok, _project} ->
        conn
        |> redirect(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive))

      {:error, %Ecto.Changeset{} = changeset} ->
        overview_params = %{
          breadcrumbs: [Breadcrumb.new(%{full_title: "Project Overview"})],
          active: :overview,
          collaborators: Accounts.project_authors(project),
          activities_enabled: Activities.advanced_activities(project, is_admin?),
          changeset: changeset,
          latest_published_publication:
            Publishing.get_latest_published_publication_by_slug(project.slug),
          publishers: Inventories.list_publishers(),
          title: "Overview | " <> project.title,
          language_codes: Oli.LanguageCodesIso639.codes(),
          can_enable_experiments: is_admin? and Oli.Delivery.Experiments.experiments_enabled?()
        }

        conn
        |> Map.put(:assigns, Map.merge(conn.assigns, overview_params))
        |> put_flash(:error, "Project could not be deleted.")
        |> render("overview.html")
    end
  end

  defp error(conn, code, reason) do
    conn
    |> Plug.Conn.send_resp(code, reason)
    |> Plug.Conn.halt()
  end
end

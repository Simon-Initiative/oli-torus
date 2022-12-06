defmodule OliWeb.ProjectController do
  use OliWeb, :controller

  import Oli.Utils, only: [trap_nil: 1, log_error: 2]

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

  def publish(conn, _) do
    project = conn.assigns.project

    latest_published_publication =
      Publishing.get_latest_published_publication_by_slug(project.slug)

    active_publication = Publishing.project_working_publication(project.slug)

    # publish
    {version_change, active_publication_changes, parent_pages} =
      case latest_published_publication do
        nil ->
          {true, nil, %{}}

        _ ->
          {version_change, changes} =
            Publishing.diff_publications(latest_published_publication, active_publication)

          parent_pages =
            case version_change do
              {:no_changes, _} ->
                %{}

              _ ->
                Map.values(changes)
                |> Enum.map(fn {_, %{revision: revision}} -> revision end)
                |> Enum.filter(fn r ->
                  r.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("activity")
                end)
                |> Enum.map(fn r -> r.resource_id end)
                |> Oli.Publishing.determine_parent_pages(
                  Oli.Publishing.project_working_publication(project.slug).id
                )
            end

          {version_change, changes, parent_pages}
      end

    base_url = Oli.Utils.get_base_url()
    canvas_developer_key_url = "#{base_url}/lti/developer_key.json"

    blackboard_application_client_id =
      Application.get_env(:oli, :blackboard_application_client_id)

    tool_url = "#{base_url}/lti/launch"
    initiate_login_url = "#{base_url}/lti/login"
    public_keyset_url = "#{base_url}/.well-known/jwks.json"
    redirect_uris = "#{base_url}/lti/launch"

    has_changes =
      case version_change do
        {:no_changes, _} -> false
        _ -> true
      end

    render(conn, "publish.html",
      # page
      breadcrumbs: [Breadcrumb.new(%{full_title: "Publish"})],
      active: :publish,

      # publish
      unpublished: active_publication_changes == nil,
      latest_published_publication: latest_published_publication,
      active_publication_id: active_publication.id,
      active_publication_changes: active_publication_changes,
      version_change: version_change,
      has_changes: has_changes,
      parent_pages: parent_pages,
      canvas_developer_key_url: canvas_developer_key_url,
      blackboard_application_client_id: blackboard_application_client_id,
      tool_url: tool_url,
      initiate_login_url: initiate_login_url,
      public_keyset_url: public_keyset_url,
      redirect_uris: redirect_uris,
      title: "Publish | " <> project.title
    )
  end

  def review_project(conn, _params) do
    project = conn.assigns.project
    Qa.review_project(project.slug)

    conn
    |> redirect(to: Routes.project_path(conn, :publish, project))
  end

  def publish_active(conn, params) do
    project = conn.assigns.project

    with {:ok, description} <- params["description"] |> trap_nil(),
         {active_publication_id, ""} <- params["active_publication_id"] |> Integer.parse(),
         {:ok} <- check_active_publication_id(project.slug, active_publication_id),
         {:ok, _pub} <- Publishing.publish_project(project, description) do
      conn
      |> put_flash(:info, "Publish Successful!")
      |> redirect(to: Routes.project_path(conn, :publish, project))
    else
      e ->
        {_id, msg} = log_error("Publish failed", e)

        conn
        |> put_flash(:error, msg)
        |> redirect(to: Routes.project_path(conn, :publish, project))
    end
  end

  defp check_active_publication_id(project_slug, active_publication_id) do
    active_publication = Publishing.project_working_publication(project_slug)

    if active_publication.id == active_publication_id do
      {:ok}
    else
      {:error, "publication id does not match the active publication"}
    end
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
          language_codes: Oli.LanguageCodesIso639.codes()
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
          language_codes: Oli.LanguageCodesIso639.codes()
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

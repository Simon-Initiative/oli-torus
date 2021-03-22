defmodule OliWeb.ProjectController do
  use OliWeb, :controller

  alias Oli.Accounts
  alias Oli.Utils
  alias Oli.Authoring.{Course}
  alias Oli.Authoring.Course.Project
  alias Oli.Publishing
  alias Oli.Qa
  alias Oli.Analytics.Datashop
  alias OliWeb.Common.Breadcrumb
  alias Oli.Authoring.Clone

  def overview(conn, project_params) do
    project = conn.assigns.project
    params = %{
      breadcrumbs: [Breadcrumb.new(%{full_title: "Overview"})],
      active: :overview,
      collaborators: Accounts.project_authors(project),
      changeset: Utils.value_or(
        Map.get(project_params, :changeset),
        Project.changeset(project)),
    }
    render %{conn | assigns: Map.merge(conn.assigns, params)}, "overview.html"
  end

  def unpublished(pub), do: pub.published == false

  def resource_editor(conn, _project_params) do
    render conn, "resource_editor.html", title: "Resource Editor", active: :resource_editor
  end

  def publish(conn, _) do
    project = conn.assigns.project
    latest_published_publication = Publishing.get_latest_published_publication_by_slug!(project.slug)
    active_publication = Publishing.get_unpublished_publication_by_slug!(project.slug)

    # publish
    {has_changes, active_publication_changes, parent_pages} = case latest_published_publication do
      nil -> {true, nil, %{}}
      _ ->
        changes = Publishing.diff_publications(latest_published_publication, active_publication)
          |> (&(:maps.filter fn _, v -> v != :identical end, &1)).()
        has_changes = Map.values(changes)
          |> Enum.any?(fn {status, _} -> status != :identical end)

        parent_pages = if has_changes do
          Map.values(changes)
          |> Enum.filter(fn {status, _} -> status != :identical end)
          |> Enum.map(fn {_, %{revision: revision}} -> revision end)
          |> Enum.filter(fn r -> r.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("activity") end)
          |> Enum.map(fn r -> r.resource_id end)
          |> Oli.Publishing.determine_parent_pages(Oli.Publishing.AuthoringResolver.publication(project.slug).id)
        else
          %{}
        end

        {has_changes, changes, parent_pages}
      end

    base_url = Oli.Utils.get_base_url()
    developer_key_url = "#{base_url}/lti/developer_key.json"

    tool_url = "#{base_url}/lti/launch"
    initiate_login_url = "#{base_url}/lti/login"
    public_keyset_url = "#{base_url}/.well-known/jwks.json"
    redirect_uris = "#{base_url}/lti/launch"

    render conn, "publish.html",
      # page
      breadcrumbs: [Breadcrumb.new(%{full_title: "Publish"})],
      active: :publish,

      # publish
      latest_published_publication: latest_published_publication,
      active_publication_changes: active_publication_changes,
      has_changes: has_changes,
      parent_pages: parent_pages,
      developer_key_url: developer_key_url,
      tool_url: tool_url,
      initiate_login_url: initiate_login_url,
      public_keyset_url: public_keyset_url,
      redirect_uris: redirect_uris

  end

  def review_project(conn, _params) do
    project = conn.assigns.project
    Qa.review_project(project.slug)

    conn
    |> redirect(to: Routes.project_path(conn, :publish, project))
  end


  def publish_active(conn, _params) do
    project = conn.assigns.project
    Publishing.publish_project(project)

    conn
    |> put_flash(:info, "Publish Successful!")
    |> redirect(to: Routes.project_path(conn, :publish, project))
  end

  def insights(conn, _project_params) do
    render conn, "insights.html", breadcrumbs: [Breadcrumb.new(%{full_title: "Insights"})], active: :insights
  end

  def create(conn, %{"project" => %{"title" => title} = _project_params}) do
    case Course.create_project(title, conn.assigns.current_author) do
      {:ok, %{project: project}} ->
        redirect conn, to: Routes.project_path(conn, :overview, project)
      {:error, _changeset} ->
        conn
          |> put_flash(:error, "Could not create project. Please try again")
          |> redirect(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive))
    end
  end

  def update(conn, %{"project" => project_params}) do
    project = conn.assigns.project
    case Course.update_project(project, project_params) do
      {:ok, project} ->
        conn
        |> put_flash(:info, "Project updated successfully.")
        |> redirect(to: Routes.project_path(conn, :overview, project))

      {:error, %Ecto.Changeset{} = changeset} ->
        overview_params = %{
          breadcrumbs: [Breadcrumb.new(%{full_title: "Overview"})],
          active: :overview,
          collaborators: Accounts.project_authors(project),
          changeset: changeset
        }
        conn
        |> Map.put(:assigns, Map.merge(conn.assigns, overview_params))
        |> put_flash(:error, "Project could not be updated.")
        |> render("overview.html")
    end
  end

  def download_datashop(conn, _project_params) do
    project = conn.assigns.project
    conn
    |> send_download({:binary, Datashop.export(project.id)}, filename: "Datashop_#{project.slug}.xml")
  end

  def clone_project(conn, _project_params) do
    case Clone.clone_project(conn.assigns.project.slug, conn.assigns.current_author) do
      {:ok, project} ->
        IO.inspect(project)
        conn
        |> put_flash(:info, "Project copied. You've been redirected to your new project.")
        |> redirect(to: Routes.project_path(conn, :overview, project))

      {:error, message} ->
        conn
        |> put_flash(:error, "Project could not be copied: " <> message)
        |> render("overview.html")
    end
  end
end

defmodule OliWeb.ResourceController do
  use OliWeb, :controller

  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Authoring.Course
  alias Oli.Accounts
  alias Oli.Activities
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Authoring.Editing.ObjectiveEditor
  alias Oli.Publishing

  import OliWeb.ProjectPlugs

  plug :fetch_project when action not in [:view, :update, :index]
  plug :authorize_project when action not in [:view, :update, :index]
  plug :put_root_layout, {OliWeb.LayoutView, "preview.html"} when action in [:preview]

  def index(conn, %{"project" => project_slug }) do

    case Course.get_project_by_slug(project_slug) do

      nil -> error(conn, 404, "not found")

      project ->

        # we allow a client to supply a current link slug that we will attempt to
        # match up to the project's current list of page slugs.
        {linked_resource_id, slug} = case Map.get(conn.query_params, "current", nil) do
          nil -> {nil, nil}
          slug -> {AuthoringResolver.from_revision_slug(project_slug, slug), slug}
        end

        pages = ContainerEditor.list_all_pages(project)
        |> Enum.map(fn r -> %{
          id: if r.resource_id == linked_resource_id do slug else r.slug end,
          title: r.title
        } end)

        json conn, %{ "type" => "success", "pages" => pages }
    end

  end

  def edit(conn, %{"project_id" => project_slug, "revision_slug" => revision_slug}) do
    author = conn.assigns[:current_author]
    is_admin? = Accounts.is_admin?(author)
    revision = AuthoringResolver.from_revision_slug(project_slug, revision_slug)
    publication = Publishing.get_unpublished_publication_by_slug!(project_slug)
    [lock_info | _tail] = Publishing.retrieve_lock_info([revision.resource_id], publication.id)

    lock_author = case lock_info.author do
      nil -> nil
      _ ->
        # Return nil if author is the same as edit requester
        if lock_info.author.email == author.email do
          nil
        else
          lock_info.author
        end
    end

    case PageEditor.create_context(project_slug, revision_slug, conn.assigns[:current_author]) do
      {:ok, context} -> render(conn, "edit.html", active: :curriculum, title: "Page Editor", author: lock_author, is_admin?: is_admin?, context: Jason.encode!(context), scripts: Activities.get_activity_scripts(), project_slug: project_slug, revision_slug: revision_slug)

      {:error, :not_found} ->
        conn
        |> put_view(OliWeb.SharedView)
        |> render("_not_found.html", title: "Not Found")
    end

  end

  def preview(conn, %{"project_id" => project_slug, "revision_slug" => revision_slug}) do
    author = conn.assigns[:current_author]

    case PageEditor.create_context(project_slug, revision_slug, author) do
      {:ok, context} ->
        render(conn, "page_preview.html",
          title: "Preview - #{context.title}",
          # content_html: PageEditor.render_page_html(project_slug, revision_slug, author, PageEditor.create_activities_map(publication_id, map)),
          content_html: PageEditor.render_page_html(project_slug, revision_slug, author),
          context: context,
          scripts: Activities.get_activity_scripts(),
          preview_mode: true
        )
      {:error, :not_found} ->
        conn
        |> put_view(OliWeb.SharedView)
        |> render("_not_found.html", title: "Not Found")
    end
  end

  def update(conn, %{"project" => project_slug, "resource" => resource_slug, "update" => update }) do

    author = conn.assigns[:current_author]

    case PageEditor.edit(project_slug, resource_slug, author.email, update) do

      {:ok, revision} -> json conn, %{ "type" => "success", "revision_slug" => revision.slug}
      {:error, {:lock_not_acquired}} -> error(conn, 423, "locked")
      {:error, {:not_found}} -> error(conn, 404, "not found")
      {:error, {:not_authorized}} -> error(conn, 403, "unauthorized")
      _ -> error(conn, 500, "server error")
    end

  end

  def delete(_conn, %{"project_id" => _project_slug, "revision_slug" => _resource_slug }) do

  end

  def create_objective(conn, %{"project_id" => project_slug, "title" => title }) do
    project = Course.get_project_by_slug(project_slug)
    author = conn.assigns[:current_author]

    case ObjectiveEditor.add_new(%{title: title}, author, project, nil) do
      {:ok, %{revision: revision}} ->
        conn
        |> json(%{ "type" => "success", "revisionSlug" => revision.slug})
      {:error, %Ecto.Changeset{} = _changeset} ->
        conn
        |> send_resp(500, "Objective could not be created")
    end
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end

end

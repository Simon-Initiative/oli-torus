defmodule OliWeb.WorkspaceController do
  use OliWeb, :controller
  alias Oli.Authoring
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Course
  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.{SystemRole}

  def projects(%{:assigns => %{:current_author => current_author}} = conn, params) do

    projects = Course.get_projects_for_author(current_author)
    author_counts = Accounts.project_author_count(Enum.map(projects, fn %{id: id} -> id end))
    |> Enum.reduce(%{}, fn [id, count], m -> Map.put(m, id, count) end)

    params = %{
      title: "Projects",
      active: :projects,
      changeset: Project.changeset(%Project{
        title: params["project_title"] || ""
      }),
      author: current_author,
      projects: projects,
      author_counts: author_counts,
      is_admin: SystemRole.role_id().admin == current_author.system_role_id
    }
    render %{conn | assigns: (Map.merge(conn.assigns, params) |> Map.put(:title, "Projects"))}, "projects.html"
  end

  def account(conn, _params) do
    author = conn.assigns.current_author
    institutions = Accounts.list_institutions() |> Enum.filter(fn i -> i.author_id == conn.assigns.current_author.id end)
    themes = Authoring.list_themes()
    active_theme = case author.preferences do
      nil ->
        Authoring.get_default_theme!()
      %{theme: url} ->
        Authoring.get_theme_by_url!(url)
    end
    render conn, "account.html", title: "Account", active: :account, institutions: institutions, themes: themes, active_theme: active_theme, title: "Account"
  end

  def update_theme(conn, %{"id" => theme_id} = _params) do
    author = conn.assigns.current_author
    theme = Authoring.get_theme!(String.to_integer(theme_id))

    updated_preferences = (author.preferences || %Accounts.AuthorPreferences{})
      |> Map.put(:theme, theme.url)
      |> Map.from_struct

    case Accounts.update_author(author, %{preferences: updated_preferences}) do
      {:ok, _author} ->
        conn
        |> redirect(to: Routes.workspace_path(conn, :account))

      {:error, _} ->
        conn
        |> put_flash(:error, "Failed to change theme")
        |> redirect(to: Routes.workspace_path(conn, :account))

    end

  end
end

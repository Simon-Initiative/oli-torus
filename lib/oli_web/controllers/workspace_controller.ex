defmodule OliWeb.WorkspaceController do
  use OliWeb, :controller
  alias Oli.Authoring
  alias Oli.Authoring.Course.Project
  alias Oli.Repo
  alias Oli.Accounts

  def projects(%{:assigns => %{:current_author => current_author}} = conn, params) do
    current_author = Repo.preload(current_author, [:projects])
    projects = current_author.projects
      |> Enum.map(fn project ->
        Map.put(project, :author_count, Accounts.project_author_count(project)) end)
    params = %{
      title: "Projects",
      active: :projects,
      changeset: Project.changeset(%Project{
        title: params["project_title"] || ""
      }),
      author: current_author,
      projects: projects
    }
    render %{conn | assigns: (Map.merge(conn.assigns, params) |> Map.put(:page_title, "Projects - "))}, "projects.html"
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
    render conn, "account.html", title: "Account", active: :account, institutions: institutions, themes: themes, active_theme: active_theme, page_title: "Account - "
  end

  def update_theme(conn, %{"id" => theme_id} = params) do
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

defmodule OliWeb.WorkspaceController do
  use OliWeb, :controller
  alias Oli.Course.Project
  alias Oli.Repo

  def projects(%{:assigns => %{:current_author => current_author}} = conn, params) do
    current_author = Repo.preload(current_author, [:projects])
    params = %{
      title: "Projects",
      project_changeset: Project.changeset(%Project{
        title: params["project_title"] || ""
      }),
      active: :nil,
      author: current_author,
      projects: current_author.projects
    }
    render %{conn | assigns: Map.merge(conn.assigns, params)}, "projects.html"
  end

  def account(conn, _params) do
    render conn, "account.html", title: "Account", active: :account
  end
end

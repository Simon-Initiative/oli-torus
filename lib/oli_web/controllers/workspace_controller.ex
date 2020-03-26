defmodule OliWeb.WorkspaceController do
  use OliWeb, :controller
  alias Oli.Course.Project

  def projects(conn, params) do
    params = %{
      title: "Projects",
      project_changeset: Project.changeset(%Project{
        title: params["project_title"] || ""
      }),
      active: :nil,
      author: conn.assigns.current_author
    }
    render %{conn | assigns: Map.merge(conn.assigns, params)}, "projects.html"
  end

  def account(conn, _params) do
    render conn, "account.html", title: "Account", active: :account
  end
end

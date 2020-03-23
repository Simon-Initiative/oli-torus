defmodule OliWeb.WorkspaceController do
  use OliWeb, :controller

  def projects(conn, _params) do
    render conn, "projects.html", title: "Projects"
  end

  def account(conn, _params) do
    render conn, "account.html", title: "Account"
  end
end

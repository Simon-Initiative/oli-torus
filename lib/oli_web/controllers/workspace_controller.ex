defmodule OliWeb.WorkspaceController do
  use OliWeb, :controller

  def projects(conn, _params) do
    render conn, "projects.html", title: "Projects", active: nil
  end

  def account(conn, _params) do
    render conn, "account.html", title: "Account", active: :account
  end
end

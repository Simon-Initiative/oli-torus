defmodule OliWeb.LayoutView do
  use OliWeb, :view

  def active_class(active, path) do
    if active == path do :active else nil end
  end

  def sidebar_link(conn, path, text) do
    link text, to: Routes.project_path(conn, path, conn.assigns.project),
    class: active_class(conn.assigns.active, path)
  end

  def account_link(%{:assigns => assigns} = conn) do
    current_author = assigns.current_author
    full_name = "#{current_author.first_name} #{current_author.last_name}"
    link full_name, to: Routes.workspace_path(conn, :account),
    class: "#{active_class(assigns.active, :account)} account-link"
  end
end

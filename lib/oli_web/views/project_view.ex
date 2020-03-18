defmodule OliWeb.ProjectView do
  use OliWeb, :view
  import Routes

  def active_class(active, path) do
    if active == path do :active else nil end
  end

  def sidebar_link(conn, path, text) do
    link text,
    to: Routes.project_path(conn, path, conn.assigns.project),
    class: active_class(conn.assigns.active, path)
  end
end

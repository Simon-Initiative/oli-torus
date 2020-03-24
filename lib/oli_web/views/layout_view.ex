defmodule OliWeb.LayoutView do
  use OliWeb, :view
  alias Oli.Utils

  def active_or_nil(assigns) do
    get_in(assigns, [Access.key(:active, nil)])
  end

  def active_class(active, path) do
    if active == path do :active else nil end
  end

  def sidebar_link(%{:assigns => assigns} = conn, path, text) do
    link text, to: Routes.project_path(conn, path, assigns.project),
    class: active_class(active_or_nil(assigns), path)
  end

  def account_link(%{:assigns => assigns} = conn) do
    current_author = assigns.current_author
    full_name = "#{current_author.first_name} #{current_author.last_name}"
    link full_name, to: Routes.workspace_path(conn, :account),
    class: "#{active_class(active_or_nil(assigns), :account)} account-link"
  end
end

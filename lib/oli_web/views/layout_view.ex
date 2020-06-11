defmodule OliWeb.LayoutView do
  use OliWeb, :view

  import OliWeb.DeliveryView, only: [user_role: 1, user_role_text: 1, user_role_color: 1, account_linked?: 1]

  def active_or_nil(assigns) do
    get_in(assigns, [Access.key(:active, nil)])
  end

  def active_class(active, path) do
    IO.inspect {active, path}
    if active == path do :active else nil end
  end

  def sidebar_link(%{:assigns => assigns} = _conn, text, path, [to: route]) do
    link text, to: route, class: active_class(active_or_nil(assigns), path)
  end

  def account_link(%{:assigns => assigns} = conn) do
    current_author = assigns.current_author
    full_name = "#{current_author.first_name} #{current_author.last_name}"
    link full_name, to: Routes.workspace_path(conn, :account),
    class: "#{active_class(active_or_nil(assigns), :account)} account-link"
  end

  def render_layout(layout, assigns, do: content) do
    render(layout, Map.put(assigns, :inner_layout, content))
  end
end

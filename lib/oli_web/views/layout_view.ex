defmodule OliWeb.LayoutView do
  use OliWeb, :view

  import OliWeb.DeliveryView, only: [user_role: 1, user_role_text: 1, user_role_color: 1, account_linked?: 1]
  alias Oli.Authoring
  alias Oli.Accounts.AuthorPreferences

  def get_title(assigns) do
    live_title_tag assigns[:page_title] || assigns[:title] || "Open Learning Initiative", suffix: ""
  end

  def active_or_nil(assigns) do
    get_in(assigns, [Access.key(:active, nil)])
  end

  def active_class(active, path) do
    if active == path do :active else nil end
  end

  def sidebar_link(%{:assigns => assigns} = _conn, text, path, [to: route]) do
    link text, to: route, class: active_class(active_or_nil(assigns), path)
  end

  def account_link(%{:assigns => assigns} = conn) do
    current_author = assigns.current_author
    full_name = "#{current_author.first_name} #{current_author.last_name}"
    initials = String.upcase(String.first(current_author.first_name)) <> String.upcase(String.first(current_author.last_name))

    link full_name,
      to: Routes.workspace_path(conn, :account),
      class: "#{active_class(active_or_nil(assigns), :account)} account-link",
      data: [initials: initials]
  end

  def render_layout(layout, assigns, do: content) do
    render(layout, Map.put(assigns, :inner_layout, content))
  end

  def theme_url(%{:assigns => assigns} = _conn, :authoring) do
    case assigns do
      %{current_author: current_author} ->
        case current_author do
          %{preferences: %AuthorPreferences{theme: url}} ->
            url
          _ ->
            Authoring.get_default_theme!().url
        end

      _ ->
        Authoring.get_default_theme!().url
    end
  end

  def theme_url(conn, :delivery) do
    Routes.static_path(conn, "/css/delivery_theme.css")
  end

  def preview_mode(%{assigns: assigns} = _conn) do
    Map.get(assigns, :preview_mode, false)
  end

  def hash_color(initials) do

  end

end

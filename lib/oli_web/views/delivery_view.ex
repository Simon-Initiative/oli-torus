defmodule OliWeb.DeliveryView do
  use OliWeb, :view

  alias Oli.Delivery.Sections.Section

  defp is_preview_mode?(conn) do
    conn.assigns[:preview_mode] == true
  end

  defp is_open_and_free_section?(conn) do
    case conn.assigns[:section] do
      %Section{open_and_free: open_and_free} ->
        open_and_free

      _ ->
        false
    end
  end

  def logo_link_path(conn) do
    cond do
      is_preview_mode?(conn) ->
        "#"

      is_open_and_free_section?(conn) ->
        Routes.delivery_path(conn, :open_and_free_index)

      true ->
        "#"
#        Routes.delivery_path(conn, :index)
    end
  end

  def user_role_is_student(conn, user) do
    case user_role(conn.assigns[:section], user) do
      :open_and_free ->
        true

      :student ->
        true

      _ ->
        false
    end
  end

  def user_role_text(conn, user) do
    case user_role(conn.assigns[:section], user) do
      :open_and_free ->
        "Open and Free"

      :administrator ->
        "Administrator"

      :instructor ->
        "Instructor"

      :student ->
        "Student"

      _ ->
        ""
    end
  end

  def user_role_color(conn, user) do
    case user_role(conn.assigns[:section], user) do
      :open_and_free ->
        "#2C67C4"

      :administrator ->
        "#f39c12"

      :instructor ->
        "#2ecc71"

      :student ->
        "#3498db"

      _ ->
        ""
    end
  end

  def account_linked?(user) do
    user.author_id != nil
  end

  def user_icon(user) do
    case user.picture do
      nil ->
        user_icon()

      picture ->
        ~E"""
        <div class="user-icon">
          <img src="<%= picture %>" class="rounded-circle" />
        </div>
        """
    end
  end

  def user_icon() do
    ~E"""
    <div class="user-icon">
      <div class="user-img rounded-circle">
        <span class="material-icons text-secondary">account_circle</span>
      </div>
    </div>
    """
  end
end

defmodule OliWeb.Pow.UserRoutes do
  use Pow.Phoenix.Routes
  use OliWeb, :controller
  alias OliWeb.Router.Helpers, as: Routes

  @impl true
  def after_sign_in_path(conn) do
    case conn.params do
      %{"user" => %{"section" => section_slug}} ->
        Routes.delivery_path(conn, :enroll, section_slug)

      _ ->
        Routes.delivery_path(conn, :open_and_free_index)
    end
  end

  @impl true
  def after_registration_path(conn) do
    case conn.params do
      %{"user" => %{"section" => section_slug}} ->
        Routes.pow_session_path(conn, :new, section: section_slug)

      _ ->
        Routes.pow_session_path(conn, :new)
    end
  end
end

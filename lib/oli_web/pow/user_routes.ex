defmodule OliWeb.Pow.UserRoutes do
  use Pow.Phoenix.Routes
  use OliWeb, :controller
  alias OliWeb.Router.Helpers, as: Routes

  @impl true
  def after_sign_in_path(conn) do
    Routes.delivery_path(conn, :open_and_free_index)
  end

  @impl true
  def after_registration_path(conn) do
    Routes.delivery_path(conn, :open_and_free_index)
  end
end

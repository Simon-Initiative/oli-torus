defmodule OliWeb.Pow.UserRoutes do
  use Pow.Phoenix.Routes
  use OliWeb, :controller

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Accounts.User

  @impl true
  def after_sign_in_path(conn) do
    conn
    |> request_path_or(
      case conn.params do
        %{"user" => %{"section" => section_slug}} ->
          Routes.delivery_path(conn, :enroll, section_slug)

        _ ->
          Routes.delivery_path(conn, :open_and_free_index)
      end
    )
  end

  @impl true
  def after_registration_path(conn) do
    conn
    |> request_path_or(
      case conn.params do
        %{"user" => %{"section" => section_slug}} ->
          Routes.pow_session_path(conn, :new, section: section_slug)

        _ ->
          Routes.pow_session_path(conn, :new)
      end
    )
  end

  @impl true
  def after_user_updated_path(conn) do
    conn
    |> request_path_or(
      case conn.assigns[:current_user] do
        %User{independent_learner: true} ->
          Routes.delivery_path(conn, :open_and_free_index)

        _ ->
          Routes.delivery_path(conn, :index)
      end
    )
  end

  # Pow stores the request redirect path in the assigns. If that value is
  # present, we use it. Otherwise, we specify default redirect paths.
  def request_path_or(conn, alternative) do
    if !is_nil(Map.get(conn.assigns, :request_path)) do
      conn.assigns.request_path
    else
      alternative
    end
  end
end

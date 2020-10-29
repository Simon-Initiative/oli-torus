defmodule OliWeb.Pow.AuthorRoutes do
  use Pow.Phoenix.Routes
  use OliWeb, :controller
  alias OliWeb.Router.Helpers, as: Routes

  @impl true
  def after_sign_in_path(conn) do
    if conn.params["provider"] do
      link_account_callback_path = Routes.delivery_path(conn, :link_account_callback, conn.params["provider"])

      case conn do
        %Plug.Conn{request_path: ^link_account_callback_path} ->
          conn
            |> Routes.delivery_path(:index)
        _ ->
          Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive)
      end
    end
  end

  @impl true
  def after_user_updated_path(conn) do
    Routes.workspace_path(conn, :account)
  end

  @impl true
  def path_for(%Plug.Conn{assigns: %{link_account: true}} = conn, PowAssent.Phoenix.AuthorizationController, :new, [provider], _query_params) do
    Routes.delivery_path(conn, :process_link_account, provider)
  end
  def path_for(%Plug.Conn{assigns: %{link_account: true}} = conn, PowAssent.Phoenix.AuthorizationController, :create, [provider], _query_params) do
    Routes.delivery_path(conn, :process_link_account, provider)
  end

  def path_for(conn, plug, verb, vars, query_params),
    do: Pow.Phoenix.Routes.path_for(conn, plug, verb, vars, query_params)

end

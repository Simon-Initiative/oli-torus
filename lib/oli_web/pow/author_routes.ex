defmodule OliWeb.Pow.AuthorRoutes do
  use Pow.Phoenix.Routes
  use OliWeb, :controller
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Accounts

  @impl true
  def after_sign_in_path(conn) do
    case maybe_link_account_route(conn) do
      nil ->
        Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive)
      route ->
        route
    end
  end

  @impl true
  def after_registration_path(conn) do
    case maybe_link_account_route(conn) do
      nil ->
        Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive)
      route ->
        route
    end
  end

  defp maybe_link_account_route(conn) do
    if conn.params["provider"] do
      link_account_callback_path = Routes.delivery_path(conn, :link_account_callback, conn.params["provider"])

      case conn do
        %Plug.Conn{request_path: ^link_account_callback_path} ->
          conn
            |> Routes.delivery_path(:index)
        _ ->
          nil
      end
    else
      case conn do
        %Plug.Conn{params: %{"user" => %{"link_account" => "true"}}} ->
          %{current_user: current_user, current_author: current_author} = conn.assigns

          case Accounts.link_user_author_account(current_user, current_author) do
            {:ok, _user} ->
              conn
              |> put_flash(:info, "Account '#{current_author.email}' is now linked")
              |> Routes.delivery_path(:index)
            _ ->
              conn
              |> put_flash(:error, "Failed to link user and author accounts for '#{current_author.email}'")
              |> Routes.delivery_path(:index)
          end
        _ ->
          nil
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

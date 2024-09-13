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

  # maybe links current user and author accounts depending on the route and request type. also handles
  # the social provider case where accounts have already been linked and the user just needs to be directed
  # back to delivery
  defp maybe_link_account_route(conn) do
    if conn.params["provider"] do
      # this is a social provider login, we need to check if it is simply a login action or a link account action
      link_account_callback_path =
        Routes.authoring_delivery_path(conn, :link_account_callback, conn.params["provider"])

      case conn do
        %Plug.Conn{request_path: ^link_account_callback_path} ->
          # action was link account, which already occurred in the custom controller method link_account
          # in delivery_controller. now we just need to redirect back to delivery root
          conn
          |> Routes.delivery_path(:index)

        _ ->
          # action is simply an account login, use the default routing mechanism
          nil
      end
    else
      # this is an email login, check if the request is simply a login or part of account link action
      case conn do
        %Plug.Conn{params: %{"user" => %{"link_account" => "true"}}} ->
          # action is to link account, so link the user and author accounts
          %{current_user: current_user, current_author: current_author} = conn.assigns

          case Accounts.link_user_author_account(current_user, current_author) do
            {:ok, _user} ->
              conn
              |> put_flash(:info, "Account '#{current_author.email}' is now linked")
              |> Routes.delivery_path(:index)

            _ ->
              conn
              |> put_flash(
                :error,
                "Failed to link user and author accounts for '#{current_author.email}'"
              )
              |> Routes.delivery_path(:index)
          end

        _ ->
          # action is simply an account login, use the default routing mechanism
          case conn do
            %{assigns: %{request_path: request_path}} ->
              request_path

            _ ->
              nil
          end
      end
    end
  end

  @impl true
  def after_user_updated_path(conn) do
    Routes.live_path(conn, OliWeb.Workspaces.AccountDetailsLive)
  end

  @impl true
  def path_for(
        %Plug.Conn{assigns: %{link_account_provider_path: link_account_provider_path}} = conn,
        PowAssent.Phoenix.AuthorizationController,
        :new,
        [provider],
        _query_params
      ) do
    link_account_provider_path.(provider)
  end

  def path_for(
        %Plug.Conn{assigns: %{link_account_provider_path: link_account_provider_path}} = conn,
        PowAssent.Phoenix.AuthorizationController,
        :create,
        [provider],
        _query_params
      ) do
    link_account_provider_path.(provider)
  end

  def path_for(conn, PowInvitation.Phoenix.InvitationController, :update, [token], query_params) do
    Pow.Phoenix.Routes.path_for(
      conn,
      PowInvitation.Phoenix.InvitationController,
      :update,
      [token],
      query_params
    )
  end

  def path_for(conn, plug, verb, vars, query_params) do
    "/authoring" <> Pow.Phoenix.Routes.path_for(conn, plug, verb, vars, query_params)
  end

  @impl true
  def url_for(conn, plug, verb, vars, query_params) do
    path = path_for(conn, plug, verb, vars, query_params)
    "#{Oli.Utils.get_base_url()}#{path}"
  end
end

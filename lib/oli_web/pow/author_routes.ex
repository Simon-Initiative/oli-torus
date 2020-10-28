defmodule OliWeb.Pow.AuthorRoutes do
  use Pow.Phoenix.Routes
  use OliWeb, :controller
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Accounts

  @impl true
  def after_sign_in_path(conn) do

    IO.inspect conn, label: "after_sign_in_path"

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
        Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive)
    end
  end

  @impl true
  def after_registration_path(conn) do
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
        Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive)
    end
  end

  @impl true
  def after_user_updated_path(conn) do
    Routes.workspace_path(conn, :account)
  end

  @impl true
  # def path_for(conn, PowAssent.Phoenix.AuthorizationController, :new, vars \\ [], query_params \\ []) do
  def path_for(%Plug.Conn{assigns: %{link_account: true}} = conn, PowAssent.Phoenix.AuthorizationController, :new, [provider], query_params \\ []) do

    # IO.inspect {conn, vars, query_params}, label: "path_for :new"

    # Pow.Phoenix.Routes.path_for(conn, PowAssent.Phoenix.AuthorizationController, :new, vars, [link_account: true])
    Routes.delivery_path(conn, :process_link_account, provider)
  end

  # @impl true
  # def url_for(conn, verb, vars \\ [], query_params \\ [])
  # def url_for(conn, Pow.Phoenix.SessionController, :show, vars, query_params),

  @impl true
  def url_for(conn, PowAssent.Phoenix.AuthorizationController, :callback, vars, query_params) do

    IO.inspect {vars, query_params}, label: "url_for :callback"

    Pow.Phoenix.Routes.url_for(conn, PowAssent.Phoenix.AuthorizationController, :callback, vars, query_params)
  end

  def url_for(conn, plug, verb, vars, query_params),
    do: Pow.Phoenix.Routes.url_for(conn, plug, verb, vars, query_params)
end

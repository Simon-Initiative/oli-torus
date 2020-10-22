defmodule OliWeb.Pow.AuthorRoutes do
  use Pow.Phoenix.Routes
  use OliWeb, :controller
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Accounts

  @impl true
  def after_sign_in_path(conn) do
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
end

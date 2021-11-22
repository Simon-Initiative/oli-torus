defmodule Oli.Plugs.AuthorizeCommunity do
  alias Oli.Accounts
  alias Oli.Groups
  alias Oli.Groups.CommunityAccount
  alias OliWeb.Router.Helpers, as: Routes

  def init(opts), do: opts

  def call(conn, _opts) do
    author = conn.assigns.current_author

    unless Accounts.is_admin?(author) do
      case Groups.get_community_account_by!(%{
             author_id: author.id,
             community_id: conn.params["community_id"]
           }) do
        nil ->
          conn
          |> Phoenix.Controller.put_flash(:info, "You are not an admin of this Community")
          |> Phoenix.Controller.redirect(
            to: Routes.live_path(OliWeb.Endpoint, OliWeb.CommunityLive.IndexView)
          )
          |> Plug.Conn.halt()

        %CommunityAccount{} ->
          conn
      end
    else
      conn
    end
  end
end

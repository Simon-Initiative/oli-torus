defmodule Oli.Plugs.CommunityAdmin do
  use OliWeb, :verified_routes

  alias Oli.Accounts
  alias Oli.Accounts.Author

  def init(opts), do: opts

  def call(conn, _opts) do
    with %Author{} = current_author <- conn.assigns[:current_author],
         true <- Accounts.is_community_admin?(current_author) do
      conn
    else
      _ ->
        conn
        |> Phoenix.Controller.put_flash(:info, "You are not allowed to access Communities")
        |> Phoenix.Controller.redirect(to: ~p"/workspaces/course_author")
        |> Plug.Conn.halt()
    end
  end
end

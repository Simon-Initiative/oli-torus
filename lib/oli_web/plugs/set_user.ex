defmodule Oli.Plugs.SetCurrentUser do
  import Plug.Conn

  alias Oli.Accounts.Author
  alias Oli.Repo

  def init(_params) do
  end

  def call(conn, _params) do
    if conn.assigns[:current_user] do
      conn
    else
      current_user_id = get_session(conn, :current_user_id)

      cond do
        current_user = current_user_id && Repo.get(Author, current_user_id) ->
          assign(conn, :current_user, current_user)

        true ->
          assign(conn, :current_user, nil)
      end
    end
  end
end

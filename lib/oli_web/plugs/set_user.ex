defmodule Oli.Plugs.SetCurrentUser do
  import Plug.Conn

  alias Oli.Accounts.Author
  alias Oli.Accounts.User
  alias Oli.Repo

  def init(_params) do
  end

  def call(conn, _params) do
    conn
    |> set_author
    |> set_user
  end

  def set_author(conn) do
    if author_id = get_session(conn, :current_author_id) do
      cond do
        current_author = Repo.get(Author, author_id) ->
          assign(conn, :current_author, current_author)

        true ->
          assign(conn, :current_author, nil)
      end
    else
      conn
    end
  end

  def set_user(conn) do
    if user_id = get_session(conn, :current_user_id) do
      cond do
        current_user = Repo.get(User, user_id) |> Repo.preload([:platform_roles, :author]) ->
          assign(conn, :current_user, current_user)

        true ->
          assign(conn, :current_user, nil)
      end
    else
      conn
    end
  end

end

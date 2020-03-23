defmodule Oli.Plugs.SetCurrentUser do
  import Plug.Conn

  alias Oli.Accounts.Author
  alias Oli.Accounts.User
  alias Oli.Repo

  def init(_params) do
  end

  def call(conn, _params) do
    if author_id = get_session(conn, :current_author_id) do
      cond do
        current_author = Repo.get(Author, author_id) ->
          assign(conn, :current_author, current_author)

        true ->
          assign(conn, :current_author, nil)
      end
    end
    if user_id = get_session(conn, :current_user_id) do
      cond do
        current_user = Repo.get(User, user_id) ->
          assign(conn, :current_user, current_user)

        true ->
          assign(conn, :current_user, nil)
      end
    end
  end
end

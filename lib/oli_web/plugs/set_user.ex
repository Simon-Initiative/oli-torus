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
    conn = OliWeb.Pow.PowHelpers.use_pow_config(conn, :author)

    if author = Pow.Plug.current_user(conn) do
      cond do
        current_author = Repo.get(Author, author.id) ->
          assign(conn, :current_author, current_author)

        true ->
          assign(conn, :current_author, nil)
      end
    else
      conn
    end
  end

  def set_user(conn) do
    conn = OliWeb.Pow.PowHelpers.use_pow_config(conn, :user)

    if user = Pow.Plug.current_user(conn) do
      cond do
        current_user = Repo.get(User, user.id) |> Repo.preload([:platform_roles, :author]) ->
          assign(conn, :current_user, current_user)

        true ->
          assign(conn, :current_user, nil)
      end
    else
      conn
    end
  end
end

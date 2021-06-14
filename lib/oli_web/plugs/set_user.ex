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
    |> set_user_token
  end

  def set_author(conn) do
    pow_config = OliWeb.Pow.PowHelpers.get_pow_config(:author)

    if author = Pow.Plug.current_user(conn, pow_config) do
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
    pow_config = OliWeb.Pow.PowHelpers.get_pow_config(:user)

    if user = Pow.Plug.current_user(conn, pow_config) do
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

  defp set_user_token(conn) do
    case conn.assigns[:current_user] do
      nil ->
        conn

      user ->
        token = Phoenix.Token.sign(conn, "user socket", user.sub)
        assign(conn, :user_token, token)
    end
  end
end

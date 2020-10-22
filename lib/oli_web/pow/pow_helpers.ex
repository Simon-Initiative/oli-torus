defmodule OliWeb.Pow.PowHelpers do

  def get_pow_config(:user) do
    [
      repo: Oli.Repo,
      user: Oli.Accounts.User,
      current_user_assigns_key: :current_user,
      session_key: "user_auth",
      # TODO: REMOVE
      # web_module: OliWeb,
      routes_backend: OliWeb.Pow.UserRoutes,
      plug: Pow.Plug.Session
    ]
  end

  def get_pow_config(:author) do
    [
      repo: Oli.Repo,
      user: Oli.Accounts.Author,
      current_user_assigns_key: :current_author,
      session_key: "author_auth",
      web_module: OliWeb,
      routes_backend: OliWeb.Pow.AuthorRoutes,
      plug: Pow.Plug.Session
    ]
  end

  def use_pow_config(conn, :user) do
    Pow.Plug.put_config(conn, get_pow_config(:user))
  end

  def use_pow_config(conn, :author) do
    Pow.Plug.put_config(conn, get_pow_config(:author))
  end
end

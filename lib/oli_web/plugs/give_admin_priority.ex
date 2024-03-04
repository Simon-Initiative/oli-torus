defmodule Oli.Plugs.GiveAdminPriority do
  alias Oli.Accounts.Author
  alias Oli.Repo

  def init(_params) do
  end

  def call(conn, _params) do
    conn
    |> check_for_admin
  end

  def check_for_admin(conn) do
    pow_config = OliWeb.Pow.PowHelpers.get_pow_config(:author)

    if author = Pow.Plug.current_user(conn, pow_config) do
      author = Repo.get(Author, author.id)

      case Oli.Accounts.has_admin_role?(author) do
        true -> OliWeb.Pow.PowHelpers.use_pow_config(conn, :author)
        _ -> OliWeb.Pow.PowHelpers.use_pow_config(conn, :user)
      end
    else
      OliWeb.Pow.PowHelpers.use_pow_config(conn, :user)
    end
  end
end

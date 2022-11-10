defmodule Oli.Utils.Seeder.Session do
  import Oli.Utils.Seeder.Utils

  @doc """
  Creates an author session
  """
  def login_as_author(%{conn: conn} = seeds, author, _tags \\ []) do
    [author] = unpack(seeds, [author])

    conn =
      Plug.Test.init_test_session(conn, %{})
      |> Pow.Plug.assign_current_user(author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    %{seeds | conn: conn}
  end

  @doc """
  Creates a user session
  """
  def login_as_user(%{conn: conn} = seeds, user, _tags \\ []) do
    [user] = unpack(seeds, [user])

    conn =
      Plug.Test.init_test_session(conn, %{})
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    %{seeds | conn: conn}
  end
end

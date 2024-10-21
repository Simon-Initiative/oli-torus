defmodule Oli.Utils.Seeder.Session do
  import Oli.Utils.Seeder.Utils

  alias OliWeb.{AuthorAuth, UserAuth}

  @doc """
  Creates an author session
  """
  def login_as_author(%{conn: conn} = seeds, author, _tags \\ []) do
    [author] = unpack(seeds, [author])

    conn =
      Plug.Test.init_test_session(conn, %{})
      |> AuthorAuth.log_in_author(author)

    %{seeds | conn: conn}
  end

  @doc """
  Creates a user session
  """
  def login_as_user(%{conn: conn} = seeds, user, _tags \\ []) do
    [user] = unpack(seeds, [user])

    conn =
      Plug.Test.init_test_session(conn, %{})
      |> UserAuth.log_in_user(user)

    %{seeds | conn: conn}
  end
end

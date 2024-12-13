defmodule Oli.Utils.Seeder.Session do
  import Oli.Utils.Seeder.Utils

  @doc """
  Creates an author session
  """
  def login_as_author(%{conn: conn} = seeds, author, _tags \\ []) do
    [author] = unpack(seeds, [author])

    token = Oli.Accounts.generate_author_session_token(author)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:author_token, token)
    |> Plug.Conn.put_session(:current_author_id, author.id)

    %{seeds | conn: conn}
  end

  @doc """
  Creates a user session
  """
  def login_as_user(%{conn: conn} = seeds, user, _tags \\ []) do
    [user] = unpack(seeds, [user])

    token = Oli.Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
    |> Plug.Conn.put_session(:current_user_id, user.id)

    %{seeds | conn: conn}
  end
end

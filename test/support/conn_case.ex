defmodule OliWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      alias OliWeb.Router.Helpers, as: Routes
      use OliWeb, :verified_routes

      import Oli.TestHelpers
      import Oli.AccountsFixtures
      import OliWeb.ConnCase

      # The default endpoint for testing
      @endpoint OliWeb.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Oli.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Oli.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in users.

      setup :register_and_log_in_user

  It stores an updated connection and a registered user in the
  test context.
  """
  def register_and_log_in_user(%{conn: conn}) do
    user = Oli.AccountsFixtures.user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user) do
    token = Oli.Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  @doc """
  Setup helper that registers and logs in authors.

      setup :register_and_log_in_author

  It stores an updated connection and a registered author in the
  test context.
  """
  def register_and_log_in_author(%{conn: conn}) do
    author = Oli.AccountsFixtures.author_fixture()
    %{conn: log_in_author(conn, author), author: author}
  end

  @doc """
  Logs the given `author` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_author(conn, author) do
    token = Oli.Accounts.generate_author_session_token(author)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:author_token, token)
  end
end

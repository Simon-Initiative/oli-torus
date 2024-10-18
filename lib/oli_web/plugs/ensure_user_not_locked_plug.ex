## MER-3835 TODO: REMOVE
defmodule OliWeb.EnsureUserNotLockedPlug do
  @moduledoc """
  This plug ensures that a user isn't locked.

  ## Example

      plug MyAppWeb.EnsureUserNotLockedPlug
  """
  import Plug.Conn, only: [halt: 1]

  alias OliWeb.Router.Helpers, as: Routes
  alias Phoenix.Controller
  alias Plug.Conn
  alias Pow.Plug

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, _opts) do
    conn
    |> Plug.current_user()
    |> locked?()
    |> maybe_halt(conn)
  end

  defp locked?(%{locked_at: locked_at}) when not is_nil(locked_at), do: true
  defp locked?(_user), do: false

  defp maybe_halt(true, conn) do
    conn
    |> Plug.delete()
    |> PowPersistentSession.Plug.delete()
    |> Controller.put_flash(:error, "Sorry, your account is locked. Please contact support.")
    |> then(fn conn ->
      if conn.private.pow_config |> Keyword.get(:user) == Oli.Accounts.Author do
        Controller.redirect(conn, to: Routes.authoring_pow_session_path(conn, :new))
      else
        Controller.redirect(conn, to: Routes.pow_session_path(conn, :new))
      end
    end)
    |> halt()
  end

  defp maybe_halt(_any, conn), do: conn
end

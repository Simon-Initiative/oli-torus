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

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, _opts) do
    conn
    |> Kernel.get_in([:assigns, :current_user])
    |> locked?()
    |> maybe_halt(conn)
  end

  defp locked?(%{locked_at: locked_at}) when not is_nil(locked_at), do: true
  defp locked?(_user), do: false

  defp maybe_halt(true, conn) do
    # MER-3835 TODO
    throw "NOT IMPLEMENTED"
  end

  defp maybe_halt(_any, conn), do: conn
end

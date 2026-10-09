defmodule OliWeb.Plugs.RequestParsers do
  @moduledoc """
  Preserves response callbacks when request parsing fails before routing.

  Phoenix renders an unwrapped endpoint exception using the original connection.
  Wrapping parser errors carries forward the security callbacks registered before
  parsing, without changing the error status or Phoenix's rendering behavior.
  """
  @behaviour Plug

  alias Plug.Conn.WrapperError

  @impl true
  def init(opts), do: Plug.Parsers.init(opts)

  @impl true
  def call(conn, opts) do
    Plug.Parsers.call(conn, opts)
  rescue
    error in WrapperError -> reraise error, __STACKTRACE__
    error -> WrapperError.reraise(conn, :error, error, __STACKTRACE__)
  end
end

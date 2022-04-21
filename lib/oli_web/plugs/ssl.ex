defmodule Oli.Plugs.SSL do
  @moduledoc """
    SSL redirect excluding the health endpoint.
  """
  @behaviour Plug

  @impl true
  def init(opts), do: Plug.SSL.init(opts)

  @impl true
  def call(%{request_path: "/healthz"} = conn, _opts), do: conn
  def call(conn, opts), do: Plug.SSL.call(conn, opts)
end

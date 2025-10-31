defmodule Oli.Plugs.SSL do
  @moduledoc """
    SSL redirect excluding the health endpoint.
  """
  @behaviour Plug

  @impl true
  def init(opts), do: Plug.SSL.init(opts)

  @impl true
  def call(%{request_path: "/healthz"} = conn, _opts), do: conn

  def call(conn, opts) do
    if force_ssl?() do
      Plug.SSL.call(conn, opts)
    else
      conn
    end
  end

  defp force_ssl? do
    Application.get_env(:oli, :force_ssl_redirect?, true)
  end
end

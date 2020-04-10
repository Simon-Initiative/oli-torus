defmodule Oli.Plugs.NoCache do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    put_resp_header(conn, "cache-control", "no-cache, no-store, must-revalidate")
  end
end

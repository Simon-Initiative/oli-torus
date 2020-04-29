defmodule Oli.Plugs.RemoveXFrameOptions do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    delete_resp_header(conn, "x-frame-options")
  end
end





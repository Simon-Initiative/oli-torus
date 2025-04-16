defmodule OliWeb.Plugs.AllowIframe do
  @moduledoc """
  Allows ressources to be loaded in an iframe.
  """

  alias Plug.Conn

  def init(opts \\ %{}), do: opts

  def call(conn, _opts) do
    Conn.delete_resp_header(conn, "x-frame-options")
  end
end

defmodule OliWeb.Plugs.SetLicense do
  import Plug.Conn
  def init(_params), do: nil

  def call(conn, _params) do
    assign(conn, :has_license, true)
  end
end

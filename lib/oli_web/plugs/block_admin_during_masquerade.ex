defmodule OliWeb.Plugs.BlockAdminDuringMasquerade do
  import Plug.Conn
  import Phoenix.Controller

  alias OliWeb.Accounts.Masquerade

  def init(opts), do: opts

  def call(conn, _opts) do
    if Masquerade.active?(conn.assigns[:masquerade]) and admin_path?(conn) and
         not stop_path?(conn) do
      conn
      |> put_flash(:error, "Admin pages are unavailable while acting as a user")
      |> redirect(to: "/")
      |> halt()
    else
      conn
    end
  end

  defp admin_path?(conn), do: String.starts_with?(conn.request_path, "/admin")

  defp stop_path?(conn) do
    conn.request_path == "/admin/masquerade"
  end
end

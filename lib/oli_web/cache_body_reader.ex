defmodule OliWeb.CacheBodyReader do
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = if enabled_for?(conn) do
      update_in(conn.assigns[:raw_body], &[body | (&1 || [])])
    else
      conn
    end
    {:ok, body, conn}
  end

  defp enabled_for?(conn) do
    case conn.path_info do
      ["jcourse", "dashboard", "log", "server" | _rest] -> true
      _ -> false
    end
  end
end

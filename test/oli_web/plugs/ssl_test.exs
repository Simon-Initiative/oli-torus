defmodule Oli.Plugs.SSLTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  setup do
    previous = Application.fetch_env(:oli, :force_ssl_redirect?)
    Application.put_env(:oli, :force_ssl_redirect?, true)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:oli, :force_ssl_redirect?, value)
        :error -> Application.delete_env(:oli, :force_ssl_redirect?)
      end
    end)
  end

  test "only exact probe paths bypass HTTP redirects, including query strings" do
    opts = Oli.Plugs.SSL.init(log: false, host: "torus.example")

    for path <- ["/healthz", "/readyz", "/readyz?probe=pod"] do
      conn = conn(:get, path) |> Oli.Plugs.SSL.call(opts)
      refute conn.halted
      assert get_resp_header(conn, "location") == []
    end

    for path <- ["/", "/healthz/extra", "/readyz/extra"] do
      conn = conn(:get, path) |> Oli.Plugs.SSL.call(opts)
      assert conn.status == 301
      assert conn.halted
    end
  end
end

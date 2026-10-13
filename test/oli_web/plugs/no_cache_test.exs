defmodule Oli.Plugs.NoCacheTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Oli.Plugs.NoCache

  test "sensitive successes, redirects and errors cannot become cacheable downstream" do
    for status <- [200, 302, 400, 401, 403, 404, 500] do
      conn =
        conn(:get, "/")
        |> NoCache.call([])
        |> put_resp_header("cache-control", "public, max-age=3600")
        |> send_resp(status, "")

      assert get_resp_header(conn, "cache-control") == ["private, no-store"]
    end
  end

  test "protects streamed responses and is safe to apply in endpoint and pipeline" do
    conn = conn(:get, "/") |> NoCache.call([]) |> NoCache.call([]) |> send_chunked(200)
    assert get_resp_header(conn, "cache-control") == ["private, no-store"]
  end

  test "explicit non-sensitive content preserves its existing private cache policy" do
    conn =
      conn(:get, "/")
      |> NoCache.call([])
      |> NoCache.public_content()
      |> put_resp_header("cache-control", "private, max-age=300")
      |> send_resp(200, "GIF89a")

    assert get_resp_header(conn, "cache-control") == ["private, max-age=300"]
  end

  test "public-content exceptions cannot cache errors or responses issuing cookies" do
    for status <- [200, 302, 500], cookie <- [:plug_cookie, :raw_header, :none] do
      conn =
        conn(:get, "/")
        |> NoCache.call([])
        |> NoCache.public_content()

      conn =
        case cookie do
          :plug_cookie -> put_resp_cookie(conn, "session", "value")
          :raw_header -> put_resp_header(conn, "set-cookie", "session=value")
          :none -> conn
        end

      conn = send_resp(conn, status, "")

      unless status == 200 and cookie == :none do
        assert get_resp_header(conn, "cache-control") == ["private, no-store"]
      end
    end
  end
end

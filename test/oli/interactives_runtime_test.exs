defmodule Oli.Interactives.RuntimeTest do
  use Oli.DataCase
  import Mox
  import Phoenix.ConnTest
  alias Oli.Interactives.Runtime
  alias Oli.Test.MockAws
  @endpoint OliWeb.Endpoint
  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    Cachex.del(:page_content_cache, Runtime.cache_key())
    on_exit(fn -> Cachex.del(:page_content_cache, Runtime.cache_key()) end)
    :ok
  end

  test "publishes shared runtime assets once and leaves original bundles untouched" do
    expect(MockAws, :request, 2, fn op ->
      assert op.http_method == :put
      assert op.path =~ "interactives/runtime/"
      assert op.path =~ "frame.html" or op.path =~ "torus.js"
      assert op.headers["cache-control"] =~ "immutable"
      {:ok, %{status_code: 200}}
    end)

    assert {:ok, url} = Runtime.entry("e591269c-9245-44ed-b0b0-a3259f7c0e8f")
    assert url =~ "/frame.html?bundle=e591269c-9245-44ed-b0b0-a3259f7c0e8f"
    assert {:ok, ^url} = Runtime.entry("e591269c-9245-44ed-b0b0-a3259f7c0e8f")
    conn = get(build_conn(), "/interactives/runtime/e591269c-9245-44ed-b0b0-a3259f7c0e8f")
    assert redirected_to(conn, 302) == url
    assert Enum.join(Plug.Conn.get_resp_header(conn, "cache-control"), ",") =~ "no-store"
  end

  test "retries publication after a transient storage failure" do
    expect(MockAws, :request, fn _ -> {:error, :unavailable} end)
    assert {:error, :unavailable} = Runtime.entry("e591269c-9245-44ed-b0b0-a3259f7c0e8f")
    expect(MockAws, :request, 2, fn _ -> {:ok, %{status_code: 200}} end)
    assert {:ok, _} = Runtime.entry("e591269c-9245-44ed-b0b0-a3259f7c0e8f")
  end

  test "rejects malformed bundle identifiers without storage requests" do
    assert {:error, :invalid_bundle} = Runtime.entry("../../private")
    assert response(get(build_conn(), "/interactives/runtime/invalid"), 400) =~ "Invalid"
  end
end

defmodule OliWeb.ReadinessControllerTest do
  use OliWeb.ConnCase, async: false

  @build Application.compile_env!(:oli, :build)

  setup do
    Oli.Health.starting()
    Oli.Health.started()

    on_exit(fn ->
      Oli.Health.starting()
      Oli.Health.started()
    end)
  end

  test "HTTP and HTTPS return only ready and this compiled build identity", %{conn: conn} do
    for scheme <- [:http, :https] do
      conn = get(%{conn | scheme: scheme}, "/readyz")
      assert json_response(conn, 200) == body("ready")
      assert is_binary(json_response(conn, 200)["version"])
      assert is_binary(json_response(conn, 200)["sha"])
      assert get_resp_header(conn, "cache-control") == ["no-store"]
      assert get_resp_header(conn, "location") == []
      assert conn.private[:plug_session_fetch] != :done
    end
  end

  test "startup and drain return generic 503 with the same build identity", %{conn: conn} do
    for transition <- [&Oli.Health.starting/0, &Oli.Health.drain/0] do
      transition.()
      response = get(conn, "/readyz")
      assert json_response(response, 503) == body("not_ready")
      assert get_resp_header(response, "cache-control") == ["no-store"]
    end
  end

  test "runtime metadata and a client's desired SHA cannot replace compiled identity", %{
    conn: conn
  } do
    previous = Application.fetch_env!(:oli, :build)
    on_exit(fn -> Application.put_env(:oli, :build, previous) end)
    Application.put_env(:oli, :build, %{version: "future", sha: "different", secret: "private"})

    assert conn |> get("/readyz?sha=different&version=future") |> json_response(200) ==
             body("ready")
  end

  test "query errors stay private and do not affect liveness", %{conn: conn} do
    assert {:error, %Postgrex.Error{}} =
             Oli.Repo.query("SELECT 1 / 0", [], log: false, sandbox_subtransaction: false)

    assert conn |> get("/readyz") |> json_response(503) == body("not_ready")
    assert conn |> get("/healthz") |> json_response(200) == %{"status" => "Ayup!"}
  end

  defp body(status), do: %{"status" => status, "version" => @build.version, "sha" => @build.sha}
end

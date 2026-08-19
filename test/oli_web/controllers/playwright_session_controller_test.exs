defmodule OliWeb.PlaywrightSessionControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  describe "log_in_user/2" do
    setup do
      previous_token = Application.get_env(:oli, :playwright_scenario_token)
      token = "playwright-session-controller-test-token"

      Application.put_env(:oli, :playwright_scenario_token, token)

      on_exit(fn ->
        Application.put_env(:oli, :playwright_scenario_token, previous_token)
      end)

      %{scenario_token: token}
    end

    test "creates a browser session for a seeded user and redirects to the requested path", %{
      scenario_token: scenario_token
    } do
      user = insert(:user, guest: true)

      conn =
        build_conn()
        |> put_req_header("x-playwright-scenario-token", scenario_token)
        |> get("/test/log_in_user", %{
          "email" => user.email,
          "request_path" => "/workspaces/student"
        })

      assert redirected_to(conn) == "/workspaces/student"
      assert get_session(conn, :current_user_id) == user.id
      assert get_session(conn, :user_token)
    end

    test "rejects unauthorized requests" do
      user = insert(:user)

      conn =
        build_conn()
        |> put_req_header("x-playwright-scenario-token", "bad-token")
        |> get("/test/log_in_user", %{"email" => user.email})

      assert response(conn, 401) == "unauthorized"
    end

    test "rejects requests that pass the token via query params only", %{
      scenario_token: scenario_token
    } do
      user = insert(:user)

      conn =
        build_conn()
        |> get("/test/log_in_user", %{
          "token" => scenario_token,
          "email" => user.email
        })

      assert response(conn, 401) == "unauthorized"
    end

    test "ignores unsafe redirect targets", %{scenario_token: scenario_token} do
      user = insert(:user)

      conn =
        build_conn()
        |> put_req_header("x-playwright-scenario-token", scenario_token)
        |> get("/test/log_in_user", %{
          "email" => user.email,
          "request_path" => "https://evil.example"
        })

      assert redirected_to(conn) == "/"
    end

    test "ignores redirect targets with backslashes", %{scenario_token: scenario_token} do
      user = insert(:user)

      conn =
        build_conn()
        |> put_req_header("x-playwright-scenario-token", scenario_token)
        |> get("/test/log_in_user", %{
          "email" => user.email,
          "request_path" => "/\\evil.example"
        })

      assert redirected_to(conn) == "/"
    end
  end
end

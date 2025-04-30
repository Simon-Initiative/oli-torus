defmodule OliWeb.HelpControllerTest do
  use OliWeb.ConnCase

  alias Oli.Test.MockHTTP

  import Mox

  describe "request_help" do
    test "send help request", %{conn: conn} do
      expect_recaptcha_http_post()

      freshdesk_url = System.get_env("FRESHDESK_API_URL", "example.edu")

      MockHTTP
      |> expect(:post, fn ^freshdesk_url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200
         }}
      end)

      conn =
        post(
          conn,
          Routes.help_path(conn, :create),
          help: %{
            full_name: "Help Me",
            email: "help@example.edu",
            subject: "help_login",
            message: "Lorem Ipsum is simply dummy text of the printing and typesetting industry.",
            timestamp: "timestamp",
            ip_address: "ip_address",
            location: "https://localhost/project/philosophy",
            user_agent: "user_agent",
            agent_accept: "agent_accept",
            agent_language: "agent_language",
            cookies_enabled: true,
            account_email: "account_email",
            account_name: "account_name",
            account_created: "account_created",
            screen_size: "screen_size",
            browser_size: "browser_size",
            browser_plugins: "browser_plugins",
            user_type: "user_type",
            operating_system: "operating_system",
            browser_info: "browser_info",
            course_data: nil,
            student_report_url: "student_report_url",
            user_account_url: "user_account_url",
            screenshots: []
          },
          "g-recaptcha-response": "any"
        )

      assert keys = json_response(conn, 200)
      assert Map.get(keys, "result") == "success"
    end
  end
end

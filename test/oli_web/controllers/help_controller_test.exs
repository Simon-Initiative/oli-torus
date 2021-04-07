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
        conn
        |> put_req_header("accept", "text/html")
        |> put_req_header("accept-language", "en-US,en;q=0.9")
        |> put_req_header("user-agent", "test agent")

      conn =
        post(
          conn,
          Routes.help_path(conn, :create),
          location: "https://localhost/project/philosophy",
          cookies_enabled: "true",
          full_name: "Help Me",
          email: "help@example.edu",
          subject: "help_tech",
          message: "Lorem Ipsum is simply dummy text of the printing and typesetting industry.",
          "g-recaptcha-response": "any"
        )

      assert redirected_to(conn) =~ "/help/sent"
    end
  end
end

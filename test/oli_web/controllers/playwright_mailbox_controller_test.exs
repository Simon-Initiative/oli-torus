defmodule OliWeb.PlaywrightMailboxControllerTest do
  use OliWeb.ConnCase

  alias Swoosh.Adapters.Local.Storage.Memory

  @token "playwright-mailbox-controller-test-token"

  setup do
    previous_token = Application.get_env(:oli, :playwright_scenario_token)
    Application.put_env(:oli, :playwright_scenario_token, @token)
    Memory.delete_all()

    on_exit(fn ->
      Memory.delete_all()
      Application.put_env(:oli, :playwright_scenario_token, previous_token)
    end)

    :ok
  end

  test "lists only messages for the requested recipient and subject", %{conn: conn} do
    confirmation = deliver("pw-author@example.test", "Confirm your email", "confirm link")
    _reset = deliver("pw-author@example.test", "Reset password", "reset link")
    _other = deliver("other@example.test", "Confirm your email", "other link")

    conn =
      conn
      |> authorized()
      |> get("/test/emails", %{
        "to" => "pw-author@example.test",
        "subject" => "Confirm your email"
      })

    assert %{"emails" => [email]} = json_response(conn, 200)
    assert email["id"] == message_id(confirmation)
    assert email["to"] == ["pw-author@example.test"]
    assert email["subject"] == "Confirm your email"
    assert is_binary(email["sent_at"])
  end

  test "returns message detail by id", %{conn: conn} do
    email = deliver("pw-user@example.test", "Reset password", "reset link")

    conn = conn |> authorized() |> get("/test/emails/#{message_id(email)}")

    assert %{
             "email" => %{
               "id" => id,
               "html_body" => "<p>reset link</p>",
               "text_body" => "reset link"
             }
           } = json_response(conn, 200)

    assert id == message_id(email)
  end

  test "requires the Playwright token", %{conn: conn} do
    conn = get(conn, "/test/emails", %{"to" => "pw-user@example.test"})

    assert response(conn, 401) == "unauthorized"
  end

  test "requires the Playwright token to retrieve message detail", %{conn: conn} do
    email = deliver("pw-user@example.test", "Reset password", "reset link")

    conn = get(conn, "/test/emails/#{message_id(email)}")

    assert response(conn, 401) == "unauthorized"
  end

  test "requires a recipient when listing messages", %{conn: conn} do
    conn = conn |> authorized() |> get("/test/emails")

    assert response(conn, 400) == "missing_recipient"
  end

  test "returns not found for an unknown message", %{conn: conn} do
    conn = conn |> authorized() |> get("/test/emails/not-a-message")

    assert response(conn, 404) == "not_found"
  end

  defp deliver(to, subject, text_body) do
    email =
      Swoosh.Email.new()
      |> Swoosh.Email.from({"Torus", "no-reply@example.test"})
      |> Swoosh.Email.to(to)
      |> Swoosh.Email.subject(subject)
      |> Swoosh.Email.html_body("<p>#{text_body}</p>")
      |> Swoosh.Email.text_body(text_body)

    Memory.push(email)
  end

  defp message_id(%{headers: %{"Message-ID" => id}}), do: id

  defp authorized(conn), do: put_req_header(conn, "x-playwright-scenario-token", @token)
end

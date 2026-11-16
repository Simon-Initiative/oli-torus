defmodule OliWeb.CookieConsentCSRFTest do
  use OliWeb.ConnCase, async: true

  alias Oli.Consent

  test "signed-in consent saves reject missing tokens without changing the stored choice", %{
    conn: conn
  } do
    user = user_fixture()
    store_rejection(user.id)
    original = Consent.retrieve_cookies(user.id)
    {conn, _token} = conn |> log_in_user(user) |> csrf_session()

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      post(conn, ~p"/consent/cookie", consent_params(true))
    end

    assert Consent.retrieve_cookies(user.id) == original
  end

  test "invalid or another session's token cannot create consent", %{conn: conn} do
    user = user_fixture()
    {_other_conn, other_token} = conn |> init_test_session(%{}) |> csrf_session()
    {conn, _token} = conn |> log_in_user(user) |> csrf_session()

    for token <- ["invalid-token", other_token] do
      assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
        conn
        |> put_req_header("x-csrf-token", token)
        |> post(~p"/consent/cookie", consent_params(true))
      end
    end

    assert Consent.retrieve_cookies(user.id) == []
  end

  test "a valid session-bound header token persists and acknowledges JSON consent", %{conn: conn} do
    user = user_fixture()
    {conn, token} = conn |> log_in_user(user) |> csrf_session()
    params = consent_params(false)

    response =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-csrf-token", token)
      |> post(~p"/consent/cookie", Jason.encode!(params))

    assert %{
             "result" => "success",
             "persistence" => "persisted",
             "acknowledged" => true,
             "decision" => %{"group" => group, "sequence" => 1}
           } = json_response(response, 200)

    assert group == params.decision.group
    refute Consent.preferences_for_user(user.id)["analytics"]
  end

  test "a cross-site form-shaped opt-in cannot bypass CSRF through JSON negotiation", %{
    conn: conn
  } do
    user = user_fixture()
    {conn, _token} = conn |> log_in_user(user) |> csrf_session()
    [choice] = consent_params(true).cookies

    body =
      URI.encode_query([
        {"cookies[][name]", choice["name"]},
        {"cookies[][value]", choice["value"]},
        {"cookies[][expiresIso]", choice["expiresIso"]}
      ])

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      conn
      |> put_req_header("accept", "text/html")
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> put_req_header("origin", "https://untrusted.example")
      |> post("/consent/cookie?_format=json", body)
    end

    assert Consent.retrieve_cookies(user.id) == []
  end

  test "anonymous consent saves also require a valid token", %{conn: conn} do
    {conn, token} = conn |> init_test_session(%{}) |> csrf_session()

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      post(conn, ~p"/consent/cookie", consent_params(false))
    end

    response =
      conn
      |> put_req_header("x-csrf-token", token)
      |> post(~p"/consent/cookie", consent_params(false))

    assert %{"persistence" => "browser_only", "acknowledged" => false} =
             json_response(response, 200)
  end

  test "GET retrieval remains available without a CSRF token", %{conn: conn} do
    user = user_fixture()
    store_rejection(user.id)

    response =
      conn
      |> log_in_user(user)
      |> put_private(:plug_skip_csrf_protection, false)
      |> get(~p"/consent/cookie")

    assert [%{"name" => "_cky_opt_choices"}] = json_response(response, 200)

    response =
      build_conn()
      |> put_private(:plug_skip_csrf_protection, false)
      |> get(~p"/consent/cookie")

    assert %{"result" => "no-op"} = json_response(response, 200)
  end

  defp csrf_session(conn) do
    Plug.CSRFProtection.load_state(OliWeb.Endpoint.config(:secret_key_base), nil)
    token = Plug.CSRFProtection.get_csrf_token()
    session_token = Plug.CSRFProtection.dump_state()
    Plug.CSRFProtection.delete_csrf_token()

    {conn
     |> put_session("_csrf_token", session_token)
     |> put_private(:plug_skip_csrf_protection, false), token}
  end

  defp consent_params(analytics) do
    %{
      cookies: [
        %{
          "name" => "_cky_opt_choices",
          "value" => Jason.encode!(%{"version" => 2, "analytics" => analytics}),
          "expiresIso" => DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.to_iso8601()
        }
      ],
      decision: %{group: String.duplicate("a", 32), sequence: 1}
    }
  end

  defp store_rejection(user_id) do
    Consent.insert_cookie(
      "_cky_opt_choices",
      ~s({"version":2,"analytics":false}),
      DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.truncate(:second),
      user_id
    )
  end
end

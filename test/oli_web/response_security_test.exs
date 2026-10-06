defmodule OliWeb.ResponseSecurityTest do
  use OliWeb.ConnCase, async: true

  test "login HTML retains its framing restriction and prevents storage", %{conn: conn} do
    for path <- ["/users/log_in", "/authors/log_in"] do
      response = get(conn, path)
      assert html_response(response, 200)
      assert get_resp_header(response, "cache-control") == ["private, no-store"]
      assert [csp] = get_resp_header(response, "content-security-policy")
      assert csp =~ "frame-ancestors 'self'"
      refute csp =~ "*"

      assert [cookie] = get_resp_header(response, "set-cookie")
      assert cookie =~ "_oli_key="
      assert cookie =~ "; path=/"
      assert cookie =~ "; secure"
      assert cookie =~ "; HttpOnly"
      assert cookie =~ "; SameSite=None"
      refute String.downcase(cookie) =~ "; domain="
    end
  end

  test "LTI registration and launch errors get an iframe-safe CSP", %{conn: conn} do
    response = get(conn, "/lti/register_form")
    assert html_response(response, 200)
    assert get_resp_header(response, "cache-control") == ["private, no-store"]
    assert get_resp_header(response, "content-security-policy") == ["base-uri 'self'"]
    assert get_resp_header(response, "x-frame-options") == []

    response = post(conn, "/lti/launch", %{})
    assert html_response(response, 400)
    assert get_resp_header(response, "cache-control") == ["private, no-store"]
    assert get_resp_header(response, "content-security-policy") == ["base-uri 'self'"]
  end

  test "delivery retains embedding and auth redirects cannot be stored", %{conn: conn} do
    response = get(conn, "/")
    assert html_response(response, 200)
    assert [csp] = get_resp_header(response, "content-security-policy")
    assert csp =~ "frame-ancestors 'self' *"
    assert get_resp_header(response, "cache-control") == ["private, no-store"]

    response = get(conn, "/users/settings")
    assert redirected_to(response) =~ "/users/log_in"
    assert get_resp_header(response, "cache-control") == ["private, no-store"]
  end

  test "static assets and public verification keys retain caching", %{conn: conn} do
    response = get(conn, "/robots.txt")
    assert response(response, 200)

    refute Enum.any?(
             get_resp_header(response, "cache-control"),
             &String.contains?(&1, "no-store")
           )

    response =
      conn |> put_req_header("accept", "application/json") |> get("/.well-known/jwks.json")

    assert %{"keys" => _} = json_response(response, 200)

    refute Enum.any?(
             get_resp_header(response, "cache-control"),
             &String.contains?(&1, "no-store")
           )
  end

  test "ordinary browser mutations still require CSRF protection", %{conn: conn} do
    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      conn
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/users/log_in", %{"user" => %{"email" => "test@example.edu", "password" => "bad"}})
    end
  end

  test "not-found pages and parser exceptions retain response protection", %{conn: conn} do
    not_found = get(conn, "/missing-mer-5179-route")
    assert html_response(not_found, 404)
    assert get_resp_header(not_found, "cache-control") == ["private, no-store"]
    assert [csp] = get_resp_header(not_found, "content-security-policy")
    assert csp =~ "base-uri 'self'"

    {400, headers, _} =
      assert_error_sent(400, fn ->
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/lti/launch", "{invalid")
      end)

    assert {"cache-control", "private, no-store"} in headers
    assert {"content-security-policy", "base-uri 'self'"} in headers
  end

  test "unauthorized media responses do not inherit the successful media exception", %{conn: conn} do
    response =
      conn
      |> put_req_header("accept", "application/json")
      |> get("/api/v1/media/proxy?url=https://example.edu/image.gif")

    assert response(response, 401) == ""
    assert get_resp_header(response, "cache-control") == ["private, no-store"]
  end
end

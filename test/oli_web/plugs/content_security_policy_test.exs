defmodule OliWeb.Plugs.ContentSecurityPolicyTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias OliWeb.Plugs.{AllowIframeCSP, ContentSecurityPolicy}

  test "missing HTML policies get only base-uri, including error responses" do
    for status <- [200, 400, 500] do
      conn =
        conn(:get, "/lti/register_form")
        |> ContentSecurityPolicy.call(report_only: nil)
        |> put_resp_content_type("text/html")
        |> send_resp(status, "<html></html>")

      assert get_resp_header(conn, "content-security-policy") == ["base-uri 'self'"]
      assert get_resp_header(conn, "content-security-policy-report-only") == []
      assert get_resp_header(conn, "x-frame-options") == []
    end
  end

  test "route-specific framing policies survive and report-only is independent" do
    candidate = "default-src 'self'; object-src 'none'"

    for embedded <- [false, true] do
      conn =
        conn(:get, "/")
        |> ContentSecurityPolicy.call(report_only: candidate)
        |> Phoenix.Controller.put_secure_browser_headers()
        |> put_resp_content_type("text/html")

      conn =
        case embedded do
          true -> AllowIframeCSP.call(conn, AllowIframeCSP.init([]))
          false -> conn
        end

      existing = get_resp_header(conn, "content-security-policy")
      conn = send_resp(conn, 200, "<html></html>")

      assert get_resp_header(conn, "content-security-policy") == existing
      assert get_resp_header(conn, "content-security-policy-report-only") == [candidate]
      assert String.contains?(hd(existing), "*") == embedded
    end
  end

  test "JSON, media and bodyless responses do not receive document CSP" do
    for type <- ["application/json", "image/gif", nil] do
      conn = conn(:get, "/") |> ContentSecurityPolicy.call(report_only: "default-src 'self'")

      conn =
        case type do
          nil -> conn
          type -> put_resp_content_type(conn, type)
        end

      conn = send_resp(conn, 200, "")
      assert get_resp_header(conn, "content-security-policy") == []
      assert get_resp_header(conn, "content-security-policy-report-only") == []
    end
  end
end

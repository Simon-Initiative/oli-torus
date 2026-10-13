defmodule OliWeb.Plugs.ContentSecurityPolicy do
  @moduledoc """
  Supplies a minimal CSP for HTML that does not already have a route policy.

  Framing and resource restrictions belong to the route: LTI relies on cross-site
  embedding and form posts. Optional report-only measurement never changes the
  enforced policy. No reports are collected or transmitted by default.
  """
  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    report_only =
      Keyword.get_lazy(opts, :report_only, fn ->
        Application.get_env(:oli, :csp_report_only)
      end)

    register_before_send(conn, fn conn ->
      case get_resp_header(conn, "content-type") do
        ["text/html" <> _] ->
          conn
          |> put_fallback_policy()
          |> put_report_only(report_only)

        _ ->
          conn
      end
    end)
  end

  defp put_fallback_policy(conn) do
    case get_resp_header(conn, "content-security-policy") do
      [] -> put_resp_header(conn, "content-security-policy", "base-uri 'self'")
      _ -> conn
    end
  end

  defp put_report_only(conn, policy) when is_binary(policy) and policy != "" do
    put_resp_header(conn, "content-security-policy-report-only", policy)
  end

  defp put_report_only(conn, _policy), do: conn
end

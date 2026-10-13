defmodule OliWeb.Components.AnalyticsTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Analytics

  setup do
    original = Application.fetch_env(:oli, :analytics)

    on_exit(fn ->
      case original do
        :error -> Application.delete_env(:oli, :analytics)
        {:ok, value} -> Application.put_env(:oli, :analytics, value)
      end
    end)

    conn = Phoenix.ConnTest.build_conn(:get, "/users/reset_password/private-token?secret=private")
    {:ok, conn: Plug.Conn.put_private(conn, :phoenix_endpoint, OliWeb.Endpoint)}
  end

  test "disabled renders no script", %{conn: conn} do
    Application.put_env(:oli, :analytics, gtm_container_id: nil)
    # A disabled installation does not need a resolvable request path.
    conn = %{conn | request_path: nil}
    assert render_component(&Analytics.gtm_head/1, conn: conn) |> String.trim() == ""
  end

  test "configured renders one writer with sanitized, escaped configuration and no fallback", %{
    conn: conn
  } do
    Application.put_env(:oli, :analytics,
      gtm_container_id: "GTM-QA123",
      gtm_auth: "auth",
      gtm_preview: "env-2"
    )

    html = render_component(&Analytics.gtm_head/1, conn: conn)
    document = Floki.parse_document!(html)
    assert length(Floki.find(document, "script")) == 1
    assert Floki.attribute(document, "script", "src") == ["/js/analytics.js"]
    [config] = Floki.attribute(document, "script", "data-config")

    assert %{
             "container_id" => "GTM-QA123",
             "auth" => "auth",
             "preview" => "env-2",
             "context" => %{"page_path" => "/users/reset_password/:token"}
           } = Jason.decode!(config)

    refute html =~ "private"
    refute html =~ "noscript"
    refute html =~ "iframe"
  end

  test "card-entry route stays excluded even with a covered layout", %{conn: conn} do
    Application.put_env(:oli, :analytics, gtm_container_id: "GTM-QA123")
    conn = %{conn | request_path: "/sections/private/payment/new"}
    assert render_component(&Analytics.gtm_head/1, conn: conn) |> String.trim() == ""
  end

  test "root layouts put installation first and excluded layouts omit it" do
    for layout <- ~w(authoring delivery chromeless) do
      html = File.read!("lib/oli_web/templates/layout/#{layout}.html.heex")
      assert html =~ ~r/<head>\s*<OliWeb.Components.Analytics.gtm_head conn=\{@conn\} \/>/
      assert length(Regex.scan(~r/Analytics.gtm_head/, html)) == 1
    end

    for layout <- ~w(lti lti_redirect delivery_from_payment error) do
      refute File.read!("lib/oli_web/templates/layout/#{layout}.html.heex") =~
               "Analytics.gtm_head"
    end
  end
end

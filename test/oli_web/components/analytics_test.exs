defmodule OliWeb.Components.AnalyticsTest do
  use OliWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Analytics

  setup do
    original = Application.fetch_env(:oli, :analytics)
    privacy = Application.fetch_env(:oli, :privacy_policies)
    Application.put_env(:oli, :privacy_policies, url: "https://example.org/privacy")

    on_exit(fn ->
      case privacy do
        :error -> Application.delete_env(:oli, :privacy_policies)
        {:ok, value} -> Application.put_env(:oli, :privacy_policies, value)
      end

      case original do
        :error -> Application.delete_env(:oli, :analytics)
        {:ok, value} -> Application.put_env(:oli, :analytics, value)
      end
    end)

    conn = Phoenix.ConnTest.build_conn(:get, "/users/reset_password/private-token?secret=private")
    {:ok, conn: Plug.Conn.put_private(conn, :phoenix_endpoint, OliWeb.Endpoint)}
  end

  test "disabled analytics still bootstraps denied cookie preferences", %{conn: conn} do
    Application.put_env(:oli, :analytics, gtm_container_id: nil)
    # A disabled installation does not need a resolvable request path.
    conn = %{conn | request_path: nil}
    html = render_component(&Analytics.gtm_head/1, conn: conn)
    assert html =~ "torus-cookie-consent"
    refute html =~ "analytics.js"
  end

  test "configured renders one writer with sanitized, escaped configuration and no fallback", %{
    conn: conn
  } do
    Application.put_env(:oli, :analytics,
      gtm_container_id: "GTM-QA123",
      measurement_ids: ["G-QA123"],
      gtm_auth: "auth",
      gtm_preview: "env-2"
    )

    html = render_component(&Analytics.gtm_head/1, conn: conn)
    document = Floki.parse_document!(html)
    assert length(Floki.find(document, "script[src]")) == 1
    assert Floki.attribute(document, "#torus-analytics", "src") == ["/js/analytics.js"]
    [config] = Floki.attribute(document, "#torus-analytics", "data-config")

    assert %{
             "container_id" => "GTM-QA123",
             "auth" => "auth",
             "preview" => "env-2",
             "measurement_ids" => ["G-QA123"],
             "context" => %{"page_path" => "/users/reset_password/:token"}
           } = Jason.decode!(config)

    refute html =~ "private"
    refute html =~ "noscript"
    refute html =~ "iframe"
  end

  test "card-entry route stays excluded even with a covered layout", %{conn: conn} do
    Application.put_env(:oli, :analytics,
      gtm_container_id: "GTM-QA123",
      measurement_ids: ["G-QA123"]
    )

    conn = %{conn | request_path: "/sections/private/payment/new"}
    refute render_component(&Analytics.gtm_head/1, conn: conn) =~ "analytics.js"
  end

  test "embeds current cookie decisions and rejects legacy opt-in", %{conn: conn} do
    Application.put_env(:oli, :analytics,
      gtm_container_id: "GTM-QA123",
      measurement_ids: ["G-QA123"]
    )

    for {decision, expected} <- [
          {%{"version" => 2, "analytics" => true}, true},
          {%{"version" => 2, "analytics" => false}, false},
          {%{"analytics" => true}, false},
          {%{"version" => 1, "analytics" => true}, false}
        ] do
      conn = %{conn | cookies: %{"_cky_opt_choices" => Jason.encode!(decision)}}
      document = render_component(&Analytics.gtm_head/1, conn: conn) |> Floki.parse_document!()
      [config] = Floki.attribute(document, "#torus-analytics", "data-config")
      assert Jason.decode!(config)["consent"]["analytics"] == expected
    end
  end

  test "signed-in database decision is embedded before analytics loads", %{conn: conn} do
    Application.put_env(:oli, :analytics,
      gtm_container_id: "GTM-QA123",
      measurement_ids: ["G-QA123"]
    )

    user = Oli.AccountsFixtures.user_fixture()

    Oli.Consent.insert_cookie(
      "_cky_opt_choices",
      Jason.encode!(%{version: 2, analytics: true}),
      DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.truncate(:second),
      user.id
    )

    html =
      render_component(&Analytics.gtm_head/1, conn: Plug.Conn.assign(conn, :current_user, user))

    document = Floki.parse_document!(html)
    [config] = Floki.attribute(document, "#torus-analytics", "data-config")
    assert Jason.decode!(config)["consent"]["analytics"] == true
    assert Jason.decode!(config)["signed_in"] == true
    [bootstrap] = Floki.attribute(document, "#torus-cookie-consent", "data-config")
    assert Jason.decode!(bootstrap)["signedIn"] == true
    assert String.split(html, "analytics.js") |> hd() =~ "torus-cookie-consent"

    pending = %{
      version: 2,
      preferences: %{
        necessary: true,
        functionality: true,
        analytics: false,
        targeting: false,
        version: 2
      },
      decision: %{group: String.duplicate("a", 32), sequence: 2},
      expiresIso: DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.to_iso8601()
    }

    pending_conn = %{
      conn
      | cookies: %{"_cky_pending_consent" => pending |> Jason.encode!() |> URI.encode_www_form()}
    }

    document =
      render_component(&Analytics.gtm_head/1,
        conn: Plug.Conn.assign(pending_conn, :current_user, user)
      )
      |> Floki.parse_document!()

    [config] = Floki.attribute(document, "#torus-analytics", "data-config")
    assert Jason.decode!(config)["consent"]["analytics"] == false
    assert Oli.Consent.preferences_for_user(user.id)["analytics"] == true
  end

  test "blank privacy URL disables measurement availability", %{conn: conn} do
    Application.put_env(:oli, :analytics,
      gtm_container_id: "GTM-QA123",
      measurement_ids: ["G-QA123"]
    )

    Application.put_env(:oli, :privacy_policies, url: " ")
    document = render_component(&Analytics.gtm_head/1, conn: conn) |> Floki.parse_document!()
    [config] = Floki.attribute(document, "#torus-analytics", "data-config")
    assert Jason.decode!(config)["consent_available"] == false
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

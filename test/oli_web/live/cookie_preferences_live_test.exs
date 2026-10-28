defmodule OliWeb.CookiePreferencesLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.Consent

  setup :guest_conn

  test "renders accessible preferences with analytics off and no targeting controls", %{
    conn: conn
  } do
    {:ok, lv, html} = live(conn, ~p"/cookie-preferences")

    assert html =~ "Cookie Preferences"
    assert html =~ "Privacy Notice"
    assert has_element?(lv, "input[aria-label='Strictly Necessary Cookies'][checked][disabled]")
    assert has_element?(lv, "input[aria-label='Functionality Cookies'][checked]")
    refute has_element?(lv, "input[aria-label='Analytics Cookies'][checked]")
    refute html =~ "Targeting Cookies"
  end

  test "anonymous mobile page saves without the workspace layout", _context do
    {:ok, lv, _html} =
      live(Phoenix.ConnTest.build_conn(), ~p"/cookie-preferences?#{%{device: "mobile"}}")

    html = lv |> element("#save-cookie-preferences") |> render_click()
    assert html =~ "Cookie preferences have been updated."

    assert_push_event(lv, "save-cookie-preferences", %{
      preferences: %{
        necessary: true,
        functionality: true,
        analytics: false,
        targeting: false,
        version: 2
      },
      is_authenticated: false
    })
  end

  test "authenticated users keep the workspace layout on mobile", %{conn: conn} do
    user = user_fixture()

    {:ok, _lv, html} =
      conn |> log_in_user(user) |> live(~p"/cookie-preferences?#{%{device: "mobile"}}")

    assert html =~ ~s(id="header")
  end

  test "back and cancel navigate to the supplied return path", %{conn: conn} do
    for label <- ["Back", "Cancel"] do
      {:ok, lv, _html} = live(conn, ~p"/cookie-preferences?#{%{return_to: "/profile"}}")
      lv |> element("button[phx-click='go_back']", label) |> render_click()
      assert_redirected(lv, "/profile")
    end

    {:ok, lv, _html} = live(conn, ~p"/cookie-preferences")
    lv |> element("button[phx-click='go_back']", "Back") |> render_click()
    assert_redirected(lv, "/")
  end

  test "current DB preferences override browser preferences", %{conn: conn} do
    user = user_fixture()
    save_choices(user, %{functionality: false, analytics: true, targeting: true, version: 2})
    {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/cookie-preferences")

    refute has_element?(lv, "input[aria-label='Functionality Cookies'][checked]")
    assert has_element?(lv, "input[aria-label='Analytics Cookies'][checked]")

    render_hook(lv, "browser_cookie_preferences", %{
      "preferences" => %{"functionality" => true, "analytics" => false, "version" => 2}
    })

    refute has_element?(lv, "input[aria-label='Functionality Cookies'][checked]")
    assert has_element?(lv, "input[aria-label='Analytics Cookies'][checked]")
  end

  test "old DB consent preserves functionality but requires analytics opt-in", %{conn: conn} do
    user = user_fixture()
    save_choices(user, %{functionality: false, analytics: true, targeting: true})
    {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/cookie-preferences")

    refute has_element?(lv, "input[aria-label='Functionality Cookies'][checked]")
    refute has_element?(lv, "input[aria-label='Analytics Cookies'][checked]")
  end

  test "pending iframe withdrawal can display denial before database persistence", %{conn: conn} do
    user = user_fixture()
    save_choices(user, %{functionality: false, analytics: true, version: 2})
    {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/cookie-preferences")

    render_hook(lv, "browser_cookie_preferences", %{
      "preferences" => %{"functionality" => false, "analytics" => false, "version" => 2},
      "pending_withdrawal" => true
    })

    refute has_element?(lv, "input[aria-label='Analytics Cookies'][checked]")
    assert Consent.preferences_for_user(user.id)["analytics"] == true

    render_hook(lv, "browser_cookie_preferences", %{
      "preferences" => %{"functionality" => true, "analytics" => true, "version" => 2},
      "pending_withdrawal" => true
    })

    refute has_element?(lv, "input[aria-label='Analytics Cookies'][checked]")
  end

  test "withdrawal acknowledged before the browser hook refreshes a stale mounted grant", %{
    conn: conn
  } do
    user = user_fixture()
    save_choices(user, %{functionality: true, analytics: true, version: 2})
    {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/cookie-preferences")
    assert has_element?(lv, "input[aria-label='Analytics Cookies'][checked]")

    save_choices(user, %{functionality: true, analytics: false, version: 2})

    render_hook(lv, "browser_cookie_preferences", %{
      "preferences" => %{"functionality" => true, "analytics" => false, "version" => 2}
    })

    refute has_element?(lv, "input[aria-label='Analytics Cookies'][checked]")
  end

  test "expired DB consent does not activate analytics", %{conn: conn} do
    user = user_fixture()

    save_choices(
      user,
      %{functionality: false, analytics: true, version: 2},
      DateTime.utc_now() |> DateTime.add(-1, :day)
    )

    {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/cookie-preferences")
    refute has_element?(lv, "input[aria-label='Analytics Cookies'][checked]")
  end

  test "browser preferences require a current version and boolean analytics", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/cookie-preferences")

    for preferences <- [
          %{"functionality" => false, "analytics" => true},
          %{"functionality" => false, "analytics" => true, "version" => 1},
          %{"functionality" => false, "analytics" => "true", "version" => 2}
        ] do
      render_hook(lv, "browser_cookie_preferences", %{"preferences" => preferences})
      refute has_element?(lv, "input[aria-label='Functionality Cookies'][checked]")
      refute has_element?(lv, "input[aria-label='Analytics Cookies'][checked]")
    end

    render_hook(lv, "browser_cookie_preferences", %{
      "preferences" => %{"functionality" => false, "analytics" => true, "version" => 2}
    })

    assert has_element?(lv, "input[aria-label='Analytics Cookies'][checked]")
  end

  test "invalid stored JSON safely falls back to analytics off", %{conn: conn} do
    for value <- ["{invalid", "undefined", "", "null", "[]", "42", "true"] do
      user = user_fixture()
      save_choices(user, value)
      {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/cookie-preferences")
      assert has_element?(lv, "input[aria-label='Functionality Cookies'][checked]")
      refute has_element?(lv, "input[aria-label='Analytics Cookies'][checked]")
    end
  end

  test "analytics description and table list GA4 cookies on this deployment", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/cookie-preferences")
    lv |> element("button", "Analytics Cookies") |> render_click()
    html = render(lv)
    assert html =~ "Google Analytics"
    assert html =~ "pages visited by type"
    assert html =~ "features used"
    assert html =~ "videos started or completed, in aggregate"

    html =
      lv
      |> element("button[phx-value-section='analytics_cookies']", "View Cookies")
      |> render_click()

    assert html =~ OliWeb.Endpoint.host()
    assert html =~ "_ga, _ga_&lt;measurement-id&gt;"
    refute html =~ "_gid"
    refute html =~ "_utma"
    refute html =~ "nmstat"
    refute html =~ "canvas.oli.cmu.edu"
    assert html =~ "overflow-x-auto"
  end

  test "expanded section state survives preference changes", %{
    conn: conn
  } do
    {:ok, lv, _html} = live(conn, ~p"/cookie-preferences")
    lv |> element("button", "Functionality Cookies") |> render_click()

    assert has_element?(
             lv,
             "button[aria-controls='functional_cookies-panel'][aria-expanded='true']"
           )

    assert render(lv) =~ "more personalized experience"
    lv |> element("input[aria-label='Analytics Cookies']") |> render_click()
    assert render(lv) =~ "more personalized experience"
    lv |> element("button", "Functionality Cookies") |> render_click()
    refute render(lv) =~ "more personalized experience"
  end

  test "forged targeting and unknown section events cannot change consent or crash", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/cookie-preferences")

    for section <- ["targeting_cookies", "unknown_section", "analytics_active"] do
      render_hook(lv, "toggle_section", %{"section" => section})
      render_hook(lv, "toggle_cookie_table", %{"section" => section})
      render_hook(lv, "toggle_preference", %{"preference" => section, "checked" => "true"})
    end

    lv |> element("#save-cookie-preferences") |> render_click()

    assert_push_event(lv, "save-cookie-preferences", %{
      preferences: %{analytics: false, targeting: false, version: 2}
    })
  end

  test "saving uses current version and the selected analytics preference", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/cookie-preferences")
    lv |> element("input[aria-label='Functionality Cookies']") |> render_click()
    lv |> element("input[aria-label='Analytics Cookies']") |> render_click()
    html = lv |> element("#save-cookie-preferences") |> render_click()

    assert html =~ "Cookie preferences have been updated."

    assert_push_event(lv, "save-cookie-preferences", %{
      preferences: %{
        necessary: true,
        functionality: false,
        analytics: true,
        targeting: false,
        version: 2
      }
    })
  end

  defp save_choices(
         user,
         preferences,
         expiration \\ DateTime.utc_now() |> DateTime.add(365, :day)
       ) do
    value =
      case preferences do
        value when is_binary(value) -> value
        preferences -> Jason.encode!(preferences)
      end

    Consent.insert_cookie(
      "_cky_opt_choices",
      value,
      DateTime.truncate(expiration, :second),
      user.id
    )
  end
end

defmodule Oli.ConsentTest do
  use Oli.DataCase, async: true

  import Oli.Utils.Seeder.AccountsFixtures
  import Plug.Conn
  import Plug.Test

  alias Oli.Consent
  alias Oli.Repo

  describe "preferences/1" do
    test "defaults analytics and ads to denied without a decision" do
      preferences = Consent.preferences(conn(:get, "/"))
      assert preferences["analytics"] == false
      assert preferences["targeting"] == false
      assert preferences["version"] == nil
      assert Consent.analytics_consent(conn(:get, "/")) == "denied"
    end

    test "legacy consent preserves functionality but requires re-consent" do
      conn = browser_conn(%{"functionality" => false, "analytics" => true})
      preferences = Consent.preferences(conn)
      refute preferences["functionality"]
      refute preferences["analytics"]
      assert preferences["version"] == nil
    end

    test "only boolean current-version analytics is accepted" do
      for value <- [true, false] do
        conn = browser_conn(%{"version" => Consent.version(), "analytics" => value})
        assert Consent.preferences(conn)["analytics"] == value
        assert Consent.preferences(conn)["version"] == Consent.version()
      end

      for value <- [nil, "true", 1, %{}] do
        conn = browser_conn(%{"version" => Consent.version(), "analytics" => value})
        refute Consent.preferences(conn)["analytics"]
        assert Consent.preferences(conn)["version"] == nil
      end
    end

    test "accepts URI encoded cookies and rejects malformed JSON safely" do
      cookie = URI.encode_www_form(~s({"version":2,"analytics":true}))
      conn = conn(:get, "/") |> put_req_cookie("_cky_opt_choices", cookie) |> fetch_cookies()
      assert Consent.analytics_consent(conn) == "granted"

      for cookie <- ["broken", "[]", "null", "1", "true", "%ZZ"] do
        conn = conn(:get, "/") |> put_req_cookie("_cky_opt_choices", cookie) |> fetch_cookies()
        assert Consent.analytics_consent(conn) == "denied"
      end
    end

    test "signed-in stored choice wins over conflicting browser consent" do
      user = user_fixture()
      store(user.id, %{"version" => 2, "analytics" => false})
      conn = browser_conn(%{"version" => 2, "analytics" => true}) |> assign(:current_user, user)
      assert Consent.analytics_consent(conn) == "denied"

      store(user.id, %{"version" => 2, "analytics" => true})
      assert Consent.analytics_consent(conn) == "granted"
      assert Consent.analytics_consent(assign(conn(:get, "/"), :current_user, user)) == "granted"
    end

    test "expired and legacy DB choices never inherit consent from the browser" do
      user = user_fixture()

      browser =
        browser_conn(%{"version" => 2, "analytics" => true}) |> assign(:current_user, user)

      store(user.id, %{"analytics" => true, "functionality" => false})
      assert Consent.analytics_consent(browser) == "denied"
      refute Consent.preferences(browser)["functionality"]

      store(user.id, %{"version" => 2, "analytics" => true}, DateTime.add(DateTime.utc_now(), -1))
      assert Consent.analytics_consent(browser) == "denied"
      assert Consent.preferences(browser)["version"] == nil
    end
  end

  describe "sync_preferences/2" do
    test "current browser decision replaces a legacy or expired DB choice" do
      user = user_fixture()
      store(user.id, %{"analytics" => true})
      :ok = Consent.sync_preferences(user.id, ~s({"version":2,"analytics":false}))
      assert Consent.preferences_for_user(user.id)["version"] == 2
      refute Consent.preferences_for_user(user.id)["analytics"]

      store(
        user.id,
        %{"version" => 2, "analytics" => false},
        DateTime.add(DateTime.utc_now(), -1)
      )

      :ok = Consent.sync_preferences(user.id, ~s({"version":2,"analytics":true}))
      assert Consent.preferences_for_user(user.id)["analytics"]
    end

    test "stored current decision wins over conflicting current browser consent" do
      user = user_fixture()
      store(user.id, %{"version" => 2, "analytics" => false})
      :ok = Consent.sync_preferences(user.id, ~s({"version":2,"analytics":true}))
      refute Consent.preferences_for_user(user.id)["analytics"]
    end

    test "legacy and malformed browser cookies cannot gain current consent" do
      user = user_fixture()
      :ok = Consent.sync_preferences(user.id, ~s({"analytics":true,"functionality":false}))
      preferences = Consent.preferences_for_user(user.id)
      refute preferences["analytics"]
      refute preferences["functionality"]
      assert preferences["version"] == nil

      :ok = Consent.sync_preferences(user.id, "invalid")
      assert length(Consent.retrieve_cookies(user.id)) == 1
    end
  end

  describe "persist_preferences/3" do
    test "metadata-free writes remain compatible before sequencing metadata exists" do
      user = user_fixture()
      expiration = DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.truncate(:second)

      for analytics <- [true, false] do
        cookies = [
          %{
            name: "_cky_opt_choices",
            value: Jason.encode!(%{version: 2, analytics: analytics}),
            expiration: expiration
          }
        ]

        assert Consent.persist_preferences(cookies, user.id) == {:ok, :persisted}
        assert Consent.preferences_for_user(user.id)["analytics"] == analytics
      end
    end

    test "invalid stored ordering metadata does not block a metadata-free decision" do
      user = user_fixture()
      expiration = DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.truncate(:second)

      cookies = [
        %{
          name: "_cky_opt_choices",
          value: Jason.encode!(%{version: 2, analytics: false}),
          expiration: expiration
        }
      ]

      for {group, sequence} <- [
            {String.duplicate("a", 32), 0},
            {String.duplicate("a", 32), 9_007_199_254_740_992},
            {String.duplicate("a", 32), "1"},
            {String.duplicate("A", 32), 1},
            {String.duplicate("a", 31), 1},
            {nil, 1}
          ] do
        store(user.id, %{
          "version" => 2,
          "analytics" => true,
          "_decision_group" => group,
          "_decision_sequence" => sequence
        })

        assert Consent.persist_preferences(cookies, user.id) == {:ok, :persisted}
        refute Consent.preferences_for_user(user.id)["analytics"]
      end
    end
  end

  test "upserts refresh the consent audit timestamp" do
    user = user_fixture()
    cookie = store(user.id, %{"version" => 2, "analytics" => false})
    old = DateTime.utc_now() |> DateTime.add(-60) |> DateTime.truncate(:second)

    Repo.update_all(from(c in Oli.Consent.CookiesConsent, where: c.id == ^cookie.id),
      set: [updated_at: old]
    )

    store(user.id, %{"version" => 2, "analytics" => true})
    assert DateTime.compare(Repo.reload!(cookie).updated_at, old) == :gt
  end

  defp browser_conn(preferences) do
    conn(:get, "/")
    |> put_req_cookie("_cky_opt_choices", Jason.encode!(preferences))
    |> fetch_cookies()
  end

  defp store(user_id, preferences, expiration \\ DateTime.add(DateTime.utc_now(), 365, :day)) do
    Consent.insert_cookie(
      "_cky_opt_choices",
      Jason.encode!(preferences),
      DateTime.truncate(expiration, :second),
      user_id
    )
  end
end

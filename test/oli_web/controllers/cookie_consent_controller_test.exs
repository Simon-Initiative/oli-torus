defmodule OliWeb.CookieConsentControllerTest do
  use OliWeb.ConnCase, async: true

  import Ecto.Query

  alias Oli.Consent
  alias Oli.Consent.CookiesConsent
  alias Oli.Repo
  alias OliWeb.UserAuth

  describe "consent storage" do
    test "anonymous choices remain browser-only", %{conn: conn} do
      decision = %{group: String.duplicate("a", 32), sequence: 1}

      response =
        post(conn, ~p"/consent/cookie", %{cookies: [choices_cookie(true)], decision: decision})

      assert %{
               "info" => "user not found",
               "persistence" => "browser_only",
               "decision" => %{"group" => group, "sequence" => 1},
               "acknowledged" => false
             } = json_response(response, 200)

      assert group == decision.group
      assert Repo.aggregate(CookiesConsent, :count) == 0
    end

    test "persists and retrieves a current decision for the signed-in user", %{conn: conn} do
      user = user_fixture()
      conn = conn |> init_test_session(%{}) |> log_in_user(user)
      response = post(conn, ~p"/consent/cookie", %{cookies: [choices_cookie(true)]})
      assert json_response(response, 200)["info"] == "cookies persisted"

      response = get(conn, ~p"/consent/cookie")
      assert [%{"name" => "_cky_opt_choices", "value" => value}] = json_response(response, 200)
      preferences = Jason.decode!(value)
      assert preferences["analytics"]
      assert preferences["version"] == 2
      assert preferences["necessary"]
      refute preferences["targeting"]
    end

    test "normalizes advertising consent and never persists malformed requests", %{conn: conn} do
      user = user_fixture()
      conn = conn |> init_test_session(%{}) |> log_in_user(user)
      cookie = choices_cookie(true)
      cookie = %{cookie | "value" => ~s({"version":2,"analytics":true,"targeting":true})}
      assert json_response(post(conn, ~p"/consent/cookie", %{cookies: [cookie]}), 200)
      refute Consent.preferences_for_user(user.id)["targeting"]

      for cookies <- [
            nil,
            [],
            [%{}],
            [Map.put(cookie, "name", "arbitrary")],
            [Map.put(cookie, "value", "invalid")],
            [Map.put(cookie, "value", ~s({"analytics":true}))],
            [Map.put(cookie, "expiresIso", "invalid")],
            [Map.put(cookie, "expiresIso", "2000-01-01T00:00:00Z")]
          ] do
        assert json_response(post(conn, ~p"/consent/cookie", %{cookies: cookies}), 422)["result"] ==
                 "error"
      end

      assert length(Consent.retrieve_cookies(user.id)) == 1
    end

    test "rejects a mixed batch before writing any cookies", %{conn: conn} do
      user = user_fixture()
      conn = conn |> init_test_session(%{}) |> log_in_user(user)
      cookies = [choices_cookie(true), %{"name" => "invalid"}]
      assert json_response(post(conn, ~p"/consent/cookie", %{cookies: cookies}), 422)
      assert Consent.retrieve_cookies(user.id) == []
    end

    test "a late or repeated older save cannot overwrite the latest decision", %{conn: conn} do
      user = user_fixture()
      conn = conn |> init_test_session(%{}) |> log_in_user(user)
      group = String.duplicate("a", 32)

      rejected = %{
        cookies: [choices_cookie(false)],
        decision: %{group: group, sequence: 2}
      }

      assert json_response(post(conn, ~p"/consent/cookie", rejected), 200)

      for sequence <- [1, 2] do
        accepted = %{
          cookies: [choices_cookie(true)],
          decision: %{group: group, sequence: sequence}
        }

        assert json_response(post(conn, ~p"/consent/cookie", accepted), 200)
        refute Consent.preferences_for_user(user.id)["analytics"]
      end

      [stored] = Consent.retrieve_cookies(user.id)
      assert Jason.decode!(stored.value)["_decision_group"] == group
      assert Jason.decode!(stored.value)["_decision_sequence"] == 2
      refute Map.has_key?(Consent.preferences_for_user(user.id), "_decision_group")

      assert [%{"value" => value}] = json_response(get(conn, ~p"/consent/cookie"), 200)
      refute Map.has_key?(Jason.decode!(value), "_decision_group")
      refute Map.has_key?(Jason.decode!(value), "_decision_sequence")
    end

    test "acknowledges an exact save and its retry without acknowledging a stale or different choice",
         %{
           conn: conn
         } do
      user = user_fixture()
      conn = conn |> init_test_session(%{}) |> log_in_user(user)
      group = String.duplicate("a", 32)

      rejected = %{
        cookies: [choices_cookie(false)],
        decision: %{group: group, sequence: 2}
      }

      assert %{
               "persistence" => "persisted",
               "decision" => %{"group" => ^group, "sequence" => 2},
               "acknowledged" => true
             } = json_response(post(conn, ~p"/consent/cookie", rejected), 200)

      assert %{
               "persistence" => "superseded",
               "decision" => %{"group" => ^group, "sequence" => 2},
               "acknowledged" => true
             } = json_response(post(conn, ~p"/consent/cookie", rejected), 200)

      for {sequence, analytics} <- [{1, false}, {2, true}] do
        stale = %{
          cookies: [choices_cookie(analytics)],
          decision: %{group: group, sequence: sequence}
        }

        assert %{"persistence" => "superseded", "acknowledged" => false} =
                 json_response(post(conn, ~p"/consent/cookie", stale), 200)
      end

      assert %{"persistence" => "persisted", "acknowledged" => true} =
               json_response(
                 post(conn, ~p"/consent/cookie", %{
                   cookies: [choices_cookie(true)],
                   decision: %{group: group, sequence: 3}
                 }),
                 200
               )

      assert %{"persistence" => "superseded", "acknowledged" => false} =
               json_response(post(conn, ~p"/consent/cookie", rejected), 200)
    end

    test "newer saves and a new page group may change the stored choice", %{conn: conn} do
      user = user_fixture()
      conn = conn |> init_test_session(%{}) |> log_in_user(user)

      for {group, sequence, analytics} <- [
            {String.duplicate("a", 32), 2, false},
            {String.duplicate("a", 32), 3, true},
            {String.duplicate("b", 32), 1, false}
          ] do
        params = %{
          cookies: [choices_cookie(analytics)],
          decision: %{group: group, sequence: sequence}
        }

        assert json_response(post(conn, ~p"/consent/cookie", params), 200)
        assert Consent.preferences_for_user(user.id)["analytics"] == analytics
      end
    end

    test "metadata-free writes cannot replace a sequenced rejection or alter its batch", %{
      conn: conn
    } do
      user = user_fixture()
      conn = conn |> init_test_session(%{}) |> log_in_user(user)
      rejected = choices_cookie(false)
      opted_in = %{rejected | "name" => "_cky_opt_in", "value" => "true"}

      assert json_response(
               post(conn, ~p"/consent/cookie", %{
                 cookies: [rejected, opted_in],
                 decision: %{group: String.duplicate("a", 32), sequence: 2}
               }),
               200
             )

      old_timestamp = DateTime.utc_now() |> DateTime.add(-60) |> DateTime.truncate(:second)

      Repo.update_all(from(cookie in CookiesConsent, where: cookie.user_id == ^user.id),
        set: [updated_at: old_timestamp]
      )

      original_cookies = Map.new(Consent.retrieve_cookies(user.id), &{&1.name, &1})
      expiry = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.to_iso8601()
      accepted = %{choices_cookie(true) | "expiresIso" => expiry}
      opted_out = %{opted_in | "value" => "false", "expiresIso" => expiry}

      assert json_response(
               post(conn, ~p"/consent/cookie", %{cookies: [accepted, opted_out]}),
               200
             )

      assert Map.new(Consent.retrieve_cookies(user.id), &{&1.name, &1}) == original_cookies
      refute Consent.preferences_for_user(user.id)["analytics"]
    end

    test "malformed supplied decision metadata is rejected before writing", %{conn: conn} do
      user = user_fixture()
      conn = conn |> init_test_session(%{}) |> log_in_user(user)
      group = String.duplicate("a", 32)

      for decision <- [
            nil,
            %{},
            %{group: group, sequence: 0},
            %{group: group, sequence: -1},
            %{group: group, sequence: 1.5},
            %{group: group, sequence: "1"},
            %{group: group, sequence: 9_007_199_254_740_992},
            %{group: String.duplicate("A", 32), sequence: 1},
            %{group: String.duplicate("a", 31), sequence: 1},
            %{group: String.duplicate("a", 33), sequence: 1},
            %{group: "<script>", sequence: 1}
          ] do
        params = %{cookies: [choices_cookie(true)], decision: decision}
        assert json_response(post(conn, ~p"/consent/cookie", params), 422)
      end

      assert Consent.retrieve_cookies(user.id) == []
    end

    test "does not retrieve expired decisions or another user's cookies", %{conn: conn} do
      user = user_fixture()
      other = user_fixture()
      store(user.id, ~s({"version":2,"analytics":true}), -1)
      store(other.id, ~s({"version":2,"analytics":true}))
      conn = conn |> init_test_session(%{}) |> log_in_user(user)
      assert json_response(get(conn, ~p"/consent/cookie"), 200) == []
    end
  end

  describe "login synchronization" do
    test "copies a current browser decision when DB is empty", %{conn: conn} do
      user = user_fixture()
      login_with_cookie(conn, user, ~s({"version":2,"analytics":true}))
      assert Consent.preferences_for_user(user.id)["analytics"]
    end

    test "upgrades legacy decisions and keeps current DB decisions", %{conn: conn} do
      user = user_fixture()
      store(user.id, ~s({"analytics":true,"functionality":false}))
      login_with_cookie(conn, user, ~s({"version":2,"analytics":false}))
      assert Consent.preferences_for_user(user.id)["version"] == 2
      refute Consent.preferences_for_user(user.id)["analytics"]

      login_with_cookie(build_conn(), user, ~s({"version":2,"analytics":true}))
      refute Consent.preferences_for_user(user.id)["analytics"]
      assert length(Consent.retrieve_cookies(user.id)) == 1
    end

    test "ignores malformed browser cookies", %{conn: conn} do
      user = user_fixture()
      login_with_cookie(conn, user, "invalid")
      assert Consent.retrieve_cookies(user.id) == []
    end
  end

  defp choices_cookie(analytics) do
    %{
      "name" => "_cky_opt_choices",
      "value" => Jason.encode!(%{"version" => 2, "analytics" => analytics}),
      "expiresIso" => DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.to_iso8601()
    }
  end

  defp store(user_id, value, seconds \\ 86_400) do
    Consent.insert_cookie(
      "_cky_opt_choices",
      value,
      DateTime.utc_now() |> DateTime.add(seconds) |> DateTime.truncate(:second),
      user_id
    )
  end

  defp login_with_cookie(conn, user, value) do
    conn
    |> Map.replace!(:secret_key_base, OliWeb.Endpoint.config(:secret_key_base))
    |> init_test_session(%{})
    |> put_req_cookie("_cky_opt_choices", value)
    |> fetch_cookies()
    |> UserAuth.log_in_user(user)
  end
end

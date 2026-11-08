defmodule Oli.Analytics.ConfigTest do
  use ExUnit.Case, async: true

  alias Oli.Analytics.Config

  test "absent and blank IDs disable analytics" do
    for id <- [nil, "", "   "] do
      assert Config.load_from_env!(&%{"GOOGLE_TAG_MANAGER_ID" => id}[&1]) ==
               [gtm_container_id: nil]
    end
  end

  test "container and paired environment settings are validated and trimmed" do
    env = %{
      "GOOGLE_TAG_MANAGER_ID" => " GTM-QA123 ",
      "GOOGLE_ANALYTICS_MEASUREMENT_IDS" => "G-ABC123",
      "GOOGLE_TAG_MANAGER_AUTH" => "qa_auth-123",
      "GOOGLE_TAG_MANAGER_PREVIEW" => "env-2"
    }

    assert Config.load_from_env!(&env[&1]) ==
             [
               gtm_container_id: "GTM-QA123",
               gtm_auth: "qa_auth-123",
               gtm_preview: "env-2",
               measurement_ids: ["G-ABC123"]
             ]

    for id <- ["G-123", "gtm-123", "GTM-", "GTM-ABC<script>", "GTM-ABC\nDEF"] do
      assert_raise ArgumentError, "Invalid GOOGLE_TAG_MANAGER_ID format", fn ->
        Config.load_from_env!(&%{"GOOGLE_TAG_MANAGER_ID" => id}[&1])
      end
    end

    for settings <- [
          %{"GOOGLE_TAG_MANAGER_AUTH" => "auth"},
          %{"GOOGLE_TAG_MANAGER_PREVIEW" => "env-2"},
          %{"GOOGLE_TAG_MANAGER_AUTH" => "<script>", "GOOGLE_TAG_MANAGER_PREVIEW" => "env-2"},
          %{"GOOGLE_TAG_MANAGER_AUTH" => "auth", "GOOGLE_TAG_MANAGER_PREVIEW" => "bad"}
        ] do
      env =
        Map.merge(settings, %{
          "GOOGLE_TAG_MANAGER_ID" => "GTM-QA123",
          "GOOGLE_ANALYTICS_MEASUREMENT_IDS" => "G-ABC123"
        })

      assert_raise ArgumentError, fn -> Config.load_from_env!(&env[&1]) end
    end
  end

  test "enabled GTM requires measurement IDs even without preview settings" do
    for measurement_ids <- [nil, "", "   "] do
      env = %{
        "GOOGLE_TAG_MANAGER_ID" => "GTM-QA123",
        "GOOGLE_ANALYTICS_MEASUREMENT_IDS" => measurement_ids
      }

      assert_raise ArgumentError,
                   "GOOGLE_ANALYTICS_MEASUREMENT_IDS must include at least one GA4 measurement ID when GOOGLE_TAG_MANAGER_ID is set",
                   fn -> Config.load_from_env!(&env[&1]) end
    end
  end

  test "measurement IDs are trimmed, validated individually and deduplicated" do
    env = %{
      "GOOGLE_TAG_MANAGER_ID" => "GTM-QA123",
      "GOOGLE_ANALYTICS_MEASUREMENT_IDS" => " G-ABC123, G-XYZ789 ,G-ABC123 "
    }

    assert Config.load_from_env!(&env[&1])[:measurement_ids] == ["G-ABC123", "G-XYZ789"]

    for ids <- [
          "G-",
          "g-ABC123",
          "GTM-ABC123",
          "G-ABC<script>",
          "G-ABC\nDEF",
          "G-VALID,G-invalid",
          "G-VALID,",
          ",G-VALID",
          "G-VALID,,G-OTHER"
        ] do
      env = Map.put(env, "GOOGLE_ANALYTICS_MEASUREMENT_IDS", ids)

      assert_raise ArgumentError, "Invalid GOOGLE_ANALYTICS_MEASUREMENT_IDS format", fn ->
        Config.load_from_env!(&env[&1])
      end
    end
  end

  test "measurement settings cannot enable analytics without a container" do
    env = %{"GOOGLE_ANALYTICS_MEASUREMENT_IDS" => "G-ABC123"}
    assert Config.load_from_env!(&env[&1]) == [gtm_container_id: nil]
  end
end

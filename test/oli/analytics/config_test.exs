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
      "GOOGLE_TAG_MANAGER_AUTH" => "qa_auth-123",
      "GOOGLE_TAG_MANAGER_PREVIEW" => "env-2"
    }

    assert Config.load_from_env!(&env[&1]) ==
             [gtm_container_id: "GTM-QA123", gtm_auth: "qa_auth-123", gtm_preview: "env-2"]

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
      env = Map.put(settings, "GOOGLE_TAG_MANAGER_ID", "GTM-QA123")
      assert_raise ArgumentError, fn -> Config.load_from_env!(&env[&1]) end
    end
  end
end

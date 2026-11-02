defmodule Oli.Lti.SecureLaunchTest do
  use ExUnit.Case, async: true

  alias Oli.Lti.SecureLaunch

  @custom "https://purl.imsglobal.org/spec/lti/claim/custom"
  @deployment "https://purl.imsglobal.org/spec/lti/claim/deployment_id"
  @resource "https://purl.imsglobal.org/spec/lti/claim/resource_link"
  @now 1_800_000_000
  @scope %{
    "issuer" => "https://moodle.test:8443",
    "client_id" => "client",
    "deployment_id" => "1"
  }

  defp claims do
    %{
      "iss" => @scope["issuer"],
      "aud" => "client",
      @deployment => "1",
      @resource => %{"id" => "resource"},
      @custom => %{
        "secure_delivery" => "seb",
        "secure_activity_id" => "42",
        "seb_configuration_id" => String.duplicate("a", 64),
        "secure_verified_at" => Integer.to_string(@now)
      }
    }
  end

  defp validate(claims), do: SecureLaunch.validate(claims, now: @now)

  test "secure fields are required on independently selected launches" do
    for key <- [
          "secure_delivery",
          "secure_activity_id",
          "seb_configuration_id",
          "secure_verified_at"
        ] do
      for value <- [nil, "", " ", [], %{}, 123] do
        assert {:error, _} = validate(put_in(claims(), [@custom, key], value))
      end

      assert {:error, _} = validate(update_in(claims(), [@custom], &Map.delete(&1, key)))
    end

    assert {:error, :missing_assertion} =
             validate(put_in(claims(), [@custom, "secure_delivery"], "SEB"))

    assert {:error, :missing_assertion} = validate(Map.put(claims(), @custom, []))
  end

  test "timestamp bounds allow five minutes of age and thirty seconds of clock skew" do
    for delta <- [-300, 0, 30] do
      assert {:ok, :verified} =
               validate(
                 put_in(
                   claims(),
                   [@custom, "secure_verified_at"],
                   Integer.to_string(@now + delta)
                 )
               )
    end

    assert {:error, :stale_assertion} =
             validate(
               put_in(claims(), [@custom, "secure_verified_at"], Integer.to_string(@now - 301))
             )

    assert {:error, :future_assertion} =
             validate(
               put_in(claims(), [@custom, "secure_verified_at"], Integer.to_string(@now + 31))
             )

    for value <- [
          "-1",
          "+1800000000",
          "1800000000x",
          "1800000000.0",
          "1800000000\n",
          String.duplicate("9", 100)
        ] do
      assert {:error, :malformed_assertion} =
               validate(put_in(claims(), [@custom, "secure_verified_at"], value))
    end
  end
end

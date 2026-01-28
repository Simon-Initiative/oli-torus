defmodule Oli.GenAI.RegisteredModelChangesetTest do
  use Oli.DataCase, async: true

  alias Oli.GenAI.Completions.RegisteredModel

  describe "breaker policy validations" do
    test "defaults are present on new changeset" do
      changeset =
        RegisteredModel.changeset(%RegisteredModel{}, %{
          name: "Default Model",
          provider: :open_ai,
          model: "gpt-4",
          url_template: "https://api.example.com",
          api_key: "secret",
          timeout: 8000,
          recv_timeout: 60_000
        })

      assert changeset.valid?
      assert get_field(changeset, :routing_breaker_error_rate_threshold) == 0.2
      assert get_field(changeset, :routing_breaker_429_threshold) == 0.1
      assert get_field(changeset, :routing_breaker_latency_p95_ms) == 6000
      assert get_field(changeset, :routing_open_cooldown_ms) == 30_000
      assert get_field(changeset, :routing_half_open_probe_count) == 3
    end

    test "rejects breaker thresholds outside 0..1 range" do
      changeset =
        RegisteredModel.changeset(%RegisteredModel{}, %{
          name: "Invalid Threshold Model",
          provider: :open_ai,
          model: "gpt-4",
          url_template: "https://api.example.com",
          api_key: "secret",
          timeout: 8000,
          recv_timeout: 60_000,
          routing_breaker_error_rate_threshold: 1.5,
          routing_breaker_429_threshold: -0.1
        })

      refute changeset.valid?

      assert "must be less than or equal to 1.0" in errors_on(changeset).routing_breaker_error_rate_threshold

      assert "must be greater than or equal to 0.0" in errors_on(changeset).routing_breaker_429_threshold
    end
  end
end

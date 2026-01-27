defmodule Oli.GenAI.ServiceConfigChangesetTest do
  use Oli.DataCase, async: true

  alias Oli.GenAI.Completions.ServiceConfig

  describe "routing policy validations" do
    test "defaults are present on new changeset" do
      changeset =
        ServiceConfig.changeset(%ServiceConfig{}, %{name: "Default Config", primary_model_id: 1})

      assert changeset.valid?
      assert get_field(changeset, :routing_soft_limit) == 40
      assert get_field(changeset, :routing_hard_limit) == 80
      assert get_field(changeset, :routing_stream_soft_limit) == 8
      assert get_field(changeset, :routing_stream_hard_limit) == 16
      assert get_field(changeset, :routing_breaker_error_rate_threshold) == 0.2
      assert get_field(changeset, :routing_breaker_429_threshold) == 0.1
      assert get_field(changeset, :routing_breaker_latency_p95_ms) == 6000
      assert get_field(changeset, :routing_open_cooldown_ms) == 30_000
      assert get_field(changeset, :routing_half_open_probe_count) == 3
      assert get_field(changeset, :routing_timeout_ms) == 30_000
      assert get_field(changeset, :routing_connect_timeout_ms) == 5_000
    end

    test "rejects soft limit greater than hard limit" do
      changeset =
        ServiceConfig.changeset(%ServiceConfig{}, %{
          name: "Invalid Config",
          primary_model_id: 1,
          routing_soft_limit: 10,
          routing_hard_limit: 5
        })

      refute changeset.valid?
      assert "must be less than or equal to hard limit" in errors_on(changeset).routing_soft_limit
    end

    test "rejects stream soft limit greater than stream hard limit" do
      changeset =
        ServiceConfig.changeset(%ServiceConfig{}, %{
          name: "Invalid Stream Config",
          primary_model_id: 1,
          routing_stream_soft_limit: 10,
          routing_stream_hard_limit: 5
        })

      refute changeset.valid?

      assert "must be less than or equal to stream hard limit" in
               errors_on(changeset).routing_stream_soft_limit
    end

    test "rejects breaker thresholds outside 0..1 range" do
      changeset =
        ServiceConfig.changeset(%ServiceConfig{}, %{
          name: "Invalid Threshold Config",
          primary_model_id: 1,
          routing_breaker_error_rate_threshold: 1.5,
          routing_breaker_429_threshold: -0.1
        })

      refute changeset.valid?
      assert "must be less than or equal to 1.0" in errors_on(changeset).routing_breaker_error_rate_threshold
      assert "must be greater than or equal to 0.0" in errors_on(changeset).routing_breaker_429_threshold
    end

    test "rejects negative routing limits" do
      changeset =
        ServiceConfig.changeset(%ServiceConfig{}, %{
          name: "Negative Config",
          primary_model_id: 1,
          routing_timeout_ms: -10
        })

      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).routing_timeout_ms
    end
  end

  describe "secondary model validations" do
    test "allows nil secondary model" do
      changeset =
        ServiceConfig.changeset(%ServiceConfig{}, %{
          name: "Config",
          primary_model_id: 1,
          backup_model_id: 2
        })

      assert changeset.valid?
    end

    test "rejects secondary model matching primary model" do
      changeset =
        ServiceConfig.changeset(%ServiceConfig{}, %{
          name: "Config",
          primary_model_id: 1,
          secondary_model_id: 1
        })

      refute changeset.valid?
      assert "must be different from primary model" in errors_on(changeset).secondary_model_id
    end

    test "rejects secondary model matching backup model" do
      changeset =
        ServiceConfig.changeset(%ServiceConfig{}, %{
          name: "Config",
          primary_model_id: 1,
          secondary_model_id: 2,
          backup_model_id: 2
        })

      refute changeset.valid?
      assert "must be different from backup model" in errors_on(changeset).secondary_model_id
    end
  end
end

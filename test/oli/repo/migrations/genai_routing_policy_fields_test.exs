defmodule Oli.Repo.Migrations.GenAIRoutingPolicyFieldsTest do
  use Oli.DataCase

  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}
  alias Oli.Repo

  describe "completions_service_configs routing policy constraints" do
    test "defaults are applied for new service configs" do
      registered_model = insert_registered_model()

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {1, [%{id: id}]} =
        Repo.insert_all(
          "completions_service_configs",
          [
            %{
              name: "Default Service Config",
              primary_model_id: registered_model.id,
              inserted_at: now,
              updated_at: now
            }
          ],
          returning: [:id]
        )

      service_config = Repo.get!(ServiceConfig, id)

      assert is_nil(service_config.secondary_model_id)
    end

    test "allows secondary model to remain nil" do
      registered_model = insert_registered_model()

      service_config =
        Repo.insert!(%ServiceConfig{
          name: "Nil Secondary",
          primary_model_id: registered_model.id,
          secondary_model_id: nil
        })

      assert is_nil(service_config.secondary_model_id)
    end
  end

  describe "registered_models routing policy fields" do
    test "defaults pool_class to slow and sets max_concurrent default" do
      registered_model = insert_registered_model()

      assert registered_model.pool_class == :slow
      assert registered_model.max_concurrent == 95
      assert registered_model.routing_breaker_error_rate_threshold == 0.2
      assert registered_model.routing_breaker_429_threshold == 0.1
      assert registered_model.routing_breaker_latency_p95_ms == 6000
      assert registered_model.routing_open_cooldown_ms == 30_000
      assert registered_model.routing_half_open_probe_count == 3
    end

    test "max_concurrent must be non-negative when present" do
      assert_raise Ecto.ConstraintError, ~r/max_concurrent_non_negative/, fn ->
        Repo.insert!(%RegisteredModel{
          name: "Invalid Model",
          provider: :open_ai,
          model: "gpt-4",
          url_template: "https://api.example.com",
          api_key: "secret",
          timeout: 8000,
          recv_timeout: 60_000,
          max_concurrent: -1
        })
      end
    end

    test "breaker error rate threshold must be between 0 and 1" do
      assert_raise Ecto.ConstraintError, ~r/routing_breaker_error_rate_threshold_range/, fn ->
        Repo.insert!(%RegisteredModel{
          name: "Invalid Error Threshold",
          provider: :open_ai,
          model: "gpt-4",
          url_template: "https://api.example.com",
          api_key: "secret",
          timeout: 8000,
          recv_timeout: 60_000,
          routing_breaker_error_rate_threshold: 1.5
        })
      end
    end

    test "breaker 429 threshold must be between 0 and 1" do
      assert_raise Ecto.ConstraintError, ~r/routing_breaker_429_threshold_range/, fn ->
        Repo.insert!(%RegisteredModel{
          name: "Invalid 429 Threshold",
          provider: :open_ai,
          model: "gpt-4",
          url_template: "https://api.example.com",
          api_key: "secret",
          timeout: 8000,
          recv_timeout: 60_000,
          routing_breaker_429_threshold: -0.1
        })
      end
    end

    test "breaker latency threshold must be non-negative" do
      assert_raise Ecto.ConstraintError, ~r/routing_breaker_latency_p95_ms_non_negative/, fn ->
        Repo.insert!(%RegisteredModel{
          name: "Invalid Latency Threshold",
          provider: :open_ai,
          model: "gpt-4",
          url_template: "https://api.example.com",
          api_key: "secret",
          timeout: 8000,
          recv_timeout: 60_000,
          routing_breaker_latency_p95_ms: -1
        })
      end
    end
  end

  defp insert_registered_model do
    Repo.insert!(%RegisteredModel{
      name: "Default Model",
      provider: :open_ai,
      model: "gpt-4",
      url_template: "https://api.example.com",
      api_key: "secret",
      timeout: 8000,
      recv_timeout: 60_000
    })
  end
end

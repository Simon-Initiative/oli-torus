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

      assert service_config.routing_soft_limit == 40
      assert service_config.routing_hard_limit == 80
      assert service_config.routing_breaker_error_rate_threshold == 0.2
      assert service_config.routing_breaker_429_threshold == 0.1
      assert service_config.routing_breaker_latency_p95_ms == 6000
      assert service_config.routing_open_cooldown_ms == 30_000
      assert service_config.routing_half_open_probe_count == 3
      assert service_config.routing_timeout_ms == 30_000
      assert service_config.routing_connect_timeout_ms == 5_000
      assert is_nil(service_config.secondary_model_id)
    end

    test "routing soft limit must be less than or equal to hard limit" do
      registered_model = insert_registered_model()

      assert_raise Ecto.ConstraintError, ~r/routing_soft_limit_lte_hard_limit/, fn ->
        Repo.insert!(%ServiceConfig{
          name: "Invalid Soft Limit",
          primary_model_id: registered_model.id,
          routing_soft_limit: 10,
          routing_hard_limit: 5
        })
      end
    end

    test "breaker error rate threshold must be between 0 and 1" do
      registered_model = insert_registered_model()

      assert_raise Ecto.ConstraintError, ~r/routing_breaker_error_rate_threshold_range/, fn ->
        Repo.insert!(%ServiceConfig{
          name: "Invalid Error Threshold",
          primary_model_id: registered_model.id,
          routing_breaker_error_rate_threshold: 1.5
        })
      end
    end

    test "routing timeout must be non-negative" do
      registered_model = insert_registered_model()

      assert_raise Ecto.ConstraintError, ~r/routing_timeout_ms_non_negative/, fn ->
        Repo.insert!(%ServiceConfig{
          name: "Invalid Timeout",
          primary_model_id: registered_model.id,
          routing_timeout_ms: -1
        })
      end
    end
  end

  describe "registered_models routing policy fields" do
    test "defaults pool_class to slow and allows null max_concurrent" do
      registered_model = insert_registered_model()

      assert registered_model.pool_class == :slow
      assert is_nil(registered_model.max_concurrent)
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

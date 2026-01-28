defmodule Oli.Repo.Migrations.AddGenAIRoutingPolicyFields do
  use Ecto.Migration

  @breaker_error_rate_threshold 0.2
  @breaker_429_threshold 0.1
  @breaker_latency_p95_ms 6000
  @breaker_open_cooldown_ms 30_000
  @breaker_half_open_probe_count 3

  def up do
    alter table(:completions_service_configs) do
      add :secondary_model_id, references(:registered_models, on_delete: :nothing), null: true
    end

    create index(:completions_service_configs, [:secondary_model_id])

    alter table(:registered_models) do
      add :pool_class, :string, null: false, default: "slow"
      add :max_concurrent, :integer, default: 95

      add :routing_breaker_error_rate_threshold, :float,
        default: @breaker_error_rate_threshold,
        null: false

      add :routing_breaker_429_threshold, :float, default: @breaker_429_threshold, null: false
      add :routing_breaker_latency_p95_ms, :integer, default: @breaker_latency_p95_ms, null: false
      add :routing_open_cooldown_ms, :integer, default: @breaker_open_cooldown_ms, null: false

      add :routing_half_open_probe_count, :integer,
        default: @breaker_half_open_probe_count,
        null: false
    end

    create constraint(:registered_models, :max_concurrent_non_negative,
             check: "max_concurrent IS NULL OR max_concurrent >= 0"
           )

    create constraint(:registered_models, :routing_breaker_error_rate_threshold_range,
             check:
               "routing_breaker_error_rate_threshold >= 0 AND routing_breaker_error_rate_threshold <= 1"
           )

    create constraint(:registered_models, :routing_breaker_429_threshold_range,
             check: "routing_breaker_429_threshold >= 0 AND routing_breaker_429_threshold <= 1"
           )

    create constraint(:registered_models, :routing_breaker_latency_p95_ms_non_negative,
             check: "routing_breaker_latency_p95_ms >= 0"
           )

    create constraint(:registered_models, :routing_open_cooldown_ms_non_negative,
             check: "routing_open_cooldown_ms >= 0"
           )

    create constraint(:registered_models, :routing_half_open_probe_count_non_negative,
             check: "routing_half_open_probe_count >= 0"
           )
  end

  def down do
    drop constraint(:registered_models, :routing_half_open_probe_count_non_negative)
    drop constraint(:registered_models, :routing_open_cooldown_ms_non_negative)
    drop constraint(:registered_models, :routing_breaker_latency_p95_ms_non_negative)
    drop constraint(:registered_models, :routing_breaker_429_threshold_range)
    drop constraint(:registered_models, :routing_breaker_error_rate_threshold_range)
    drop constraint(:registered_models, :max_concurrent_non_negative)

    alter table(:registered_models) do
      remove :pool_class
      remove :max_concurrent
      remove :routing_half_open_probe_count
      remove :routing_open_cooldown_ms
      remove :routing_breaker_latency_p95_ms
      remove :routing_breaker_429_threshold
      remove :routing_breaker_error_rate_threshold
    end

    drop index(:completions_service_configs, [:secondary_model_id])

    alter table(:completions_service_configs) do
      remove :secondary_model_id
    end
  end
end

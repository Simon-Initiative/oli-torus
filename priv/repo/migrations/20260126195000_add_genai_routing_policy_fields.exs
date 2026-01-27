defmodule Oli.Repo.Migrations.AddGenAIRoutingPolicyFields do
  use Ecto.Migration

  @routing_soft_limit 40
  @routing_hard_limit 80
  @routing_breaker_error_rate_threshold 0.2
  @routing_breaker_429_threshold 0.1
  @routing_breaker_latency_p95_ms 6000
  @routing_open_cooldown_ms 30_000
  @routing_half_open_probe_count 3
  @routing_timeout_ms 30_000
  @routing_connect_timeout_ms 5_000

  def up do
    alter table(:completions_service_configs) do
      add :secondary_model_id, references(:registered_models, on_delete: :nothing), null: true
      add :routing_soft_limit, :integer, default: @routing_soft_limit
      add :routing_hard_limit, :integer, default: @routing_hard_limit
      add :routing_breaker_error_rate_threshold, :float,
        default: @routing_breaker_error_rate_threshold

      add :routing_breaker_429_threshold, :float, default: @routing_breaker_429_threshold
      add :routing_breaker_latency_p95_ms, :integer, default: @routing_breaker_latency_p95_ms
      add :routing_open_cooldown_ms, :integer, default: @routing_open_cooldown_ms
      add :routing_half_open_probe_count, :integer, default: @routing_half_open_probe_count
      add :routing_timeout_ms, :integer, default: @routing_timeout_ms
      add :routing_connect_timeout_ms, :integer, default: @routing_connect_timeout_ms
    end

    create index(:completions_service_configs, [:secondary_model_id])

    alter table(:registered_models) do
      add :pool_class, :string, null: false, default: "slow"
      add :max_concurrent, :integer
    end

    create constraint(:registered_models, :max_concurrent_non_negative,
             check: "max_concurrent IS NULL OR max_concurrent >= 0"
           )

    execute("""
    UPDATE completions_service_configs
    SET
      routing_soft_limit = COALESCE(routing_soft_limit, #{@routing_soft_limit}),
      routing_hard_limit = COALESCE(routing_hard_limit, #{@routing_hard_limit}),
      routing_breaker_error_rate_threshold = COALESCE(routing_breaker_error_rate_threshold, #{@routing_breaker_error_rate_threshold}),
      routing_breaker_429_threshold = COALESCE(routing_breaker_429_threshold, #{@routing_breaker_429_threshold}),
      routing_breaker_latency_p95_ms = COALESCE(routing_breaker_latency_p95_ms, #{@routing_breaker_latency_p95_ms}),
      routing_open_cooldown_ms = COALESCE(routing_open_cooldown_ms, #{@routing_open_cooldown_ms}),
      routing_half_open_probe_count = COALESCE(routing_half_open_probe_count, #{@routing_half_open_probe_count}),
      routing_timeout_ms = COALESCE(routing_timeout_ms, #{@routing_timeout_ms}),
      routing_connect_timeout_ms = COALESCE(routing_connect_timeout_ms, #{@routing_connect_timeout_ms})
    """)

    alter table(:completions_service_configs) do
      modify :routing_soft_limit, :integer, null: false
      modify :routing_hard_limit, :integer, null: false
      modify :routing_breaker_error_rate_threshold, :float, null: false
      modify :routing_breaker_429_threshold, :float, null: false
      modify :routing_breaker_latency_p95_ms, :integer, null: false
      modify :routing_open_cooldown_ms, :integer, null: false
      modify :routing_half_open_probe_count, :integer, null: false
      modify :routing_timeout_ms, :integer, null: false
      modify :routing_connect_timeout_ms, :integer, null: false
    end

    create constraint(:completions_service_configs, :routing_soft_limit_non_negative,
             check: "routing_soft_limit >= 0"
           )

    create constraint(:completions_service_configs, :routing_hard_limit_non_negative,
             check: "routing_hard_limit >= 0"
           )

    create constraint(:completions_service_configs, :routing_soft_limit_lte_hard_limit,
             check: "routing_soft_limit <= routing_hard_limit"
           )

    create constraint(:completions_service_configs, :routing_breaker_error_rate_threshold_range,
             check: "routing_breaker_error_rate_threshold >= 0 AND routing_breaker_error_rate_threshold <= 1"
           )

    create constraint(:completions_service_configs, :routing_breaker_429_threshold_range,
             check: "routing_breaker_429_threshold >= 0 AND routing_breaker_429_threshold <= 1"
           )

    create constraint(:completions_service_configs, :routing_breaker_latency_p95_ms_non_negative,
             check: "routing_breaker_latency_p95_ms >= 0"
           )

    create constraint(:completions_service_configs, :routing_open_cooldown_ms_non_negative,
             check: "routing_open_cooldown_ms >= 0"
           )

    create constraint(:completions_service_configs, :routing_half_open_probe_count_non_negative,
             check: "routing_half_open_probe_count >= 0"
           )

    create constraint(:completions_service_configs, :routing_timeout_ms_non_negative,
             check: "routing_timeout_ms >= 0"
           )

    create constraint(:completions_service_configs, :routing_connect_timeout_ms_non_negative,
             check: "routing_connect_timeout_ms >= 0"
           )
  end

  def down do
    drop constraint(:registered_models, :max_concurrent_non_negative)

    alter table(:registered_models) do
      remove :pool_class
      remove :max_concurrent
    end

    drop index(:completions_service_configs, [:secondary_model_id])

    drop constraint(:completions_service_configs, :routing_connect_timeout_ms_non_negative)
    drop constraint(:completions_service_configs, :routing_timeout_ms_non_negative)
    drop constraint(:completions_service_configs, :routing_half_open_probe_count_non_negative)
    drop constraint(:completions_service_configs, :routing_open_cooldown_ms_non_negative)
    drop constraint(:completions_service_configs, :routing_breaker_latency_p95_ms_non_negative)
    drop constraint(:completions_service_configs, :routing_breaker_429_threshold_range)
    drop constraint(:completions_service_configs, :routing_breaker_error_rate_threshold_range)
    drop constraint(:completions_service_configs, :routing_soft_limit_lte_hard_limit)
    drop constraint(:completions_service_configs, :routing_hard_limit_non_negative)
    drop constraint(:completions_service_configs, :routing_soft_limit_non_negative)

    alter table(:completions_service_configs) do
      remove :secondary_model_id
      remove :routing_connect_timeout_ms
      remove :routing_timeout_ms
      remove :routing_half_open_probe_count
      remove :routing_open_cooldown_ms
      remove :routing_breaker_latency_p95_ms
      remove :routing_breaker_429_threshold
      remove :routing_breaker_error_rate_threshold
      remove :routing_hard_limit
      remove :routing_soft_limit
    end
  end
end

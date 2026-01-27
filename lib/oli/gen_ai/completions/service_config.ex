defmodule Oli.GenAI.Completions.ServiceConfig do
  use Ecto.Schema

  import Ecto.Changeset

  schema "completions_service_configs" do
    field :name, :string
    belongs_to :primary_model, Oli.GenAI.Completions.RegisteredModel
    belongs_to :secondary_model, Oli.GenAI.Completions.RegisteredModel
    belongs_to :backup_model, Oli.GenAI.Completions.RegisteredModel

    field :routing_soft_limit, :integer, default: 40
    field :routing_hard_limit, :integer, default: 80
    field :routing_breaker_error_rate_threshold, :float, default: 0.2
    field :routing_breaker_429_threshold, :float, default: 0.1
    field :routing_breaker_latency_p95_ms, :integer, default: 6000
    field :routing_open_cooldown_ms, :integer, default: 30_000
    field :routing_half_open_probe_count, :integer, default: 3
    field :routing_timeout_ms, :integer, default: 30_000
    field :routing_connect_timeout_ms, :integer, default: 5_000

    field :usage_count, :integer, virtual: true

    timestamps(type: :utc_datetime)
  end

  def changeset(service_config, attrs) do
    service_config
    |> cast(attrs, [
      :name,
      :primary_model_id,
      :secondary_model_id,
      :backup_model_id,
      :routing_soft_limit,
      :routing_hard_limit,
      :routing_breaker_error_rate_threshold,
      :routing_breaker_429_threshold,
      :routing_breaker_latency_p95_ms,
      :routing_open_cooldown_ms,
      :routing_half_open_probe_count,
      :routing_timeout_ms,
      :routing_connect_timeout_ms
    ])
    |> validate_required([
      :name,
      :primary_model_id,
      :routing_soft_limit,
      :routing_hard_limit,
      :routing_breaker_error_rate_threshold,
      :routing_breaker_429_threshold,
      :routing_breaker_latency_p95_ms,
      :routing_open_cooldown_ms,
      :routing_half_open_probe_count,
      :routing_timeout_ms,
      :routing_connect_timeout_ms
    ])
    |> validate_number(:routing_soft_limit, greater_than_or_equal_to: 0)
    |> validate_number(:routing_hard_limit, greater_than_or_equal_to: 0)
    |> validate_number(:routing_breaker_error_rate_threshold,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> validate_number(:routing_breaker_429_threshold,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> validate_number(:routing_breaker_latency_p95_ms, greater_than_or_equal_to: 0)
    |> validate_number(:routing_open_cooldown_ms, greater_than_or_equal_to: 0)
    |> validate_number(:routing_half_open_probe_count, greater_than_or_equal_to: 0)
    |> validate_number(:routing_timeout_ms, greater_than_or_equal_to: 0)
    |> validate_number(:routing_connect_timeout_ms, greater_than_or_equal_to: 0)
    |> validate_soft_limit()
    |> validate_secondary_model()
  end

  defp validate_soft_limit(changeset) do
    soft_limit = get_field(changeset, :routing_soft_limit)
    hard_limit = get_field(changeset, :routing_hard_limit)

    if is_integer(soft_limit) and is_integer(hard_limit) and soft_limit <= hard_limit do
      changeset
    else
      add_error(changeset, :routing_soft_limit, "must be less than or equal to hard limit")
    end
  end

  defp validate_secondary_model(changeset) do
    primary_id = get_field(changeset, :primary_model_id)
    secondary_id = get_field(changeset, :secondary_model_id)
    backup_id = get_field(changeset, :backup_model_id)

    cond do
      is_nil(secondary_id) ->
        changeset

      secondary_id == primary_id ->
        add_error(changeset, :secondary_model_id, "must be different from primary model")

      not is_nil(backup_id) and secondary_id == backup_id ->
        add_error(changeset, :secondary_model_id, "must be different from backup model")

      true ->
        changeset
    end
  end
end

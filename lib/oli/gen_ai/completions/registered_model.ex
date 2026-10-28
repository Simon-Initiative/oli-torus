defmodule Oli.GenAI.Completions.RegisteredModel do
  use Ecto.Schema

  import Ecto.Changeset

  schema "registered_models" do
    field :name, :string
    field :model, :string
    belongs_to :configured_provider, Oli.GenAI.Provider, foreign_key: :provider_id
    field :health_check, :boolean, default: false
    field :capabilities, {:array, :string}, default: []
    field :timeout, :integer, default: 8000
    field :recv_timeout, :integer, default: 60000
    field :max_concurrent, :integer, default: 95
    field :routing_breaker_error_rate_threshold, :float, default: 0.2
    field :routing_breaker_429_threshold, :float, default: 0.1
    field :routing_breaker_latency_p95_ms, :integer, default: 6000
    field :routing_open_cooldown_ms, :integer, default: 30_000
    field :routing_half_open_probe_count, :integer, default: 3

    # virtual field for count of service configs appearing in
    field :service_config_count, :integer, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc "Validates model inference settings; connection credentials belong to the associated Provider."
  def changeset(registered_model, attrs) do
    registered_model
    |> cast(attrs, [
      :name,
      :provider_id,
      :health_check,
      :capabilities,
      :model,
      :timeout,
      :recv_timeout,
      :max_concurrent,
      :routing_breaker_error_rate_threshold,
      :routing_breaker_429_threshold,
      :routing_breaker_latency_p95_ms,
      :routing_open_cooldown_ms,
      :routing_half_open_probe_count
    ])
    |> validate_required([
      :provider_id,
      :name,
      :model,
      :timeout,
      :recv_timeout,
      :routing_breaker_error_rate_threshold,
      :routing_breaker_429_threshold,
      :routing_breaker_latency_p95_ms,
      :routing_open_cooldown_ms,
      :routing_half_open_probe_count
    ])
    |> validate_number(:timeout, greater_than: 0)
    |> validate_number(:recv_timeout, greater_than: 0)
    |> validate_capability_array()
    |> foreign_key_constraint(:provider_id)
    |> validate_number(:max_concurrent, greater_than_or_equal_to: 0)
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
  end

  defp validate_capability_array(changeset) do
    case get_field(changeset, :capabilities) do
      nil -> add_error(changeset, :capabilities, "must be a list")
      _ -> changeset
    end
  end
end

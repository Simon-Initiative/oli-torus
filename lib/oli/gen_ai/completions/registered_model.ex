defmodule Oli.GenAI.Completions.RegisteredModel do
  use Ecto.Schema

  import Ecto.Changeset

  schema "registered_models" do
    field :name, :string
    field :provider, Ecto.Enum, values: [:null, :open_ai, :claude]
    field :model, :string
    field :url_template, :string
    field :api_key, Oli.Encrypted.Binary
    field :secondary_api_key, Oli.Encrypted.Binary
    field :timeout, :integer, default: 8000
    field :recv_timeout, :integer, default: 60000
    field :pool_class, Ecto.Enum, values: [:fast, :slow], default: :slow
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

  @doc false
  def changeset(registered_model, attrs) do
    registered_model
    |> cast(attrs, [
      :name,
      :provider,
      :model,
      :url_template,
      :api_key,
      :secondary_api_key,
      :timeout,
      :recv_timeout,
      :pool_class,
      :max_concurrent,
      :routing_breaker_error_rate_threshold,
      :routing_breaker_429_threshold,
      :routing_breaker_latency_p95_ms,
      :routing_open_cooldown_ms,
      :routing_half_open_probe_count
    ])
    |> validate_required([
      :name,
      :provider,
      :model,
      :url_template,
      :api_key,
      :timeout,
      :recv_timeout,
      :pool_class,
      :routing_breaker_error_rate_threshold,
      :routing_breaker_429_threshold,
      :routing_breaker_latency_p95_ms,
      :routing_open_cooldown_ms,
      :routing_half_open_probe_count
    ])
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
end

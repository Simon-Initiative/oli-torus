defmodule Oli.GenAI.Provider do
  @moduledoc "Persisted connection and administrative configuration for independently probed Providers."
  use Ecto.Schema
  import Ecto.Changeset
  alias Oli.GenAI.Completions.Utils

  @policy_fields [
    :probe_interval_ms,
    :probe_failure_interval_ms,
    :probe_deadline_ms,
    :failure_threshold,
    :recovery_threshold
  ]

  schema "gen_ai_providers" do
    field :name, :string
    field :adapter, Ecto.Enum, values: [:open_ai, :claude, :null]
    field :base_url, :string
    field :api_key, Oli.Encrypted.Binary, redact: true
    field :organization_key, Oli.Encrypted.Binary, redact: true
    field :enabled, :boolean, default: true
    field :config_version, :integer, default: 1
    field :probe_interval_ms, :integer
    field :probe_failure_interval_ms, :integer
    field :probe_deadline_ms, :integer
    field :failure_threshold, :integer
    field :recovery_threshold, :integer
    has_many :registered_models, Oli.GenAI.Completions.RegisteredModel
    timestamps(type: :utc_datetime)
  end

  @doc "Validates connection settings without making an external request. Access is tested by an independent probe."
  def changeset(provider, attrs) do
    changeset =
      provider
      |> cast(
        attrs,
        [:name, :adapter, :base_url, :api_key, :organization_key, :enabled] ++ @policy_fields
      )
      |> validate_required([:name, :adapter, :enabled])
      |> validate_length(:name, max: 255)

    changeset =
      case {provider.id, get_field(changeset, :enabled), get_field(changeset, :adapter)} do
        {_, _, :null} ->
          changeset

        {id, false, _} when not is_nil(id) ->
          changeset

        _ ->
          changeset = validate_required(changeset, [:base_url, :api_key])

          case origin(endpoint(apply_changes(changeset), nil)) do
            {:ok, _} ->
              changeset

            {:error, _} ->
              add_error(
                changeset,
                :base_url,
                "must be an HTTP(S) URL without embedded credentials"
              )
          end
      end

    Enum.reduce(@policy_fields, changeset, &validate_number(&2, &1, greater_than: 0))
  end

  @doc "Realizes the existing adapter's endpoint templates using the selected model and Provider credentials."
  def endpoint(%{base_url: url} = provider, model) when is_binary(url) do
    identifier =
      case model do
        %{model: model} when is_binary(model) -> model
        _ -> "model"
      end

    Utils.realize_url(url, %{
      "model" => identifier,
      "api_key" => provider.api_key,
      "secondary_api_key" => provider.organization_key
    })
  end

  def endpoint(_, _), do: nil

  @doc "Returns an HTTP origin; production pool generations are restricted to a single origin."
  def origin(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host, port: port, userinfo: nil}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        {:ok, {scheme, String.downcase(host), port}}

      _ ->
        {:error, :invalid_endpoint}
    end
  rescue
    _ -> {:error, :invalid_endpoint}
  end

  def origin(_), do: {:error, :invalid_endpoint}

  @doc "Identifies execution inputs without exposing endpoint credentials in transport metadata."
  def transport_signature(provider, model) do
    {provider.id, provider.config_version, model.id, model.model,
     :crypto.hash(:sha256, endpoint(provider, model))}
  end

  @doc "Resolves persisted probe overrides against startup environment defaults."
  def policy(provider) do
    defaults = [
      probe_interval_ms: 180_000,
      probe_failure_interval_ms: 30_000,
      probe_deadline_ms: 10_000,
      failure_threshold: 3,
      recovery_threshold: 2
    ]

    configured = Application.get_env(:oli, :genai_health, [])

    Map.new(defaults, fn {key, default} ->
      {key, Map.get(provider, key) || Keyword.get(configured, key, default)}
    end)
  end
end

defmodule Oli.GenAI.Dev.LocalCodex do
  @moduledoc """
  Dev-only helper for pointing GenAI feature configs at a local OpenAI-compatible
  proxy in front of Codex.

  The setup is idempotent by model, service, and feature/section combination, so
  it can be rerun while iterating on the local proxy URL or model name.
  """

  import Ecto.Query, warn: false

  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}
  alias Oli.GenAI.FeatureConfig
  alias Oli.Repo

  @default_api_key "dev"
  @default_feature :student_dialogue
  @default_model "codex-proxy"
  @default_model_name "local-codex-proxy"
  @default_service_name "local-codex-proxy"
  @default_url "http://localhost:4001"

  @type setup_result :: %{
          registered_model: RegisteredModel.t(),
          service_config: ServiceConfig.t(),
          feature_config: FeatureConfig.t()
        }

  @spec setup(map() | keyword()) :: {:ok, setup_result()} | {:error, Ecto.Changeset.t()}
  def setup(attrs \\ %{}) do
    opts = normalize_attrs(attrs)

    Repo.transaction(fn ->
      with {:ok, registered_model} <- upsert_registered_model(opts),
           {:ok, service_config} <- upsert_service_config(registered_model, opts),
           {:ok, feature_config} <- upsert_feature_config(service_config, opts) do
        %{
          registered_model: registered_model,
          service_config: service_config,
          feature_config: feature_config
        }
      else
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp normalize_attrs(attrs) when is_list(attrs),
    do: attrs |> Enum.into(%{}) |> normalize_attrs()

  defp normalize_attrs(attrs) when is_map(attrs) do
    %{
      api_key: Map.get(attrs, :api_key, @default_api_key),
      feature: normalize_feature(Map.get(attrs, :feature, @default_feature)),
      model: Map.get(attrs, :model, @default_model),
      model_name: Map.get(attrs, :model_name, @default_model_name),
      section_id: Map.get(attrs, :section_id),
      service_name: Map.get(attrs, :service_name, @default_service_name),
      url: Map.get(attrs, :url, @default_url)
    }
  end

  defp normalize_feature(feature) when feature in [:student_dialogue, :instructor_dashboard],
    do: feature

  defp normalize_feature("student_dialogue"), do: :student_dialogue
  defp normalize_feature("instructor_dashboard"), do: :instructor_dashboard

  defp normalize_feature(other),
    do: raise(ArgumentError, "unsupported feature: #{inspect(other)}")

  defp upsert_registered_model(opts) do
    attrs = %{
      api_key: opts.api_key,
      max_concurrent: 4,
      model: opts.model,
      name: opts.model_name,
      pool_class: :slow,
      provider: :open_ai,
      recv_timeout: 60_000,
      routing_breaker_429_threshold: 0.0,
      routing_breaker_error_rate_threshold: 0.0,
      routing_breaker_latency_p95_ms: 0,
      routing_half_open_probe_count: 3,
      routing_open_cooldown_ms: 30_000,
      timeout: 8_000,
      url_template: opts.url
    }

    case Repo.get_by(RegisteredModel, name: opts.model_name) do
      nil ->
        %RegisteredModel{}

      registered_model ->
        registered_model
    end
    |> RegisteredModel.changeset(attrs)
    |> Repo.insert_or_update()
  end

  defp upsert_service_config(%RegisteredModel{id: registered_model_id}, opts) do
    attrs = %{
      name: opts.service_name,
      primary_model_id: registered_model_id,
      secondary_model_id: nil,
      backup_model_id: nil
    }

    case Repo.get_by(ServiceConfig, name: opts.service_name) do
      nil ->
        %ServiceConfig{}

      service_config ->
        service_config
    end
    |> ServiceConfig.changeset(attrs)
    |> Repo.insert_or_update()
  end

  defp upsert_feature_config(%ServiceConfig{id: service_config_id}, opts) do
    attrs = %{
      feature: opts.feature,
      service_config_id: service_config_id,
      section_id: opts.section_id
    }

    opts.feature
    |> feature_config_query(opts.section_id)
    |> Repo.one()
    |> case do
      nil ->
        %FeatureConfig{}

      feature_config ->
        feature_config
    end
    |> FeatureConfig.changeset(attrs)
    |> Repo.insert_or_update()
  end

  defp feature_config_query(feature, nil) do
    from(fc in FeatureConfig, where: fc.feature == ^feature and is_nil(fc.section_id))
  end

  defp feature_config_query(feature, section_id) do
    from(fc in FeatureConfig, where: fc.feature == ^feature and fc.section_id == ^section_id)
  end
end

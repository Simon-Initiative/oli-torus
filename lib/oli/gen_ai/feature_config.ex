defmodule Oli.GenAI.FeatureConfig do
  @moduledoc """
  Persists the GenAI service configuration selected for each product feature.

  A configuration can be global (`section_id == nil`) or section-specific. Runtime
  callers use this module to resolve the effective completion provider/model set
  for features such as instructor dashboard recommendations.
  """

  use Ecto.Schema

  import Ecto.Query, warn: false
  import Ecto.Changeset

  @features [:student_dialogue, :instructor_dashboard_recommendation, :instructor_email]

  def features, do: @features

  schema "gen_ai_feature_configs" do
    field :feature, Ecto.Enum, values: @features

    belongs_to :service_config, Oli.GenAI.Completions.ServiceConfig
    belongs_to :section, Oli.Delivery.Sections.Section

    timestamps(type: :utc_datetime)
  end

  def changeset(service_config, attrs) do
    service_config
    |> cast(attrs, [:feature, :service_config_id, :section_id])
    |> validate_required([:feature, :service_config_id])
  end

  @type load_error :: {:missing_feature_config, String.t()}

  @doc """
  Returns the effective `ServiceConfig` for the given `feature` + `section_id`.

  Passing `nil` for `section_id` resolves the global default; an integer
  resolves the section-specific row falling back to the global default.

  Returns `{:ok, ServiceConfig.t()}` on success or `{:error,
  {:missing_feature_config, message}}` when no row matches.
  """
  @spec load_for(nil | pos_integer(), atom()) ::
          {:ok, Oli.GenAI.Completions.ServiceConfig.t()} | {:error, load_error()}
  def load_for(nil, feature) do
    query =
      from(g in __MODULE__,
        where: g.feature == ^feature and is_nil(g.section_id),
        preload: [service_config: [:primary_model, :secondary_model, :backup_model]],
        limit: 1
      )

    case Oli.Repo.one(query) do
      %__MODULE__{service_config: service_config} ->
        {:ok, service_config}

      nil ->
        {:error,
         {:missing_feature_config,
          "No GenAI feature config found for feature #{inspect(feature)} (global)"}}
    end
  end

  # `desc_nulls_last` orders the section-specific row before the global default,
  # so LIMIT 1 picks the correct one without loading every match.
  def load_for(section_id, feature) when is_integer(section_id) do
    query =
      from(g in __MODULE__,
        where:
          g.feature == ^feature and
            (g.section_id == ^section_id or is_nil(g.section_id)),
        preload: [service_config: [:primary_model, :secondary_model, :backup_model]],
        order_by: [desc_nulls_last: g.section_id],
        limit: 1
      )

    case Oli.Repo.one(query) do
      %__MODULE__{service_config: service_config} ->
        {:ok, service_config}

      nil ->
        {:error,
         {:missing_feature_config,
          "No GenAI feature config found for feature #{inspect(feature)} (section_id=#{section_id})"}}
    end
  end
end

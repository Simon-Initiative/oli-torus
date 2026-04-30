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

  @features [:student_dialogue, :instructor_dashboard_recommendation]

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

  def load_for(section_id, feature) do
    case from(
           g in __MODULE__,
           where: (g.section_id == ^section_id or is_nil(g.section_id)) and g.feature == ^feature,
           preload: [service_config: [:primary_model, :secondary_model, :backup_model]]
         )
         |> Oli.Repo.all() do
      [] ->
        raise "No configurations found for section #{section_id} and feature #{feature}"

      [%__MODULE__{section_id: nil} = default_config] ->
        default_config.service_config

      multiple_found ->
        Enum.find(multiple_found, fn config -> config.section_id == section_id end).service_config
    end
  end
end

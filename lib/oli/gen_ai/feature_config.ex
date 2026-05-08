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

  def load_for(section_id, feature) do
    base =
      from(g in __MODULE__,
        where: g.feature == ^feature,
        preload: [service_config: [:primary_model, :secondary_model, :backup_model]]
      )

    scoped =
      if is_nil(section_id) do
        from(g in base, where: is_nil(g.section_id))
      else
        from(g in base, where: g.section_id == ^section_id or is_nil(g.section_id))
      end

    case Oli.Repo.all(scoped) do
      [] ->
        raise "No GenAI feature config found for feature #{inspect(feature)} (section_id=#{inspect(section_id)})"

      [%__MODULE__{section_id: nil} = default_config] ->
        default_config.service_config

      rows ->
        # Multiple rows can come back when a non-nil section_id is supplied: a
        # section-specific override and the global default. Prefer the section
        # override; fall back to the global default if no section row exists.
        section_match = Enum.find(rows, fn config -> config.section_id == section_id end)
        global_default = Enum.find(rows, fn config -> is_nil(config.section_id) end)

        case section_match || global_default do
          %__MODULE__{service_config: service_config} ->
            service_config

          nil ->
            raise "No GenAI feature config found for feature #{inspect(feature)} (section_id=#{inspect(section_id)})"
        end
    end
  end
end

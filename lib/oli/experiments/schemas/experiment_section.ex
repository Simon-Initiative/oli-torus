defmodule Oli.Experiments.Schemas.ExperimentSection do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Delivery.Sections.Section
  alias Oli.Experiments.Schemas.ExperimentDefinition

  schema "experiment_sections" do
    belongs_to :experiment, ExperimentDefinition
    belongs_to :section, Section

    timestamps(type: :utc_datetime)
  end

  def changeset(experiment_section, attrs) do
    experiment_section
    |> cast(attrs, [:experiment_id, :section_id])
    |> validate_required([:experiment_id, :section_id])
    |> foreign_key_constraint(:experiment_id)
    |> foreign_key_constraint(:section_id)
    |> unique_constraint([:experiment_id, :section_id],
      name: :experiment_sections_experiment_id_section_id_index
    )
  end
end

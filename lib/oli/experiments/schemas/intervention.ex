defmodule Oli.Experiments.Schemas.Intervention do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Experiments.Schemas.{AssessmentBinding, ExperimentDefinition}
  alias Oli.Resources.Resource

  schema "experiment_interventions" do
    field :content_element_id, :string
    belongs_to :experiment, ExperimentDefinition
    belongs_to :page_resource, Resource
    has_one :assessment_binding, AssessmentBinding
    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(intervention, attrs \\ %{}) do
    intervention
    |> cast(attrs, [:experiment_id, :page_resource_id, :content_element_id])
    |> validate_required([:experiment_id, :page_resource_id, :content_element_id])
    |> validate_length(:content_element_id, min: 1, max: 255)
    |> foreign_key_constraint(:experiment_id)
    |> foreign_key_constraint(:page_resource_id)
    |> unique_constraint([:experiment_id, :page_resource_id, :content_element_id],
      name: :experiment_interventions_identity_idx
    )
  end
end

defmodule Oli.Experiments.Schemas.AssessmentBinding do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Experiments.Schemas.Intervention
  alias Oli.Resources.Resource

  schema "experiment_assessment_bindings" do
    field :reward_threshold, :decimal, default: Decimal.new(1)
    belongs_to :intervention, Intervention
    belongs_to :assessment_page_resource, Resource
    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(binding, attrs \\ %{}) do
    binding
    |> cast(attrs, [:intervention_id, :assessment_page_resource_id, :reward_threshold])
    |> validate_required([:intervention_id, :assessment_page_resource_id, :reward_threshold])
    |> validate_number(:reward_threshold, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> foreign_key_constraint(:intervention_id)
    |> foreign_key_constraint(:assessment_page_resource_id)
    |> unique_constraint(:intervention_id, name: :experiment_assessment_bindings_intervention_idx)
  end
end

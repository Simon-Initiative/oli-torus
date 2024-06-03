defmodule Oli.Authoring.Schemas.Experiment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "experiments" do
    field :is_enabled, :boolean, default: false
    belongs_to :revision, Oli.Resources.Revision
  end

  def changeset(%__MODULE__{} = experiment, attrs) do
    experiment
    |> cast(attrs, [:is_enabled])
    |> validate_required([:is_enabled])
  end

  def new_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:is_enabled, :revision_id])
    |> validate_required([:is_enabled, :revision_id])
  end
end

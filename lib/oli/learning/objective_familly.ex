defmodule Oli.Learning.ObjectiveFamily do
  use Ecto.Schema
  import Ecto.Changeset

  schema "objective_families" do

    timestamps()
  end

  @doc false
  def changeset(objective_family, attrs) do
    objective_family
    |> cast(attrs, [])
    |> validate_required([])
  end

end

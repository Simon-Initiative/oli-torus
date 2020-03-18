defmodule Oli.Authoring.Objective do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pages_with_positions" do
    timestamps()
    field :description, :string
    belongs_to :project, Oli.Authoring.Project
    many_to_many :parents, Oli.Authoring.Objective, join_through: "objectives_objectives"
    many_to_many :children, Oli.Authoring.Objective, join_through: "objectives_objectives"
  end

  @doc false
  def changeset(objective, attrs \\ %{}) do
    objective
    |> cast(attrs, [
      :description,
      :parents,
      :children
    ])
    |> validate_required([:description])
  end
end

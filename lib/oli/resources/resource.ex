defmodule Oli.Resources.Resource do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resources" do
    field :slug, :string

    belongs_to :project, Oli.Course.Project

    timestamps()
  end

  @doc false
  def changeset(resource, attrs) do
    resource
    |> cast(attrs, [:slug, :project_id])
    |> validate_required([:slug, :project_id])
    |> unique_constraint(:slug)
  end
end

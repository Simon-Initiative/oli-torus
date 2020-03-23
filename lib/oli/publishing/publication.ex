defmodule Oli.Publishing.Publication do
  use Ecto.Schema
  import Ecto.Changeset

  schema "publications" do
    field :description, :string
    field :published, :boolean, default: false
    field :root_resources, {:array, :id}

    belongs_to :project, Oli.Course.Project

    timestamps()
  end

  @doc false
  def changeset(publication, attrs) do
    publication
    |> cast(attrs, [:description, :root_resources, :project_id])
    |> validate_required([:description, :root_resources, :published, :project_id])
  end
end

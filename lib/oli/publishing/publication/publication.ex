defmodule Oli.Publishing.Publication do
  use Ecto.Schema
  import Ecto.Changeset

  schema "publications" do
    field :description, :string
    field :published, :boolean, default: false
    belongs_to :root_resource, Oli.Resources.Resource
    belongs_to :project, Oli.Authoring.Course.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(publication, attrs \\ %{}) do
    publication
    |> cast(attrs, [:description, :published, :root_resource_id, :project_id])
    |> validate_required([:root_resource_id, :published, :project_id])
  end

end

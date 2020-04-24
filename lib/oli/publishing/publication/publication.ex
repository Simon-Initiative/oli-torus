defmodule Oli.Publishing.Publication do
  use Ecto.Schema
  import Ecto.Changeset

  schema "publications" do
    field :description, :string
    field :published, :boolean, default: false
    field :open_and_free, :boolean, default: false
    belongs_to :root_resource, Oli.Resources.Resource
    belongs_to :project, Oli.Authoring.Course.Project

    timestamps()
  end

  @doc false
  def changeset(publication, attrs \\ %{}) do
    publication
    |> cast(attrs, [:description, :open_and_free, :published, :root_resource_id, :project_id])
    |> validate_required([:root_resource_id, :published, :project_id])
  end

end

defmodule Oli.Publishing.Publications.Publication do
  use Ecto.Schema
  import Ecto.Changeset

  schema "publications" do
    field :published, :utc_datetime
    field :description, :string
    field :edition, :integer, default: 0
    field :major, :integer, default: 0
    field :minor, :integer, default: 0

    belongs_to :root_resource, Oli.Resources.Resource
    belongs_to :project, Oli.Authoring.Course.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(publication, attrs \\ %{}) do
    publication
    |> cast(attrs, [
      :published,
      :description,
      :edition,
      :major,
      :minor,
      :root_resource_id,
      :project_id
    ])
    |> validate_required([:root_resource_id, :project_id])
  end
end

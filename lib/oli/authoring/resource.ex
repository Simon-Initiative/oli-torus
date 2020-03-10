defmodule Oli.Authoring.Resource do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resources" do
    timestamps()
    field :title, :string
    field :slug, :string
    belongs_to :last_revision, Oli.Authoring.Revision
    belongs_to :resource_type, Oli.Authoring.ResourceType
    belongs_to :project, Oli.Authoring.Project
  end

  @doc false
  def changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [
      :title,
      :slug,
      :last_revision,
      :resource_type,
      :project
    ])
    |> validate_required([:title, :slug, :last_revision, :resource_type, :project])
    |> unique_constraint(:slug)
  end
end

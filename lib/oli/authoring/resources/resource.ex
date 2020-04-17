defmodule Oli.Authoring.Resources.Resource do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resources" do

    belongs_to :family, Oli.Authoring.Resources.ResourceFamily
    belongs_to :project, Oli.Authoring.Course.Project
    has_many :resource_revisions, Oli.Authoring.Resources.ResourceRevision

    timestamps()
  end

  @doc false
  def changeset(resource, attrs) do
    resource
    |> cast(attrs, [:project_id, :family_id])
    |> validate_required([:project_id, :family_id])
  end

end

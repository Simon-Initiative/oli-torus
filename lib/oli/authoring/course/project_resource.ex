defmodule Oli.Authoring.Course.ProjectResource do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "projects_resources" do
    timestamps()
    field :project_id, :integer, primary_key: true
    field :resource_id, :integer, primary_key: true
  end

  @doc false
  def changeset(project_resource, attrs \\ %{}) do
    project_resource
    |> cast(attrs, [:project_id, :resource_id])
    |> validate_required([:project_id, :resource_id])
  end
end

defmodule Oli.PartComponents.PartComponentRegistrationProject do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "part_component_registration_projects" do
    timestamps(type: :utc_datetime)
    field :part_component_registration_id, :integer, primary_key: true
    field :project_id, :integer, primary_key: true
  end

  @doc false
  def changeset(author_project, attrs \\ %{}) do
    author_project
    |> cast(attrs, [:part_component_registration_id, :project_id])
    |> validate_required([:part_component_registration_id, :project_id])
    |> unique_constraint(:part_component_registration_id,
      name: :index_part_component_registration_project
    )
  end
end

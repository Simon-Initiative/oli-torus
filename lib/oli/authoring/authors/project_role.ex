defmodule Oli.Authoring.Authors.ProjectRole do
  use Ecto.Schema
  import Ecto.Changeset

  def role_id, do: %{
    owner: 1,
    contributor: 2,
  }

  schema "project_roles" do
    field :type, :string
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(project_role, attrs \\ %{}) do
    project_role
    |> cast(attrs, [:type])
    |> validate_required([:type])
  end
end

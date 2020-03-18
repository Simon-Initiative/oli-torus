defmodule Oli.Accounts.ProjectRole do
  use Ecto.Schema
  import Ecto.Changeset

  schema "project_roles" do
    field :type, :string
    timestamps()
  end

  @doc false
  def changeset(project_role, attrs) do
    project_role
    |> cast(attrs, [:type])
    |> validate_required([:type])
  end
end

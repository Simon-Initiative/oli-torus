defmodule Oli.Accounts.SystemRole do
  use Ecto.Schema
  import Ecto.Changeset

  schema "system_roles" do
    field :type, :string
    timestamps()
  end

  @doc false
  def changeset(system_role, attrs) do
    system_role
    |> cast(attrs, [:type])
    |> validate_required([:type])
  end
end

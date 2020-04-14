defmodule Oli.Accounts.SystemRole do
  use Ecto.Schema
  import Ecto.Changeset

  @doc """
  Enumerates all the SystemRole ids
  """
  def role_id, do: %{
    author: 1,
    admin: 2,
  }

  schema "system_roles" do
    field :type, :string
    timestamps()
  end

  @doc false
  def changeset(system_role, attrs \\ %{}) do
    system_role
    |> cast(attrs, [:type])
    |> validate_required([:type])
  end
end

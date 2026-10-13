defmodule Oli.Accounts.SystemRole do
  use Ecto.Schema
  import Ecto.Changeset

  @doc """
  Enumerates all the SystemRole ids
  """
  def role_id,
    do: %{
      author: 1,
      system_admin: 2,
      account_admin: 3,
      content_admin: 4
    }

  @doc """
  Returns the display label for a system role ID.
  """
  def label(id) do
    case id do
      2 -> "System Admin"
      3 -> "Account Admin"
      4 -> "Content Admin"
      _ -> "Author"
    end
  end

  schema "system_roles" do
    field :type, :string
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(system_role, attrs \\ %{}) do
    system_role
    |> cast(attrs, [:type])
    |> validate_required([:type])
  end
end

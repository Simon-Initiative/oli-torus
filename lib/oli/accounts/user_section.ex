defmodule Oli.Accounts.UserSection do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "users_sections" do
    timestamps()
    belongs_to :user, Oli.Accounts.User
    belongs_to :section, Oli.Delivery.Section
    belongs_to :role, Oli.Accounts.Role
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:user_id, :section_id, :role_id])
    |> validate_required([:user_id, :section_id, :role_id])
  end
end

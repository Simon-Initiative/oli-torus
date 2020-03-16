defmodule Oli.Accounts.UserSection do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "users_sections" do
    timestamps()
    belongs_to :user, Oli.Accounts.User
    belongs_to :section, Oli.Delivery.Section
    belongs_to :section_role, Oli.Accounts.SectionRole
  end

  @doc false
  def changeset(user_section, attrs) do
    user_section
    |> cast(attrs, [:user_id, :section_id, :section_role_id])
    |> validate_required([:user_id, :section_id, :section_role_id])
  end
end

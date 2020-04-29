defmodule Oli.Delivery.Sections.Enrollment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "enrollments" do

    belongs_to :user, Oli.Accounts.User
    belongs_to :section, Oli.Delivery.Sections.Section
    belongs_to :section_role, Oli.Delivery.Sections.SectionRole

    timestamps()
  end

  @doc false
  def changeset(section, attrs) do
    section
    |> cast(attrs, [:user_id, :section_id, :section_role_id])
    |> validate_required([:user_id, :section_id, :section_role_id])
  end
end

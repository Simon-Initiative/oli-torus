defmodule Oli.Delivery.Sections.Enrollment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "enrollments" do
    belongs_to :user, Oli.Accounts.User
    belongs_to :section, Oli.Delivery.Sections.Section
    field :state, :map, default: %{}

    many_to_many :context_roles, Lti_1p3.DataProviders.EctoProvider.ContextRole,
      join_through: "enrollments_context_roles",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section, attrs) do
    section
    |> cast(attrs, [:user_id, :section_id, :state])
    |> validate_required([:user_id, :section_id])
  end
end

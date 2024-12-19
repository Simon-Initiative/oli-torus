defmodule Oli.Delivery.Sections.Enrollment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "enrollments" do
    belongs_to :user, Oli.Accounts.User
    belongs_to :section, Oli.Delivery.Sections.Section
    belongs_to :most_recently_visited_resource, Oli.Resources.Resource

    field :state, :map, default: %{}

    field :status, Ecto.Enum,
      values: [:enrolled, :suspended, :pending_confirmation, :rejected],
      default: :enrolled

    many_to_many :context_roles, Lti_1p3.DataProviders.EctoProvider.ContextRole,
      join_through: "enrollments_context_roles",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(enrollment, attrs) do
    enrollment
    |> cast(attrs, [:user_id, :section_id, :state, :status, :most_recently_visited_resource_id])
    |> validate_required([:user_id, :section_id])
    |> validate_inclusion(:status, Ecto.Enum.values(__MODULE__, :status))
  end
end

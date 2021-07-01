defmodule Oli.Delivery.Sections.UserGroup do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.DeliveryPolicy

  schema "user_groups" do
    field :name, :string

    many_to_many :users, Oli.Accounts.User, join_through: "user_groups_users"

    belongs_to :section, Section

    # group delivery policy
    belongs_to :delivery_policy, DeliveryPolicy

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_group, attrs \\ %{}) do
    user_group
    |> cast(attrs, [:author_id, :section_id, :delivery_policy_id])
    |> validate_required([:author_id, :section_id, :delivery_policy_id])
  end
end

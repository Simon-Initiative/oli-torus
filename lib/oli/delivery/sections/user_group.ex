defmodule Oli.Delivery.Sections.UserGroup do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_groups" do
    field :name, :string

    many_to_many :users, Oli.Accounts.User,
      join_through: "user_groups_users",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_group, attrs \\ %{}) do
    user_group
    |> cast(attrs, [:author_id, :section_id])
    |> validate_required([:author_id, :section_id])
  end
end

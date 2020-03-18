defmodule Oli.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user" do
    field :user_id, :string
    field :user_image, :string
    field :roles, :string
    belongs_to :author, Oli.Accounts.User
    belongs_to :tool_consumer, Oli.Accounts.LtiToolConsumer

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:user_id, :user_image, :roles, :author_id, :tool_consumer_id])
    |> validate_required([:user_id, :user_image, :roles])
  end
end

defmodule Oli.Authoring.Attempt do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resources" do
    timestamps()
    field :score, :integer
    belongs_to :resource, Oli.Authoring.Resource
    belongs_to :user, Oli.Accounts.User
  end

  @doc false
  def changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [
      :score,
      :resource,
      :user
    ])
    |> validate_required([:score, :resource, :user])
  end
end

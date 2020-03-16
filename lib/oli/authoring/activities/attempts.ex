defmodule Oli.Authoring.Attempt do
  use Ecto.Schema
  import Ecto.Changeset

  schema "attempts" do
    timestamps()
    field :score, :integer
    belongs_to :activity, Oli.Authoring.Resource
    belongs_to :user, Oli.Accounts.User
  end

  @doc false
  def changeset(attempt, attrs \\ %{}) do
    attempt
    |> cast(attrs, [
      :score,
      :resource,
      :user
    ])
    |> validate_required([:score, :resource, :user])
  end
end

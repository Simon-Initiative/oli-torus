defmodule Oli.Resources.Collaboration.UserReactionPost do
  use Ecto.Schema

  import Ecto.Changeset

  schema "user_reaction_posts" do
    field :reaction, Ecto.Enum, values: [:like], default: :like

    belongs_to :user, Oli.Accounts.User
    belongs_to :post, Oli.Resources.Collaboration.Post

    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs \\ %{}) do
    post
    |> cast(attrs, [
      :reaction,
      :user_id,
      :post_id
    ])
    |> validate_required([
      :reaction,
      :user_id,
      :post_id
    ])
  end
end

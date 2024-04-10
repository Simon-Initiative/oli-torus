defmodule Oli.Resources.Collaboration.UserReadPost do
  use Ecto.Schema

  import Ecto.Changeset

  schema "user_read_posts" do
    belongs_to :user, Oli.Accounts.User
    belongs_to :post, Oli.Resources.Collaboration.Post

    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs \\ %{}) do
    post
    |> cast(attrs, [
      :user_id,
      :post_id
    ])
  end
end

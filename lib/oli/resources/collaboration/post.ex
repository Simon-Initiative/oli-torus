defmodule Oli.Resources.Collaboration.Post do
  use Ecto.Schema

  import Ecto.Changeset

  schema "posts" do
    field :content, :map, default: %{}
    field :status, Ecto.Enum, values: [:submitted, :approved, :deleted, :archived], default: :approved

    belongs_to :user, Oli.Accounts.User
    belongs_to :section, Oli.Delivery.Sections.Section
    belongs_to :resource, Oli.Resources.Resource
    belongs_to :parent_post, Oli.Resources.Collaboration.Post
    belongs_to :thread_root, Oli.Resources.Collaboration.Post

    field :replies_count, :integer, virtual: true

    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs \\ %{}) do
    post
    |> cast(attrs, [
      :content,
      :status,
      :user_id,
      :section_id,
      :resource_id,
      :parent_post_id,
      :thread_root_id,
      :replies_count
    ])
  end
end

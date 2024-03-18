defmodule Oli.Resources.Collaboration.Post do
  use Ecto.Schema

  import Ecto.Changeset

  schema "posts" do
    @derive {Jason.Encoder, except: [:user, :resource, :section]}

    embeds_one :content, Oli.Resources.Collaboration.PostContent, on_replace: :update

    field :status, Ecto.Enum,
      values: [:submitted, :approved, :deleted, :archived],
      default: :approved

    belongs_to :user, Oli.Accounts.User
    belongs_to :section, Oli.Delivery.Sections.Section
    belongs_to :resource, Oli.Resources.Resource
    belongs_to :parent_post, Oli.Resources.Collaboration.Post
    belongs_to :thread_root, Oli.Resources.Collaboration.Post

    belongs_to :annotated_resource, Oli.Resources.Resource

    field :annotated_block_id, :string

    field :annotation_type, Ecto.Enum,
      values: [:none, :point, :range],
      default: :none

    field :visibility, Ecto.Enum,
      values: [:private, :public],
      default: :private

    field :replies_count, :integer, virtual: true
    field :read_replies_count, :integer, virtual: true
    field :is_read, :boolean, virtual: true

    field :anonymous, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs \\ %{}) do
    post
    |> cast(attrs, [
      :status,
      :user_id,
      :section_id,
      :resource_id,
      :parent_post_id,
      :thread_root_id,
      :annotated_resource_id,
      :annotated_block_id,
      :annotation_type,
      :visibility,
      :replies_count,
      :anonymous
    ])
    |> cast_embed(:content)
  end

  def post_response(post) do
    %{
      id: post.id,
      content: post.content.message,
      user_id: post.user_id,
      user_name: post.user.name,
      parent_post_id: post.parent_post_id,
      thread_root_id: post.thread_root_id,
      annotated_resource_id: post.annotated_resource_id,
      annotated_block_id: post.annotated_block_id,
      annotation_type: post.annotation_type,
      visibility: post.visibility,
      anonymous: post.anonymous,
      updated_at: post.updated_at
    }
  end
end

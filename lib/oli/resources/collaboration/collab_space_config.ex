defmodule Oli.Resources.Collaboration.CollabSpaceConfig do
  use Ecto.Schema

  import Ecto.Changeset

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field :status, Ecto.Enum, values: [:disabled, :enabled, :archived], default: :disabled

    field :threaded, :boolean, default: true
    field :auto_accept, :boolean, default: true
    field :show_full_history, :boolean, default: true

    field :participation_min_replies, :integer, default: 0
    field :participation_min_posts, :integer, default: 0
  end

  def changeset(collab_space_config, attrs \\ %{}) do
    collab_space_config
    |> cast(attrs, [
      :status,
      :threaded,
      :auto_accept,
      :show_full_history,
      :participation_min_replies,
      :participation_min_posts
    ])
  end
end

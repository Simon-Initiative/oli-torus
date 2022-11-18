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

  def changeset(collab_space_config, attrs \\ %{})

  def changeset(collab_space_config, %Oli.Resources.Collaboration.CollabSpaceConfig{} = attrs) do
    # if attrs is given as a struct, then convert it to a map in order to process
    changeset(collab_space_config, Map.from_struct(attrs))
  end

  def changeset(collab_space_config, attrs) do
    collab_space_config
    |> cast(attrs, [
      :status,
      :threaded,
      :auto_accept,
      :show_full_history,
      :participation_min_replies,
      :participation_min_posts
    ])
    |> validate_number(:participation_min_replies, greater_than: 0)
    |> validate_number(:participation_min_posts, greater_than: 0)
  end
end

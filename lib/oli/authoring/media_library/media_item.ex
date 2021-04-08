defmodule Oli.Authoring.MediaLibrary.MediaItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media_items" do
    field :url, :string
    field :file_name, :string
    field :mime_type, :string
    field :file_size, :integer
    field :md5_hash, :string
    field :deleted, :boolean

    belongs_to :project, Oli.Authoring.Course.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(score, attrs) do
    score
    |> cast(attrs, [:url, :file_name, :mime_type, :file_size, :md5_hash, :deleted, :project_id])
    |> validate_required([
      :url,
      :file_name,
      :mime_type,
      :file_size,
      :md5_hash,
      :deleted,
      :project_id
    ])
  end
end

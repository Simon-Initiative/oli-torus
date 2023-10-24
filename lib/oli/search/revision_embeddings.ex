defmodule Oli.Search.RevisionEmbeddings do
  use Ecto.Schema
  import Ecto.Changeset

  @chunk_types [
    :paragraph,
    :code,
    :image,
    :list,
    :table,
    :quote,
    :formula,
    :heading,
    :group,
    :audio,
    :video,
    :youtube,
    :iframe,
    :conjugation,
    :dialog,
    :example,
    :callout,
    :definition_list,
    :definition,
    :other
  ]

  @derive {Phoenix.Param, key: :slug}
  schema "revision_embeddings" do

    field :revision, references(:revisions)
    field :resource, references(:resources)
    field :resource_type: references(:resource_types)

    field :component_type, Ecto.Enum, values: [:stem, :hint, :feedback, :other]
    field :chunk_type, , Ecto.Enum, values: @chunk_types
    field :chunk_ordinal, :integer
    field :fingerprint_md5, :string
    field :content, :string
    field :embedding, Pgvector.Ecto.Vector

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(family, attrs \\ %{}) do
    family
    |> cast(attrs, [
      :revision_id,
      :resource_id,
      :resource_type_id,
      :component_type,
      :chunk_type,
      :chunk_ordinal,
      :fingerprint_md5,
      :content,
      :embedding
      ])
    |> validate_required([:revision_id, :resource_id, :resource_type_id, :component_type, :chunk_type, :chunk_ordinal, :fingerprint_md5, :content, :embedding])

  end
end

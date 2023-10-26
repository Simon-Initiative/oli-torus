defmodule Oli.Search.RevisionEmbedding do
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

  schema "revision_embeddings" do


    belongs_to :revision, Oli.Resources.Revision
    belongs_to :resource, Oli.Resources.Resource
    belongs_to :resource_type, Oli.Resources.ResourceType

    field :component_type, Ecto.Enum, values: [:stem, :hint, :feedback, :other]
    field :chunk_type, Ecto.Enum, values: @chunk_types
    field :chunk_ordinal, :integer
    field :fingerprint_md5, :string
    field :content, :string
    field :embedding, Pgvector.Ecto.Vector

    field(:title, :string, virtual: true)

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

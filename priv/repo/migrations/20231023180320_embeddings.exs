defmodule Oli.Repo.Migrations.Embeddings do
  use Ecto.Migration

  def up do
    create table("revision_embeddings") do

      add :revision_id, references(:revisions)
      add :resource_id, references(:resources)
      add :resource_type_id, references(:resource_types)

      add :component_type, :string
      add :chunk_type, :string
      add :chunk_ordinal, :integer
      add :fingerprint_md5, :string
      add :content, :text
      add :embedding, :vector, size: 1536
    end

    execute """
    CREATE INDEX revision_embeddings_idx ON revision_embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)
    """

  end

  def down do

    execute """
    DROP INDEX revision_embeddings_idx
    """

    drop table("revision_embeddings")

  end
end

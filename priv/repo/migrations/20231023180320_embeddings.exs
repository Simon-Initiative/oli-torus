defmodule Oli.Repo.Migrations.Embeddings do
  use Ecto.Migration

  def up do
    create table("revision_embeddings") do

      add :revision_id, references(:revisions)
      add :resource_id, references(:resources)

      add :component_type, :string
      add :chunk_type, :string
      add :chunk_ordinal, :integer
      add :fingerprint_md5, :string
      add :content, :text
      add :embedding, :vector, size: 1551
    end
  end

  def down do
    drop table("revision_embeddings")

  end
end

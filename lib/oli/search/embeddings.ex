defmodule Oli.Search.Embeddings do

  import Ecto.Query, warn: false
  alias Oli.Search.RevisionEmbedding

  alias Oli.Search.EmbeddingWorker
  alias Oli.Resources.Revision
  alias Oli.Publishing.PublishedResource
  alias Oli.Repo

  import Ecto.Query
  import Pgvector.Ecto.Query

  def search(input) do

    case embedding_for_input(input) do
      {:ok, embedding} ->

        query = from i in RevisionEmbedding,
          join: r in Revision, on: r.id == i.revision_id,
          order_by: cosine_distance(i.embedding, ^embedding),
          limit: 5,
          select_merge: %{title: r.title}

        Repo.all(query)

      e -> e
    end
  end

  def most_relevant_pages(input) do

    case embedding_for_input(input) do
      {:ok, embedding} ->

        query = from i in RevisionEmbedding,
          join: r in Revision, on: r.id == i.revision_id,
          order_by: cosine_distance(i.embedding, ^embedding),
          limit: 10,
          select_merge: %{title: r.title}

        most_relevant_revisions = Repo.all(query)
        |> Enum.map(fn %{revision_id: revision_id} -> revision_id end)
        # Dedupe and take 2 gets us the top two most relevant pages
        # [3, 2, 3, 3, 3, 2, 1] -> [3, 2, 3, 2, 1] -> [3, 2]
        |> Enum.dedup()
        |> Enum.take(2)

        query = from i in RevisionEmbedding,
          join: r in Revision, on: r.id == i.revision_id,
          where: i.revision_id in ^most_relevant_revisions,
          order_by: i.chunk_ordinal,
          select_merge: %{title: r.title}

        result = Repo.all(query)
        |> Enum.group_by(fn %{revision_id: revision_id} -> revision_id end)
        |> Enum.map(fn {_revision_id, [first_chunk | _rest] = chunks} ->
          %{revision_id: first_chunk.revision_id, title: first_chunk.title, chunks: chunks}
        end)

        {:ok, result}

      e -> e
    end

  end

  def concat_chunks(chunks) do
    chunks
    |> Enum.map(fn %{content: content} -> content end)
    |> Enum.join("\n\n")
  end

  def embedding_for_input(input) do
    case OpenAI.embeddings([model: "text-embedding-ada-002", input: input], Oli.Conversation.Dialogue.config(:sync)) do
      {:ok, %{data: [result]}} ->

        {:ok, result["embedding"]}

      e ->
        e
    end
  end

  def update_all(publication_id, sync \\ false) do

    revisions_to_embed(publication_id)
    |> Enum.each(fn revision_id ->
      if sync do
        EmbeddingWorker.perform_now(revision_id, publication_id)
      else
        EmbeddingWorker.new(%{revision_id: revision_id, publication_id: publication_id}) |> Oban.insert()
      end
    end)

  end

  defp revisions_to_embed(publication_id) do
    to_embed_query(publication_id)
    |> select([_p, r], r.id)
    |> Repo.all()
  end

  def count_revision_to_embed(publication_id) do
    to_embed_query(publication_id)
    |> select([_p, r], count(r.id))
    |> Repo.one()
  end

  defp to_embed_query(publication_id) do
    page_type_id = Oli.Resources.ResourceType.get_id_by_type("page")

    PublishedResource
    |> join(:left, [p], r in Revision, on: r.id == p.revision_id)
    |> where([p, r], p.publication_id == ^publication_id and r.resource_type_id == ^page_type_id)
  end

end

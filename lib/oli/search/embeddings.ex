defmodule Oli.Search.Embeddings do

  import Ecto.Query, warn: false
  alias Oli.Search.RevisionEmbedding
  alias Oli.Search.MarkdownRenderer
  alias Oli.Search.EmbeddingWorker
  alias Oli.Resources.Revision
  alias Oli.Publishing.PublishedResource
  alias Oli.Repo

  import Ecto.Query
  import Pgvector.Ecto.Query

  def search(input) do
    case OpenAI.embeddings([model: "text-embedding-ada-002", input: input], Oli.Conversation.Dialogue.config(:sync)) do
      {:ok, %{data: [result]}} ->

        embedding = result["embedding"]

        query = from i in RevisionEmbedding,
          join: r in Revision, on: r.id == i.revision_id,
          order_by: l2_distance(i.embedding, ^embedding),
          limit: 5,
          select_merge: %{title: r.title}

        Repo.all(query)

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

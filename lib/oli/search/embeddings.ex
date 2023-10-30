defmodule Oli.Search.Embeddings do

  import Ecto.Query, warn: false
  alias Oli.Search.RevisionEmbedding

  alias Oli.Search.EmbeddingWorker
  alias Oli.Resources.Revision
  alias Oli.Publishing.PublishedResource
  alias Oli.Repo

  import Ecto.Query
  import Pgvector.Ecto.Query


  def search(input, publication_id) do

    case embedding_for_input(input) do
      {:ok, embedding} ->

        query =
          from re in RevisionEmbedding,
          join: pr in PublishedResource, on: re.revision_id == pr.revision_id,
          join: r in Revision, on: r.id == re.revision_id,
          where: pr.publication_id == ^publication_id,
          where: re.chunk_type == :paragraph,
          order_by: cosine_distance(re.embedding, ^embedding),
          limit: 5,
          select_merge: %{title: r.title, distance: cosine_distance(re.embedding, ^embedding)}

        Repo.all(query)

      e -> e
    end
  end

  def most_relevant_pages(input, section_id) do

    case embedding_for_input(input) do
      {:ok, embedding} ->

        query =
          Oli.Delivery.Sections.SectionsProjectsPublications
          |> join(:right, [spp], p in PublishedResource, on: p.publication_id == spp.publication_id)
          |> join(:right, [_spp, pr], re in RevisionEmbedding, on: re.revision_id == pr.revision_id)
          |> join(:left, [_spp, _p, re], r in Revision, on: r.id == re.revision_id)
          |> where([spp, _p, re, _r], spp.section_id == ^section_id and re.chunk_type == :paragraph)
          |> order_by([_spp, _p, re, _r], cosine_distance(re.embedding, ^embedding))
          |> limit(10)
          |> select([_spp, _p, re, _r], re.revision_id)

        most_relevant_revisions = Repo.all(query)
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

  def project_embeddings_summary(publication_id) do

    total_to_embed = count_revision_to_embed(publication_id)

    total_embedded = existing_embedded_query(publication_id)
    |> select([_p, r], count(r.id))
    |> Repo.one()

    total_revisions_embedded = existing_embedded_query(publication_id)
    |> distinct([_p, r, re], re.revision_id)
    |> Repo.all()
    |> length()

    %{
      total_embedded: total_embedded,
      total_revisions_embedded: total_revisions_embedded,
      total_to_embed: total_to_embed
    }
  end

  defp to_embed_query(publication_id) do
    page_type_id = Oli.Resources.ResourceType.get_id_by_type("page")

    PublishedResource
    |> join(:left, [p], r in Revision, on: r.id == p.revision_id)
    |> join(:left, [p, _r], re in RevisionEmbedding, on: p.revision_id == re.revision_id)
    |> where([p, r, re], is_nil(re.revision_id) and p.publication_id == ^publication_id and r.resource_type_id == ^page_type_id)
  end

  defp existing_embedded_query(publication_id) do
    page_type_id = Oli.Resources.ResourceType.get_id_by_type("page")

    PublishedResource
    |> join(:left, [p], r in Revision, on: r.id == p.revision_id)
    |> join(:right, [p, _r], re in RevisionEmbedding, on: p.revision_id == re.revision_id)
    |> where([p, r, re], p.publication_id == ^publication_id and r.resource_type_id == ^page_type_id)
  end



end

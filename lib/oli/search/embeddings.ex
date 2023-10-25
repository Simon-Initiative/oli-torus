defmodule Oli.Search.Embeddings do

  import Ecto.Query, warn: false
  alias Oli.Search.RevisionEmbedding
  alias Oli.Search.MarkdownRenderer
  alias Oli.Search.EmbeddingWorker
  alias Oli.Resources.Revision
  alias Oli.Publishing.PublishedResource
  alias Oli.Repo

  def update_all(publication_id, sync \\ false) do

    revisions_to_embed(publication_id)
    |> Enum.take(5)
    |> Enum.each(fn revision_id ->
      if sync do
        EmbeddingWorker.perform_now(revision_id)
      else
        EmbeddingWorker.new(%{revision_id: revision_id})
      end
    end)

  end

  defp revisions_to_embed(publication_id) do

    page_type_id = Oli.Resources.ResourceType.get_id_by_type("page")

    PublishedResource
    |> join(:left, [p], r in Revision, on: r.id == p.revision_id)
    |> where([p, r], p.publication_id == ^publication_id and r.resource_type_id == ^page_type_id)
    |> select([_p, r], r.id)
    |> Repo.all()
  end

end

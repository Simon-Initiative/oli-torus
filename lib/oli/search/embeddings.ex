defmodule Oli.Search.Embeddings do

  import Ecto.Query, warn: false
  alias Oli.Search.RevisionEmbeddings
  alias Oli.Publishing.PublishedResource
  alias Oli.Repo

  def update_all(publication_id) do





    # Render all changed to markdown "chunks"

    # For each ordinal based chunk:
    #   calculate the md5 hash
    #   lookup in fingerprint map to see if it is still valid
    #   if not:
    #     add to list of "to be calculated" chunks
    #

    # Create an Oban job for each "to be calculated" chunk


    # Embedding structure

    # revision_id
    # resource_type_id (page, activity, objective)
    # component_type (stem, hint, feedback)
    # chunk_type (paragraph, video, image, table, list, etc)
    # chunk_ordinal
    # fingerprint_md5
    # text
    # embedding




  end

  defp embeddings_map_for(publication_id) do

    PublishedResource
    |> join(:right, [p], re in RevisionEmbeddings, on: re.revision_id == p.revision_id)
    |> where([p, _re], p.publication_id == ^publication_id)
    |> select([_, re], %{
      revision_id: re.revision_id,
      chunk_ordinal: re.chunk_ordinal,
      fingerprint_md5: re.fingerprint_md5
    })
    |> Repo.all()
    |> Enum.reduce(%{}, fn %{revision_id: revision_id, chunk_ordinal: chunk_ordinal, fingerprint_md5: fingerprint_md5}, acc ->
      Map.put(acc, {revision_id, chunk_ordinal}, fingerprint_md5)
    end)

  end

  defp revisions_to_embed(publication_id) do
    PublishedResource
    |> join(:left, [p], r in Oli.Resource.Revision, on: r.id == p.revision_id)
    |> where([p, _], p.publication_id == ^publication_id)
    |> select([_, r], r)
    |> Repo.stream()
  end

end

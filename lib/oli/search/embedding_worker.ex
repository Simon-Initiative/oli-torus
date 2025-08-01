defmodule Oli.Search.EmbeddingWorker do
  use Oban.Worker, queue: :embeddings, max_attempts: 3

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Search.MarkdownRenderer
  alias Oli.Resources.Revision
  alias Oli.Search.RevisionEmbedding
  alias Oli.Authoring.Broadcaster

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"revision_id" => revision_id, "publication_id" => publication_id}
      }) do
    perform_now(revision_id, publication_id)
  end

  def perform_now(revision_id, publication_id) do
    result = do_perform(revision_id)

    Broadcaster.broadcast_revision_embedding(publication_id, result)

    result
  end

  defp do_perform(revision_id) do
    revision_id
    |> get_revision()
    |> render_to_chunks()
    |> Enum.map(&reuse_existing_embedding(&1))
    |> calculate_embeddings()
    |> persist()
  end

  defp persist({:ok, revision_embeddings}) do
    attrs =
      Enum.map(revision_embeddings, fn r ->
        Map.delete(r, :__struct__)
        |> Map.delete(:__meta__)
        |> Map.delete(:resource)
        |> Map.delete(:revision)
        |> Map.delete(:title)
        |> Map.delete(:resource_type)
        |> Map.delete(:id)
        |> Map.delete(:updated_at)
        |> Map.delete(:inserted_at)
        |> Map.delete(:distance)
      end)

    expected_num_inserts = Enum.count(attrs)

    case Repo.insert_all(RevisionEmbedding, attrs) do
      {^expected_num_inserts, _} -> :ok
      _ -> {:error, "unexpected number of inserts"}
    end
  end

  defp persist(e), do: e

  # TODO: We will eventually want to front this "one at a time db lookup" with an
  # in memory cache of "fingerprint -> embedding" so that we don't have to hit the db
  defp reuse_existing_embedding(%RevisionEmbedding{fingerprint_md5: fingerprint_md5} = re) do
    result =
      RevisionEmbedding
      |> where([re], re.fingerprint_md5 == ^fingerprint_md5)
      |> select([re], re.embedding)
      |> limit(1)
      |> Repo.all()

    case result do
      [] -> re
      [embedding] -> %{re | embedding: embedding}
    end
  end

  defp calculate_embeddings(revision_embeddings) do
    # split the embeddings into two groups, those that already have embeddings and those that don't
    {haves, have_nots} = Enum.split_with(revision_embeddings, fn re -> !is_nil(re.embedding) end)

    # conditionally call the OpenAI embeddings API, in bulk, for all the revision embeddings that
    # don't already have embeddings
    case have_nots do
      [] ->
        {:ok, haves}

      have_nots ->
        inputs = Enum.map(have_nots, fn re -> re.content end)

        case Oli.OpenAIClient.embeddings(
               [model: "text-embedding-ada-002", input: inputs],
               Oli.Conversation.Dialogue.config(:sync)
             ) do
          {:ok, %{data: data}} ->
            # apply the returned embeddings and combine with the already calculated embeddings
            all =
              Enum.zip(have_nots, data)
              |> Enum.map(fn {re, %{"embedding" => embedding}} ->
                %{re | embedding: embedding}
              end)
              |> Enum.concat(haves)

            {:ok, all}

          e ->
            e
        end
    end
  end

  defp get_revision(revision_id) do
    Repo.get(Revision, revision_id)
  end

  defp render_to_chunks(revision) do
    MarkdownRenderer.to_markdown(revision)
  end
end

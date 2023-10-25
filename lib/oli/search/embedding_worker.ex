defmodule Oli.Search.EmbeddingWorker do
  use Oban.Worker, queue: :embeddings, max_attempts: 3

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Search.MarkdownRenderer
  alias Oli.Resources.Revision
  alias Oli.Search.RevisionEmbedding

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"revision_id" => revision_id}
      }) do
    perform_now(revision_id)
  end

  def perform_now(revision_id) do

    get_revision(revision_id)
    |> render_to_chunks()
    |> Enum.map(&(calculate_fingerprint(&1)))
    |> Enum.map(&(reuse_existing_embedding(&1)))
    |> calculate_embeddings()
    |> persist()

  end

  defp persist({:ok, revision_embeddings}) do
    Repo.insert_all(RevisionEmbedding, revision_embeddings)
  end

  defp persist(e), do: e

  # TODO: We will eventually want to front this "one at a time db lookup" with an
  # in memory cache of "fingerprint -> embedding" so that we don't have to hit the db
  defp reuse_existing_embedding(%RevisionEmbedding{fingerprint_md5: fingerprint_md5} = re) do
    result = RevisionEmbedding
    |> where([re], re.fingerprint_md5 == ^fingerprint_md5)
    |> select([_, re], re.embedding)
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

        case OpenAI.embeddings([model: "text-embedding-ada-002", input: inputs], Oli.Conversation.Dialogue.config(:sync)) do
          {:ok, %{data: data}} ->

            # apply the returned embeddings and combine with the already calculated embeddings
            all = Enum.zip(have_nots, data)
            |> Enum.map(fn {re, %{"embedding" => embedding}} -> %{re | embedding: embedding} end)
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

  defp calculate_fingerprint(%RevisionEmbedding{content: content} = re) do
    %{re | fingerprint_md5: :erlang.md5(content)}
  end

end

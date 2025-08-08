defmodule Oli.Interop.Ingest do
  alias Oli.Interop.Ingest

  # v1 ingest apis in use now implemented using v2 ingest methods

  # ingest project from file for author
  def ingest(file, as_author) do
    %{
      Ingest.State.new()
      | author: as_author,
        force_rollback: true
    }
    |> Ingest.ScalableIngest.unzip(file)
    |> do_ingest()
  end

  # ingest project from unzipped entry list
  def process(entries, author) do
    %{
      Ingest.State.new()
      | entries: entries,
        author: author,
        force_rollback: true
    }
    |> do_ingest()
  end

  defp do_ingest(state) do
    result =
      state
      |> Ingest.Preprocessor.preprocess()
      |> Ingest.Processor.process()

    # v1 ingest returned {:ok, project} on success
    case result do
      {:ok, %Ingest.State{project: project}} -> {:ok, project}
      {:error, %Ingest.State{errors: [err1 | _rest]}} -> {:error, err1}
      _ -> {:error, "An error occurred"}
    end
  end
end

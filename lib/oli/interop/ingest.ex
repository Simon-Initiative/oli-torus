defmodule Oli.Interop.Ingest do
  @moduledoc """
    v1 ingest apis for non-interactive use. Now implemented using v2 ingest methods
  """
  alias Oli.Interop.Ingest

  @doc """
  ingest project from file for author
  Returns {:ok, project} on success and {:error, first_error_string} on failure
  """
  def ingest(file, as_author) do
    %{
      Ingest.State.new()
      | author: as_author,
        force_rollback: true
    }
    |> Ingest.ScalableIngest.unzip(file)
    |> do_ingest()
  end

  @doc """
  ingest project from unzipped entry list for author
  Returns {:ok, project} on success and {:error, first_error_string} on failure
  """
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

    # convert to v1 return
    case result do
      {:ok, %Ingest.State{project: project}} -> {:ok, project}
      {:error, %Ingest.State{errors: [err1 | _rest]}} -> {:error, err1}
      _ -> {:error, "An error occurred"}
    end
  end
end

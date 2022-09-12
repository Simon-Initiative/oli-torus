defmodule Oli.Interop.ScalableIngest do
  alias Oli.Interop.IngestState

  def unzip_then_preprocess(%IngestState{} = state, file) do
    case unzip(state, file) do
      %IngestState{entries: nil} = state -> state
      %IngestState{} = state -> Oli.Interop.IngestPreprocessor.preprocess(state)
    end
  end

  defp unzip(%IngestState{errors: errors} = state, file) do
    state = IngestState.notify_step_start(state, :unzip)

    case :zip.unzip(to_charlist(file), [:memory]) do
      {:ok, entries} ->
        %{state | entries: entries}

      _ ->
        %{state | errors: ["Could not unzip file. Perhaps it is not a valid zip file?" | errors]}
    end
  end
end

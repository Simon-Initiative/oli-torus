defmodule Oli.Interop.Ingest.ScalableIngest do
  alias Oli.Interop.Ingest.State

  def unzip_then_preprocess(%State{} = state, file) do
    case unzip(state, file) do
      %State{entries: nil} = state -> state
      %State{} = state -> Oli.Interop.Ingest.Preprocessor.preprocess(state)
    end
  end

  defp unzip(%State{errors: errors} = state, file) do
    state = State.notify_step_start(state, :unzip)

    case :zip.unzip(to_charlist(file), [:memory]) do
      {:ok, entries} ->
        %{state | entries: entries}

      _ ->
        %{state | errors: ["Could not unzip file. Perhaps it is not a valid zip file?" | errors]}
    end
  end

end

defmodule Oli.Interop.Ingest.ScalableIngest do
  alias Oli.Interop.Ingest.State

  def unzip(%State{} = state, file) do
    state = State.notify_step_start(state, :unzip)

    case :zip.unzip(to_charlist(file), [:memory]) do
      {:ok, entries} ->
        %{state | entries: entries}

      _ ->
        %{state | errors: ["Could not unzip file. Perhaps it is not a valid zip file?"]}
    end
  end
end

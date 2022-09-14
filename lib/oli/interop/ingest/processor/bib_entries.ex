defmodule Oli.Interop.Ingest.Processor.BibEntries do
  alias Oli.Interop.Ingest.State
  import Oli.Interop.Ingest.Processor.Common

  def process(%State{} = state) do
    State.notify_step_start(state, :bib_entries)
    |> create_revisions(
      :bib_entries,
      Oli.Resources.ResourceType.get_id_by_type("bibentry"),
      &standard_mapper/3
    )
  end
end

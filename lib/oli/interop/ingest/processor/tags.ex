defmodule Oli.Interop.Ingest.Processor.Tags do
  alias Oli.Interop.Ingest.State
  import Oli.Interop.Ingest.Processor.Common

  def process(%State{} = state) do
    State.notify_step_start(state, :tags)
    |> create_revisions(
      :tags,
      Oli.Resources.ResourceType.id_for_tag(),
      &standard_mapper/3
    )
  end
end

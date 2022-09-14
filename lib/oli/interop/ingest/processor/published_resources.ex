defmodule Oli.Interop.Ingest.Processor.PublishedResources do
  import Ecto.Query, warn: false
  alias Oli.Interop.Ingest.State
  alias Oli.Resources.Revision

  def process(
        %State{
          publication: publication,
          legacy_to_resource_id_map: legacy_to_resource_id_map
        } = state
      ) do
    State.notify_step_start(state, :published_resources)

    resource_ids = Map.values(legacy_to_resource_id_map)

    query =
      from p in Revision,
        where: p.resource_id in ^resource_ids,
        select: %{
          revision_id: p.id,
          resource_id: p.resource_id,
          inserted_at: p.inserted_at,
          updated_at: p.updated_at,
          publication_id: ^publication.id
        }

    Oli.Repo.insert_all(Oli.Publishing.PublishedResource, query,
      on_conflict: :replace_all,
      conflict_target: [:publication_id, :resource_id, :revision_id]
    )

    state
  end
end

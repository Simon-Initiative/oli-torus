defmodule Oli.Interop.Ingest.Processor.Hyperlinks do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Interop.Ingest.State

  def process(
        %State{project: project, legacy_to_resource_id_map: legacy_to_resource_id_map} = state
      ) do
    State.notify_step_start(state, :hyperlinks)

    resource_id_to_legacy =
      Enum.reduce(legacy_to_resource_id_map, %{}, fn {legacy_id, resource_id}, m ->
        Map.put(m, resource_id, legacy_id)
      end)

    page_map =
      Oli.Publishing.query_unpublished_revisions_by_type(project.slug, "page")
      |> Repo.all()
      |> Enum.reduce(%{}, fn r, m ->
        Map.put(m, Map.get(resource_id_to_legacy, r.resource_id), r)
      end)

    activity_map =
      Oli.Publishing.query_unpublished_revisions_by_type(project.slug, "activity")
      |> Repo.all()
      |> Enum.reduce(%{}, fn r, m ->
        Map.put(m, Map.get(resource_id_to_legacy, r.resource_id), r)
      end)

    {:ok, _} = Oli.Ingest.RewireLinks.rewire_all_hyperlinks(page_map, project, page_map)
    {:ok, _} = Oli.Ingest.RewireLinks.rewire_all_hyperlinks(activity_map, project, page_map)

    state
  end
end

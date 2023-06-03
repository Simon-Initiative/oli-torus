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

    rewire_relates_to(page_map)

    state
  end

  # This rewires the ids in the relates_to field of each page to point to the new resource_id
  # of the page being related to. These ids are already integers (because they had to be
  # to allow the revision to be written in the DB in the first place), so we do need to
  # convert them back to string to be able to look them up in the page_map.
  #
  # A legacy OLI course has no notion of relates_to, so this field is only ever going to be
  # populated by an export from a Torus course, which guarantees that these "string ids" will
  # always actually be integers, as strings - as opposed to a legacy OLI id.
  defp rewire_relates_to(page_map) do

    Map.values(page_map)
    |> Enum.each(fn revision ->
      case revision.relates_to do
        nil -> revision
        [] -> revision
        ids ->
          mapped_ids = Enum.map(ids, fn id ->
            case Map.get(page_map, "#{id}") do
              nil -> nil
              relates_to -> relates_to.resource_id
            end
          end)
          |> Enum.reject(fn id -> is_nil(id) end)

          Oli.Resources.update_revision(revision, %{relates_to: mapped_ids})
      end
    end)
  end
end

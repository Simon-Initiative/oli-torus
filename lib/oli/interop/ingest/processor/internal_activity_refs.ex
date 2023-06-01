defmodule Oli.Interop.Ingest.Processor.InternalActivityRefs do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Interop.Ingest.State

  @doc """
  Makes a pass across all activities to rewire internal activity references. Currently
  the only place this is used is in the flowchart paths, where the destinationScreenId
  is a reference to a resource id of another activity.
  """
  def process(
        %State{project: project, legacy_to_resource_id_map: legacy_to_resource_id_map} = state
      ) do
    State.notify_step_start(state, :internal_activity_refs)

    resource_id_to_legacy =
      Enum.reduce(legacy_to_resource_id_map, %{}, fn {legacy_id, resource_id}, m ->
        Map.put(m, resource_id, legacy_id)
      end)

    activity_map =
      Oli.Publishing.query_unpublished_revisions_by_type(project.slug, "activity")
      |> Repo.all()
      |> Enum.reduce(%{}, fn r, m ->
        Map.put(m, Map.get(resource_id_to_legacy, r.resource_id), r)
      end)

    rewire_all_internal_refs(activity_map)

    state
  end

  def rewire_all_internal_refs(activity_map) do
    Map.values(activity_map)
    |> Enum.map(fn revision ->
      rewire_internal_refs(revision, activity_map)
    end)
  end

  defp rewire_internal_refs(revision, activity_map) do

    try do

      case revision.content do
        %{"authoring" => %{"flowchart" => %{"paths" => paths} = flowchart} = authoring} ->

          if Enum.any?(paths, fn p -> Map.has_key?(p, "destinationScreenId") end) do

            paths = Enum.map(paths, fn path ->
              case path do
                %{"destinationScreenId" => id} ->

                  id_as_str = Integer.to_string(id)
                  Map.put(path, "destinationScreenId", Map.get(activity_map, id_as_str).resource_id)

                other -> other
              end
            end)

            flowchart = Map.put(flowchart, "paths", paths)
            authoring = Map.put(authoring, "flowchart", flowchart)
            content = Map.put(revision.content, "authoring", authoring)

            Oli.Resources.update_revision(revision, %{content: content})

          else
            {:ok, revision}
          end

        _ ->
          {:ok, revision}
      end

    rescue
      _ in KeyError -> {:ok, revision}
    end
  end

end

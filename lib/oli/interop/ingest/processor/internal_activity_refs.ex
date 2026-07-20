defmodule Oli.Interop.Ingest.Processor.InternalActivityRefs do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Interop.Ingest.State

  @doc """
  Makes a pass across all activities to rewire internal activity references.
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
        %{"authoring" => authoring} ->
          authoring =
            authoring
            |> rewire_flowchart(activity_map)
            |> rewire_activities_required_for_evaluation(activity_map)

          content = Map.put(revision.content, "authoring", authoring)

          if content == revision.content do
            {:ok, revision}
          else
            Oli.Resources.update_revision(revision, %{content: content})
          end

        _ ->
          {:ok, revision}
      end
    rescue
      _ in KeyError -> {:ok, revision}
    end
  end

  defp rewire_flowchart(authoring, activity_map) do
    case Map.fetch(authoring, "flowchart") do
      {:ok, flowchart} when is_map(flowchart) ->
        Map.put(authoring, "flowchart", rewire_flowchart_paths(flowchart, activity_map))

      _ ->
        authoring
    end
  end

  defp rewire_flowchart_paths(flowchart, activity_map) do
    case Map.fetch(flowchart, "paths") do
      {:ok, paths} when is_list(paths) ->
        paths =
          Enum.map(paths, fn
            %{"destinationScreenId" => id} = path ->
              case mapped_resource_id(activity_map, id) do
                nil -> path
                resource_id -> Map.put(path, "destinationScreenId", resource_id)
              end

            other ->
              other
          end)

        Map.put(flowchart, "paths", paths)

      _ ->
        flowchart
    end
  end

  defp rewire_activities_required_for_evaluation(authoring, activity_map) do
    case Map.fetch(authoring, "activitiesRequiredForEvaluation") do
      {:ok, ids} when is_list(ids) ->
        ids = Enum.map(ids, fn id -> mapped_resource_id(activity_map, id) || id end)
        Map.put(authoring, "activitiesRequiredForEvaluation", ids)

      _ ->
        authoring
    end
  end

  defp mapped_resource_id(activity_map, id) do
    activity_map
    |> get_mapped_activity(id)
    |> case do
      nil -> nil
      revision -> revision.resource_id
    end
  end

  defp get_mapped_activity(activity_map, id) do
    case Map.get(activity_map, id) do
      nil ->
        case id do
          integer when is_integer(integer) ->
            Map.get(activity_map, Integer.to_string(integer))

          binary when is_binary(binary) ->
            case Integer.parse(binary) do
              {integer, ""} -> Map.get(activity_map, integer)
              _ -> nil
            end

          _ ->
            nil
        end

      activity ->
        activity
    end
  end
end

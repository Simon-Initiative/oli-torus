defmodule Oli.Interop.Ingest.Processor.Activities do
  alias Oli.Interop.Ingest.State
  import Oli.Interop.Ingest.Processor.Common

  def process(%State{} = state) do
    State.notify_step_start(state, :activities)
    |> create_revisions(
      :activities,
      Oli.Resources.ResourceType.get_id_by_type("activity"),
      &mapper/3
    )
  end

  defp mapper(state, resource_id, resource) do
    legacy_id = Map.get(resource, "legacyId", nil)
    legacy_path = Map.get(resource, "legacyPath", nil)

    title =
      case Map.get(resource, "title") do
        nil -> Map.get(resource, "subType")
        "" -> Map.get(resource, "subType")
        title -> title
      end

    scope =
      case Map.get(resource, "scope", "embedded") do
        str when str in ~w(embedded banked) -> String.to_existing_atom(str)
        _ -> :embedded
      end

    %{
      slug: Oli.Utils.Slug.slug_with_prefix(state.slug_prefix, title),
      legacy: %Oli.Resources.Legacy{id: legacy_id, path: legacy_path},
      resource_id: resource_id,
      scope: scope,
      tags: transform_tags(resource, state.legacy_to_resource_id_map),
      title: title,
      objectives: process_activity_objectives(resource, state.legacy_to_resource_id_map),
      content: Map.get(resource, "content"),
      author_id: {:placeholder, :author_id},
      children: {:placeholder, :children},
      resource_type_id: {:placeholder, :resource_type_id},
      activity_type_id: Map.get(state.registration_by_subtype, Map.get(resource, "subType")),
      scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
      inserted_at: {:placeholder, :now},
      updated_at: {:placeholder, :now}
    }
  end

  defp process_activity_objectives(activity, objective_map) do
    case Map.get(activity, "objectives", []) do
      map when is_map(map) ->
        Map.keys(map)
        |> Enum.reduce(%{}, fn k, m ->
          mapped =
            Map.get(activity, "objectives")[k]
            |> MapSet.new()
            |> MapSet.to_list()
            |> Enum.map(fn id ->
              case Map.get(objective_map, id) do
                nil ->
                  IO.inspect("Missing objective #{id}")
                  nil

                o ->
                  o
              end
            end)
            |> Enum.filter(fn id -> !is_nil(id) end)

          Map.put(m, k, mapped)
        end)

      list when is_list(list) ->
        activity["content"]["authoring"]["parts"]
        |> Enum.map(fn %{"id" => id} -> id end)
        |> Enum.reduce(%{}, fn e, m ->
          objectives =
            MapSet.new(list)
            |> MapSet.to_list()
            |> Enum.map(fn id ->
              case Map.get(objective_map, id) do
                nil ->
                  IO.inspect("Missing objective #{id}")
                  nil

                o ->
                  o
              end
            end)
            |> Enum.filter(fn id -> !is_nil(id) end)

          Map.put(m, e, objectives)
        end)
    end
  end
end

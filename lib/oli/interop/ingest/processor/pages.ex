defmodule Oli.Interop.Ingest.Processor.Pages do
  alias Oli.Interop.Ingest.State
  alias Oli.Interop.Ingest.Processing.Rewiring
  import Oli.Interop.Ingest.Processor.Common

  def process(%State{} = state) do
    State.notify_step_start(state, :pages)
    |> create_revisions(
      :pages,
      Oli.Resources.ResourceType.get_id_by_type("page"),
      &mapper/3
    )
  end

  defp mapper(state, resource_id, resource) do
    legacy_id = Map.get(resource, "legacyId", nil)
    legacy_path = Map.get(resource, "legacyPath", nil)

    title =
      case Map.get(resource, "title") do
        nil -> "Missing title"
        "" -> "Empty title"
        title -> title
      end

    graded = Map.get(resource, "isGraded", false)

    content = Map.get(resource, "content")

    content =
      Rewiring.rewire_activity_references(content, state.legacy_to_resource_id_map)
      |> Rewiring.rewire_bank_selections(state.legacy_to_resource_id_map)
      |> Rewiring.rewire_citation_references(state.legacy_to_resource_id_map)

    %{
      legacy: %Oli.Resources.Legacy{id: legacy_id, path: legacy_path},
      resource_id: resource_id,
      tags: transform_tags(resource, state.legacy_to_resource_id_map),
      title: title,
      objectives: %{
        "attached" =>
          Enum.map(resource["objectives"], fn id ->
            case Map.get(state.legacy_to_resource_id_map, id) do
              nil -> nil
              id -> id
            end
          end)
          |> Enum.filter(fn f -> !is_nil(f) end)
      },
      content: content,
      author_id: {:placeholder, :author_id},
      children: {:placeholder, :children},
      resource_type_id: {:placeholder, :resource_type_id},
      activity_type_id: Map.get(state.registration_by_subtype, Map.get(resource, "subType")),
      scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
      graded: graded,
      max_attempts:
        if graded do
          5
        else
          0
        end,
      inserted_at: {:placeholder, :now},
      updated_at: {:placeholder, :now}
    }
  end
end

defmodule Oli.Interop.Ingest.Processor.Objectives do
  alias Oli.Interop.Ingest.State
  import Oli.Interop.Ingest.Processor.Common

  def process(%State{} = state) do
    without_children = fn {_, o} -> Map.get(o, "objectives", []) |> Enum.count() == 0 end
    with_children = fn {_, o} -> Map.get(o, "objectives", []) |> Enum.count() > 0 end

    objective_type_id = Oli.Resources.ResourceType.id_for_objective()

    State.notify_step_start(state, :objectives)
    |> create_revisions(:objectives, objective_type_id, &mapper/3, without_children)
    |> create_revisions(:objectives, objective_type_id, &mapper/3, with_children)
  end

  defp mapper(state, resource_id, resource) do
    legacy_id = Map.get(resource, "legacyId", nil)
    legacy_path = Map.get(resource, "legacyPath", nil)
    parameters = Map.get(resource, "parameters", nil)
    title = Map.get(resource, "title", "missing title")

    %{
      slug: Oli.Utils.Slug.slug_with_prefix(state.slug_prefix, title),
      legacy: %Oli.Resources.Legacy{id: legacy_id, path: legacy_path},
      resource_id: resource_id,
      parameters: parameters,
      tags: transform_tags(resource, state.legacy_to_resource_id_map),
      title: title,
      objectives: {:placeholder, :objectives},
      content: {:placeholder, :content},
      author_id: {:placeholder, :author_id},
      children:
        Map.get(resource, "objectives", [])
        |> Enum.map(fn id -> Map.get(state.legacy_to_resource_id_map, id) end),
      resource_type_id: {:placeholder, :resource_type_id},
      inserted_at: {:placeholder, :now},
      updated_at: {:placeholder, :now}
    }
  end
end

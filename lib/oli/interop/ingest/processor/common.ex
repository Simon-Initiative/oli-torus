defmodule Oli.Interop.Ingest.Processor.Common do
  alias Oli.Interop.Ingest.State
  alias Oli.Resources.Revision
  alias Oli.Repo

  @doc """
  Bulk creates revisions for a particular resource type from the ingest state. The resource
  type is specified as an atom via the `resource_key` argument (e.g. `:tags`, `:activities`, etc) and
  matches the keys that are present in the ingest state struct.
  """
  def create_revisions(
        %State{author: author} = state,
        resource_key,
        resource_type_id,
        mapper_fn,
        filter_fn \\ fn _ -> true end
      ) do
    # Get the {legacy_id, resource JSON} pairs from the state and filter them
    resources = Map.get(state, resource_key) |> Enum.filter(fn r -> filter_fn.(r) end)

    # Take the necessary amount of resource_ids from the pre-allocated collection of resource id records
    count = Enum.count(resources)
    {state, ids} = take_ids(state, count)

    # Construct the bulk insert payloads, using the supplied mapper function to allow proper creation of the
    # payload map per the needs of each resource type
    payload =
      Enum.zip(ids, resources)
      |> Enum.map(fn {resource_id, {_, resource}} -> mapper_fn.(state, resource_id, resource) end)

    Repo.insert_all(Revision, payload, placeholders: create_placeholders(author, resource_type_id))

    # Finish by updating the `:legacy_to_resource_id_map` to track which resource ids were just allocated to
    # which legacy ids
    state
    |> augment_id_mapping(ids, resources)
  end

  # Take a batch of pre-allocated resource_ids from our pool of resource ids.
  defp take_ids(%State{resource_id_pool: pool} = state, count) do
    ids = Enum.take(pool, count)

    {%{state | resource_id_pool: Enum.drop(pool, count)}, ids}
  end

  # Update the mapping of legacy id to resource id. This map is key to allowing internal references to
  # be updated as we proceed thru processing. For example, this map is used to allow the legacy ids present
  # in the `"objectives"` key of an activity JSON to be updated with the correct resource_id for those
  # objectives.
  defp augment_id_mapping(
         %State{legacy_to_resource_id_map: legacy_to_resource_id_map} = state,
         resource_ids,
         id_resource_pairs
       ) do
    additional =
      Enum.zip(resource_ids, id_resource_pairs)
      |> Enum.reduce(%{}, fn {resource_id, {id, _}}, m ->
        Map.put(m, id, resource_id)
      end)

    %{state | legacy_to_resource_id_map: Map.merge(legacy_to_resource_id_map, additional)}
  end

  defp create_placeholders(author, resource_type_id) do
    %{
      now: DateTime.utc_now() |> DateTime.truncate(:second),
      resource_type_id: resource_type_id,
      objectives: %{},
      author_id: author.id,
      content: %{},
      children: [],
      tags: []
    }
  end

  def standard_mapper(%State{slug_prefix: slug_prefix}, resource_id, resource) do
    legacy_id = Map.get(resource, "legacyId", nil)
    legacy_path = Map.get(resource, "legacyPath", nil)
    title = Map.get(resource, "title", "missing title")

    %{
      slug: Oli.Utils.Slug.slug_with_prefix(slug_prefix, title),
      legacy: %Oli.Resources.Legacy{id: legacy_id, path: legacy_path},
      resource_id: resource_id,
      tags: {:placeholder, :tags},
      title: title,
      content: {:placeholder, :content},
      author_id: {:placeholder, :author_id},
      objectives: {:placeholder, :objectives},
      resource_type_id: {:placeholder, :resource_type_id},
      inserted_at: {:placeholder, :now},
      updated_at: {:placeholder, :now}
    }
  end

  def transform_tags(value, tag_map) do
    Map.get(value, "tags", [])
    |> Enum.map(fn id ->
      case Map.get(tag_map, id) do
        nil -> nil
        id -> id
      end
    end)
    |> Enum.filter(fn id -> !is_nil(id) end)
  end
end

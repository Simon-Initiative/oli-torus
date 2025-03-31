defmodule Oli.Interop.Ingest.Processor.Hierarchy do
  alias Oli.Interop.Ingest.State
  import Oli.Interop.Ingest.Processor.Common
  alias Oli.Publishing.ChangeTracker

  @doc """
  We cannot (easily) bulk allocate containers, because of how many
  dependencies there are between them.  So instead, we continue with the
  'create one record at a time' approach.
  """
  def process(
        %State{
          root_revision: root_revision,
          author: as_author,
          project: project,
          hierarchy: hierarchy_details,
          legacy_to_resource_id_map: legacy_to_resource_id_map,
          container_id_map: container_id_map
        } = state
      ) do
    State.notify_step_start(state, :hierarchy)

    # Process top-level items and containers, add recursively add container
    {container_id_map, children} =
      Map.get(hierarchy_details, "children")
      |> Enum.filter(fn c -> c["type"] == "item" || c["type"] == "container" end)
      |> Enum.reduce({container_id_map, []}, fn c, {container_id_map, children} ->
        case Map.get(c, "type") do
          "item" ->
            {container_id_map,
             children ++ [Map.get(legacy_to_resource_id_map, Map.get(c, "idref"))]}

          "container" ->
            {container_id_map, id} =
              create_container(project, container_id_map, legacy_to_resource_id_map, as_author, c)

            {container_id_map, children ++ [id]}
        end
      end)

    labels =
      Map.get(hierarchy_details, "children")
      |> Enum.filter(fn c -> c["type"] == "labels" end)
      |> Enum.reduce(%{}, fn item, acc ->
        Map.merge(acc, %{
          unit: Map.get(item, "unit"),
          module: Map.get(item, "module"),
          section: Map.get(item, "section")
        })
      end)

    custom_labels =
      case Map.equal?(labels, %{}) do
        true -> nil
        _ -> labels
      end

    {:ok, updated_project} =
      Oli.Authoring.Course.update_project(project, %{customizations: custom_labels})

    # wire those newly created top-level containers into the root resource
    ChangeTracker.track_revision(project.slug, root_revision, %{children: children})

    %{state | container_id_map: container_id_map, project: updated_project}
  end

  # This is the recursive container creation routine.  It processes a hierarchy by
  # descending through the tree and processing the leaves first, and then back upwards.
  defp create_container(
         project,
         container_id_map,
         legacy_to_resource_id_map,
         as_author,
         container
       ) do
    # recursively visit item container in the hierarchy, and via bottom
    # up approach create resource and revisions for each container, while
    # substituting page references for resource ids and container references
    # for container resource ids

    {container_id_map, children_ids} =
      Map.get(container, "children")
      |> Enum.reduce({container_id_map, []}, fn c, {container_id_map, children} ->
        case Map.get(c, "type") do
          "item" ->
            p = Map.get(legacy_to_resource_id_map, Map.get(c, "idref"))
            {container_id_map, children ++ [p]}

          "container" ->
            {container_id_map, id} =
              create_container(project, container_id_map, legacy_to_resource_id_map, as_author, c)

            {container_id_map, children ++ [id]}
        end
      end)

    attrs = %{
      tags: transform_tags(container, legacy_to_resource_id_map),
      title: Map.get(container, "title"),
      intro_content: Map.get(container, "intro_content", %{}),
      intro_video: Map.get(container, "intro_video"),
      poster_image: Map.get(container, "poster_image"),
      children: children_ids,
      author_id: as_author.id,
      content: %{"model" => []},
      resource_type_id: Oli.Resources.ResourceType.id_for_container()
    }

    {:ok, %{revision: revision}} = Oli.Authoring.Course.create_and_attach_resource(project, attrs)
    {:ok, _} = ChangeTracker.track_revision(project.slug, revision)

    container_id_map = Map.put(container_id_map, Map.get(container, "id", UUID.uuid4()), revision)

    {container_id_map, revision.resource_id}
  end
end

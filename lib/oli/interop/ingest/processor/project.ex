defmodule Oli.Interop.Ingest.Processor.Project do
  alias Oli.Interop.Ingest.State
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Resources.ResourceType

  def process(
        %State{
          project_details: project_details,
          author: author,
          legacy_to_resource_id_map: legacy_to_resource_id_map
        } = state
      ) do
    State.notify_step_start(state, :project)

    title =
      case Map.get(project_details, "title") do
        nil ->
          {:error, "Missing project title"}

        "" ->
          {:error, "Missing project title"}

        title ->
          title
      end

    {:ok, %{project: project, publication: publication, resource_revision: root_revision}} =
      Oli.Authoring.Course.create_project(title, author, %{
        description: Map.get(project_details, "description"),
        legacy_svn_root: Map.get(project_details, "svnRoot")
      })

    # create alternatives groups
    {:ok, legacy_to_resource_id_map} =
      case Map.get(project_details, "alternativesGroups") do
        nil ->
          {:ok, legacy_to_resource_id_map}

        alternatives_groups ->
          legacy_to_resource_id_map =
            Enum.reduce(alternatives_groups, legacy_to_resource_id_map, fn {name, values}, acc ->
              options = Enum.map(values, fn value -> %{"id" => value, "name" => value} end)

              {:ok, group} =
                ResourceEditor.create(
                  project.slug,
                  author,
                  ResourceType.get_id_by_type("alternatives"),
                  %{title: name, content: %{"options" => options}}
                )

              Map.put_new(acc, name, group.resource_id)
            end)

          {:ok, legacy_to_resource_id_map}
      end

    %{
      state
      | project: project,
        publication: publication,
        root_revision: root_revision,
        legacy_to_resource_id_map: legacy_to_resource_id_map
    }
  end
end

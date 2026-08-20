defmodule Oli.Interop.Ingest.Processor.Project do
  alias Oli.Interop.Ingest.State
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Resources.ResourceType
  alias Oli.LearningModel.ModelVersion
  alias Oli.Repo

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

    learning_model_version =
      case ModelVersion.decode_archive(
             Map.get(project_details, "learningModelVersion"),
             :naive
           ) do
        {:ok, learning_model_version} ->
          learning_model_version

        {:error, _reason} ->
          rollback_invalid_model_version(state, "_project.json", project_details)
      end

    {:ok, %{project: project, publication: publication, resource_revision: root_revision}} =
      Oli.Authoring.Course.create_project_from_archive(
        title,
        author,
        learning_model_version,
        %{
          description: Map.get(project_details, "description"),
          legacy_svn_root: Map.get(project_details, "svnRoot"),
          attributes: Map.get(project_details, "attributes"),
          welcome_title: Map.get(project_details, "welcomeTitle"),
          encouraging_subtitle: Map.get(project_details, "encouragingSubtitle")
        }
      )

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
                  ResourceType.id_for_alternatives(),
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

  defp rollback_invalid_model_version(state, file, resource) do
    value = Map.get(resource, "learningModelVersion")

    error =
      "Invalid learningModelVersion in #{file}: expected \"naive\", \"lkt_aoa\", or null; got #{inspect(value, limit: 3, printable_limit: 80)}"

    Repo.rollback(%{state | errors: [error | state.errors]})
  end
end

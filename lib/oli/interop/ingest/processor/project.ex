defmodule Oli.Interop.Ingest.Processor.Project do
  alias Oli.Interop.Ingest.State

  def process(%State{project_details: project_details, author: author} = state) do
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

    %{state | project: project, publication: publication, root_revision: root_revision}
  end
end

defmodule Oli.Interop.ExportTest do
  use OliWeb.ConnCase

  alias Oli.Interop.Export
  import Oli.Factory

  describe "export" do
    setup [:setup_project_with_survey]

    test "project export preserves student surveys", %{project: project} do
      export = Export.export(project)
      |> unzip_to_memory()
      |> Enum.reduce(%{}, fn {f, c}, m -> Map.put(m, f, c) end)

      {:ok, project_json} = Jason.decode(Map.get(export, '_project.json'))

      assert project_json["required_student_survey"] == Integer.to_string(project.required_survey_resource_id)
    end
  end

  def setup_project_with_survey(_) do
    author = insert(:author)

    survey_revision =
      insert(:revision, resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"))

    project =
      insert(:project,
        slug: "project_with_survey",
        required_survey_resource_id: survey_revision.resource.id,
        authors: [author]
      )

    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container")
      })

    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_revision.resource.id,
        published: nil
      })

    insert(:published_resource, %{
      publication: publication,
      resource: survey_revision.resource,
      revision: survey_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: container_revision.resource,
      revision: container_revision,
      author: author
    })

    insert(:project_resource, %{project_id: project.id, resource_id: survey_revision.resource.id})

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: container_revision.resource.id
    })

    {:ok, project: project}
  end
end

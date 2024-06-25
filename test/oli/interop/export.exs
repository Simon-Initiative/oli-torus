defmodule Oli.Interop.ExportTest do
  use OliWeb.ConnCase

  alias Oli.Interop.Export
  import Oli.Factory

  describe "export" do
    setup [:setup_project_with_survey]

    test "project export preserves student surveys", %{project: project} do
      export =
        Export.export(project)
        |> unzip_to_memory()
        |> Enum.reduce(%{}, fn {f, c}, m -> Map.put(m, f, c) end)

      {:ok, project_json} = Jason.decode(Map.get(export, ~c"_project.json"))

      assert project_json["required_student_survey"] ==
               Integer.to_string(project.required_survey_resource_id)
    end

    test "project export preserves attributes", %{project: project} do
      export =
        Export.export(project)
        |> unzip_to_memory()
        |> Enum.reduce(%{}, fn {f, c}, m -> Map.put(m, f, c) end)

      {:ok, project_json} = Jason.decode(Map.get(export, ~c"_project.json"))

      # Check that learning language in the project attributes is preserved
      assert project_json["attributes"]["learning_language"] ==
               project.attributes.learning_language
    end

    test "project export preserves customizations", %{project: project} do
      export =
        Export.export(project)
        |> unzip_to_memory()
        |> Enum.reduce(%{}, fn {f, c}, m -> Map.put(m, f, c) end)

      {:ok, hierarchy_json} = Jason.decode(Map.get(export, ~c"_hierarchy.json"))

      [type_labels] =
        hierarchy_json["children"] |> Enum.filter(&(&1["type"] == "labels"))

      # Check that customizations in the project are preserved
      assert type_labels["unit"] == project.customizations.unit

      assert type_labels["module"] == project.customizations.module

      assert type_labels["section"] == project.customizations.section
    end

    test "project export preserves welcome title and encouraging subtitle", %{project: project} do
      export =
        Export.export(project)
        |> unzip_to_memory()
        |> Enum.reduce(%{}, fn {f, c}, m -> Map.put(m, f, c) end)

      {:ok, project_json} = Jason.decode(Map.get(export, ~c"_project.json"))

      assert project_json["welcomeTitle"] == %{"test" => "test"}
      assert project_json["encouragingSubtitle"] == "Subtitle test"
    end
  end

  def setup_project_with_survey(_) do
    author = insert(:author)

    survey_revision =
      insert(:revision, resource_type_id: Oli.Resources.ResourceType.id_for_page())

    project =
      insert(:project,
        slug: "project_with_survey",
        required_survey_resource_id: survey_revision.resource.id,
        authors: [author],
        attributes: %{learning_language: "es"},
        customizations: %{
          unit: "Unit_Example",
          module: "Module_Example",
          section: "Section_Example"
        },
        welcome_title: %{test: "test"},
        encouraging_subtitle: "Subtitle test"
      )

    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_container()
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

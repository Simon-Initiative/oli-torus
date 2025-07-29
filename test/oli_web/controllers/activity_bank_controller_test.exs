defmodule OliWeb.ActivityBankControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  setup [:project_seed]

  describe "preview" do
    test "can preview activity bank selection", %{conn: conn, project: project} do
      # Preload the authors association
      project = Oli.Repo.preload(project, :authors)

      # Create a section for the project
      section = insert(:section, base_project: project, open_and_free: true)

      # Create a page with a selection
      page_revision =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Test Page",
          content: %{
            "model" => [
              %{
                "type" => "selection",
                "id" => "test_selection",
                "logic" => %{"conditions" => nil},
                "count" => 2
              }
            ]
          }
        )

      # Associate page to the project
      insert(:project_resource, %{project_id: project.id, resource_id: page_revision.resource.id})

      # Create some banked activities
      mcq_reg = Oli.Activities.get_registration_by_slug("oli_multiple_choice")

      activity1 =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_activity(),
          activity_type_id: mcq_reg.id,
          title: "Activity 1",
          content: %{"model" => %{"stem" => "Test activity 1"}},
          scope: :banked
        )

      activity2 =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_activity(),
          activity_type_id: mcq_reg.id,
          title: "Activity 2",
          content: %{"model" => %{"stem" => "Test activity 2"}},
          scope: :banked
        )

      # Associate activities to the project
      insert(:project_resource, %{project_id: project.id, resource_id: activity1.resource.id})
      insert(:project_resource, %{project_id: project.id, resource_id: activity2.resource.id})

      # Create publication and publish resources
      publication =
        insert(:publication, %{project: project, root_resource_id: page_revision.resource.id})

      insert(:published_resource, %{
        publication: publication,
        resource: page_revision.resource,
        revision: page_revision,
        author: project.authors |> List.first()
      })

      insert(:published_resource, %{
        publication: publication,
        resource: activity1.resource,
        revision: activity1,
        author: project.authors |> List.first()
      })

      insert(:published_resource, %{
        publication: publication,
        resource: activity2.resource,
        revision: activity2,
        author: project.authors |> List.first()
      })

      # Create section resources
      {:ok, section} = Oli.Delivery.Sections.create_section_resources(section, publication)

      # Make the author an instructor of the section
      author = project.authors |> List.first()
      user = insert(:user, author: author)

      Oli.Delivery.Sections.enroll(user.id, section.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
      ])

      conn = conn |> log_in_user(user)

      conn =
        get(
          conn,
          Routes.activity_bank_path(
            conn,
            :preview,
            section.slug,
            page_revision.slug,
            "test_selection"
          )
        )

      # This should fail with the KeyError for :has_scheduled_resources?
      assert html_response(conn, 200)
    end

    test "returns error when not authorized", %{conn: conn, project: project} do
      # Preload the authors association
      project = Oli.Repo.preload(project, :authors)

      # Create a section for the project
      section = insert(:section, base_project: project, open_and_free: true)

      # Create a page with a selection
      page_revision =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Test Page",
          content: %{
            "model" => [
              %{
                "type" => "selection",
                "id" => "test_selection",
                "logic" => %{"conditions" => nil},
                "count" => 2
              }
            ]
          }
        )

      # Associate page to the project
      insert(:project_resource, %{project_id: project.id, resource_id: page_revision.resource.id})

      # Create publication and publish resources
      publication =
        insert(:publication, %{project: project, root_resource_id: page_revision.resource.id})

      insert(:published_resource, %{
        publication: publication,
        resource: page_revision.resource,
        revision: page_revision,
        author: project.authors |> List.first()
      })

      # Create section resources
      {:ok, section} = Oli.Delivery.Sections.create_section_resources(section, publication)

      # Don't make the author an instructor
      conn =
        get(
          conn,
          Routes.activity_bank_path(
            conn,
            :preview,
            section.slug,
            page_revision.slug,
            "test_selection"
          )
        )

      assert response(conn, 403)
    end
  end

  def project_seed(%{conn: conn}) do
    map = Oli.Seeder.base_project_with_resource2()

    conn =
      log_in_author(
        conn,
        map.author
      )

    {:ok, Map.merge(%{conn: conn}, map)}
  end
end

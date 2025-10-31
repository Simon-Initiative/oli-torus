defmodule OliWeb.ActivityBankControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  setup [:project_seed]

  describe "index" do
    test "can launch activity bank editor", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/activity_bank")

      render_hook(view, "survey_scripts_loaded", %{})

      assert render(view) =~ "Activity Bank"
    end

    test "shows revision history link for admin users", %{conn: conn, project: project} do
      admin_author =
        insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().system_admin)

      conn = conn |> log_in_author(admin_author)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/activity_bank")

      render_hook(view, "survey_scripts_loaded", %{})

      assert render(view) =~ "&quot;revisionHistoryLink&quot;:true"
    end

    test "does not show revision history link for non-admin users", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/activity_bank")

      render_hook(view, "survey_scripts_loaded", %{})

      assert render(view) =~ "&quot;revisionHistoryLink&quot;:false"
    end

    test "returns not found for non-existent project", %{conn: conn} do
      {:error, {:redirect, %{to: to}}} =
        live(conn, ~p"/workspaces/course_author/non-existent-project/activity_bank")

      assert to == "/workspaces/course_author"
    end
  end

  describe "preview" do
    test "can preview activity bank selection", %{conn: conn, project: project} do
      project = Oli.Repo.preload(project, :authors)

      section = insert(:section, base_project: project, open_and_free: true)

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

      insert(:project_resource, %{project_id: project.id, resource_id: page_revision.resource.id})

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

      insert(:project_resource, %{project_id: project.id, resource_id: activity1.resource.id})
      insert(:project_resource, %{project_id: project.id, resource_id: activity2.resource.id})

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

      {:ok, section} = Oli.Delivery.Sections.create_section_resources(section, publication)

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

      assert html_response(conn, 200)

      assert html_response(conn, 200) =~ "Activity Bank Selection"
      assert html_response(conn, 200) =~ "2 activities"
    end

    test "returns error when not authorized", %{conn: conn, project: project} do
      project = Oli.Repo.preload(project, :authors)

      section = insert(:section, base_project: project, open_and_free: true)

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

      insert(:project_resource, %{project_id: project.id, resource_id: page_revision.resource.id})

      publication =
        insert(:publication, %{project: project, root_resource_id: page_revision.resource.id})

      insert(:published_resource, %{
        publication: publication,
        resource: page_revision.resource,
        revision: page_revision,
        author: project.authors |> List.first()
      })

      {:ok, section} = Oli.Delivery.Sections.create_section_resources(section, publication)

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

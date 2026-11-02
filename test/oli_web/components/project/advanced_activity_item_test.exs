defmodule OliWeb.Components.Project.AdvancedActivityItemTest do
  use OliWeb.ConnCase
  import Phoenix.LiveViewTest
  import Oli.Factory
  import LiveComponentTests

  describe "AdvancedActivityItem" do
    setup do
      project = insert(:project)

      activity =
        insert(:activity_registration, %{
          title: "Test Activity",
          globally_visible: true
        })

      author = insert(:author)
      collaboration = insert(:author_project, project_id: project.id, author_id: author.id)

      [
        project: project,
        activity: activity,
        author: author,
        collaboration: collaboration
      ]
    end

    test "renders activity information correctly", %{
      conn: conn,
      project: project,
      activity: activity,
      author: author
    } do
      {:ok, lcd, html} =
        live_component_isolated(
          conn,
          OliWeb.Components.Project.AdvancedActivityItem,
          id: "test-item",
          activity: activity,
          project: project,
          current_author: author
        )

      assert html =~ activity.title
      assert has_element?(lcd, "div", activity.title)
    end

    test "shows deployment ID for LTI activities", %{conn: conn, project: project, author: author} do
      lti_activity =
        insert(:activity_registration, %{
          title: "LTI Activity",
          delivery_element: "lti-external-tool-delivery",
          authoring_element: "lti-external-tool-authoring"
        })

      deployment =
        insert(:lti_external_tool_activity_deployment, %{
          activity_registration: lti_activity,
          status: :enabled
        })

      activity_with_deployment = %{lti_activity | deployment_id: deployment.deployment_id}

      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Components.Project.AdvancedActivityItem,
          id: "test-item",
          activity: activity_with_deployment,
          project: project,
          current_author: author
        )

      assert has_element?(lcd, "span", "Deployment Id: #{deployment.deployment_id}")
    end

    test "shows enable button for disabled activities", %{
      conn: conn,
      project: project,
      activity: activity,
      author: author
    } do
      disabled_activity = %{activity | project_status: :disabled}

      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Components.Project.AdvancedActivityItem,
          id: "test-item",
          activity: disabled_activity,
          project: project,
          current_author: author
        )

      assert has_element?(lcd, "button", "Enable")
    end

    test "shows disable button for enabled activities", %{
      conn: conn,
      project: project,
      activity: activity,
      author: author
    } do
      enabled_activity = %{activity | project_status: :enabled}

      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Components.Project.AdvancedActivityItem,
          id: "test-item",
          activity: enabled_activity,
          project: project,
          current_author: author
        )

      assert has_element?(lcd, "button", "Disable")
    end

    test "enables activity when enable button is clicked", %{
      conn: conn,
      project: project,
      activity: activity,
      author: author
    } do
      # Add activity to project with disabled status
      insert(:activity_registration_project, %{
        activity_registration_id: activity.id,
        project_id: project.id,
        status: :disabled
      })

      disabled_activity = %{activity | project_status: :disabled}

      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Components.Project.AdvancedActivityItem,
          id: "test-item",
          activity: disabled_activity,
          project: project,
          current_author: author
        )

      # Click enable button
      lcd
      |> element("button", "Enable")
      |> render_click()

      # Should update the activity status in the component
      assert has_element?(lcd, "button", "Disable")
    end

    test "disables activity when disable button is clicked", %{
      conn: conn,
      project: project,
      activity: activity,
      author: author
    } do
      # Add activity to project with enabled status
      insert(:activity_registration_project, %{
        activity_registration_id: activity.id,
        project_id: project.id,
        status: :enabled
      })

      enabled_activity = %{activity | project_status: :enabled}

      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Components.Project.AdvancedActivityItem,
          id: "test-item",
          activity: enabled_activity,
          project: project,
          current_author: author
        )

      # Click disable button
      lcd
      |> element("button", "Disable")
      |> render_click()

      # Should update the activity status in the component
      assert has_element?(lcd, "button", "Enable")
    end

    test "toggles its own row when the event names another project", %{
      conn: conn,
      project: project,
      activity: activity,
      author: author
    } do
      other_project = insert(:project)
      own_row = enabled_row(activity, project)
      other_project_row = enabled_row(activity, other_project)

      {:ok, lcd, _html} = mount_item(conn, activity, project, author)

      lcd
      |> element("button", "Disable")
      |> render_click(%{"project_id" => other_project.id})

      assert row_status(other_project_row) == :enabled
      assert row_status(own_row) == :disabled
    end

    test "toggles its own row when the event names another activity", %{
      conn: conn,
      project: project,
      activity: activity,
      author: author
    } do
      admin_only = insert(:activity_registration, %{title: "Admin Only", globally_visible: false})
      own_row = enabled_row(activity, project)
      admin_only_row = enabled_row(admin_only, project)

      {:ok, lcd, _html} = mount_item(conn, activity, project, author)

      lcd
      |> element("button", "Disable")
      |> render_click(%{"activity_id" => admin_only.id, "title" => "Admin Only"})

      assert row_status(admin_only_row) == :enabled
      assert row_status(own_row) == :disabled
      assert has_element?(lcd, "div", "Test Activity")
    end

    test "uses its own status and title when the event names others", %{
      conn: conn,
      project: project,
      activity: activity,
      author: author
    } do
      own_row = enabled_row(activity, project)

      {:ok, lcd, _html} = mount_item(conn, activity, project, author)

      test_pid = self()

      live_component_intercept(lcd, fn
        {:flash_message, message}, socket ->
          send(test_pid, {:flash_message, message})
          {:cont, socket}

        _other, socket ->
          {:cont, socket}
      end)

      lcd
      |> element("button", "Disable")
      |> render_click(%{"status" => "disabled", "title" => "Forged Title"})

      assert row_status(own_row) == :disabled
      assert_receive {:flash_message, {:info, "Activity `Test Activity` disabled successfully."}}
    end

    test "refuses to toggle once the author no longer collaborates on the project", %{
      conn: conn,
      project: project,
      activity: activity,
      author: author,
      collaboration: collaboration
    } do
      own_row = enabled_row(activity, project)

      {:ok, lcd, _html} = mount_item(conn, activity, project, author)
      Oli.Repo.delete!(collaboration)

      lcd
      |> element("button", "Disable")
      |> render_click()

      assert row_status(own_row) == :enabled
    end
  end

  defp mount_item(conn, activity, project, author) do
    live_component_isolated(
      conn,
      OliWeb.Components.Project.AdvancedActivityItem,
      id: "test-item",
      activity: %{activity | project_status: :enabled},
      project: project,
      current_author: author
    )
  end

  defp enabled_row(activity, project) do
    insert(:activity_registration_project, %{
      activity_registration_id: activity.id,
      project_id: project.id,
      status: :enabled
    })
  end

  defp row_status(row) do
    Oli.Repo.get_by!(Oli.Activities.ActivityRegistrationProject,
      activity_registration_id: row.activity_registration_id,
      project_id: row.project_id
    ).status
  end
end

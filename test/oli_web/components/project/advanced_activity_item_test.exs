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

      [
        project: project,
        activity: activity
      ]
    end

    test "renders activity information correctly", %{
      conn: conn,
      project: project,
      activity: activity
    } do
      {:ok, lcd, html} =
        live_component_isolated(
          conn,
          OliWeb.Components.Project.AdvancedActivityItem,
          id: "test-item",
          activity: activity,
          project_id: project.id
        )

      assert html =~ activity.title
      assert has_element?(lcd, "div", activity.title)
    end

    test "shows deployment ID for LTI activities", %{conn: conn, project: project} do
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
          project_id: project.id
        )

      assert has_element?(lcd, "span", "Deployment Id: #{deployment.deployment_id}")
    end

    test "shows enable button for disabled activities", %{
      conn: conn,
      project: project,
      activity: activity
    } do
      disabled_activity = %{activity | project_status: :disabled}

      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Components.Project.AdvancedActivityItem,
          id: "test-item",
          activity: disabled_activity,
          project_id: project.id
        )

      assert has_element?(lcd, "button", "Enable")
    end

    test "shows disable button for enabled activities", %{
      conn: conn,
      project: project,
      activity: activity
    } do
      enabled_activity = %{activity | project_status: :enabled}

      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Components.Project.AdvancedActivityItem,
          id: "test-item",
          activity: enabled_activity,
          project_id: project.id
        )

      assert has_element?(lcd, "button", "Disable")
    end

    test "enables activity when enable button is clicked", %{
      conn: conn,
      project: project,
      activity: activity
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
          project_id: project.id
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
      activity: activity
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
          project_id: project.id
        )

      # Click disable button
      lcd
      |> element("button", "Disable")
      |> render_click()

      # Should update the activity status in the component
      assert has_element?(lcd, "button", "Enable")
    end
  end
end

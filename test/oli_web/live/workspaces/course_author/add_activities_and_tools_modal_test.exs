defmodule OliWeb.Workspaces.CourseAuthor.AddActivitiesAndToolsModalTest do
  use OliWeb.ConnCase
  import Phoenix.LiveViewTest
  import Oli.Factory
  import LiveComponentTests
  import Ecto.Query, only: [where: 2]

  alias Oli.Activities.ActivityRegistrationProject
  alias Oli.Repo

  defp manually_trigger_show_modal_event(lcd) do
    lcd
    |> element("#test-show-modal-button")
    |> render_click()

    lcd
  end

  describe "AddActivitiesAndToolsModal" do
    setup do
      project = insert(:project)
      author = insert(:author)
      collaboration = insert(:author_project, project_id: project.id, author_id: author.id)

      # Create advanced activities
      activity1 =
        insert(:activity_registration, %{
          title: "Test Activity 1",
          globally_visible: true,
          globally_available: false
        })

      activity2 =
        insert(:activity_registration, %{
          title: "Test Activity 2",
          globally_visible: true,
          globally_available: false
        })

      # Create LTI tool
      lti_tool =
        insert(:activity_registration, %{
          title: "LTI Tool",
          delivery_element: "lti-external-tool-delivery",
          authoring_element: "lti-external-tool-authoring",
          globally_visible: true,
          globally_available: false
        })

      deployment =
        insert(:lti_external_tool_activity_deployment, %{
          activity_registration: lti_tool,
          status: :enabled
        })

      [
        project: project,
        author: author,
        collaboration: collaboration,
        activity1: activity1,
        activity2: activity2,
        lti_tool: lti_tool,
        deployment: deployment
      ]
    end

    test "mounts correctly in loading state", %{author: author, conn: conn, project: project} do
      {:ok, _lcd, html} =
        live_component_isolated(
          conn,
          OliWeb.Workspaces.CourseAuthor.AddActivitiesAndToolsModal,
          id: "test-modal",
          project: project,
          current_author: author,
          is_admin: true
        )

      assert html =~ "Add Advanced Activities &amp; External Tools"
      assert html =~ "loading"
    end

    test "shows modal content when loading is complete", %{
      author: author,
      conn: conn,
      project: project,
      activity1: activity1
    } do
      # Add activity to project so it shows up in selectable items
      insert(:activity_registration_project, %{
        activity_registration_id: activity1.id,
        project_id: project.id,
        status: :enabled
      })

      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Workspaces.CourseAuthor.AddActivitiesAndToolsModal,
          id: "test-modal",
          project: project,
          current_author: author,
          is_admin: true
        )

      # Trigger the show_modal event to load data and exit loading state
      lcd = manually_trigger_show_modal_event(lcd)

      # Now we can test the actual modal content
      assert has_element?(lcd, "[role='tab'][data-tab='activities']")
      assert has_element?(lcd, "[role='tab'][data-tab='tools']")
      assert has_element?(lcd, "[role='search']")
      assert has_element?(lcd, "[role='cancel-button']")
      assert has_element?(lcd, "[role='apply-button']")
      assert has_element?(lcd, "[role='activity-item'][data-activity-id='#{activity1.id}']")

      assert lcd
             |> element("[role='activity-item'][data-activity-id='#{activity1.id}']")
             |> render() =~ activity1.title
    end

    test "filters activities by search term", %{
      author: author,
      conn: conn,
      project: project,
      activity1: activity1,
      activity2: activity2
    } do
      # Add activities to project
      insert(:activity_registration_project, %{
        activity_registration_id: activity1.id,
        project_id: project.id,
        status: :enabled
      })

      insert(:activity_registration_project, %{
        activity_registration_id: activity2.id,
        project_id: project.id,
        status: :enabled
      })

      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Workspaces.CourseAuthor.AddActivitiesAndToolsModal,
          id: "test-modal",
          project: project,
          current_author: author,
          is_admin: true
        )

      # Trigger the show_modal event to load data and exit loading state
      lcd = manually_trigger_show_modal_event(lcd)

      # Verify both activities are initially visible
      assert has_element?(lcd, "[role='activity-item'][data-activity-id='#{activity1.id}']")
      assert has_element?(lcd, "[role='activity-item'][data-activity-id='#{activity2.id}']")

      # Search for activity1 by title
      lcd
      |> element("[role='search'] form")
      |> render_change(%{search_term: activity1.title})

      # Verify only activity1 is visible after search
      assert has_element?(lcd, "[role='activity-item'][data-activity-id='#{activity1.id}']")
      refute has_element?(lcd, "[role='activity-item'][data-activity-id='#{activity2.id}']")
    end

    test "clears search when clear_search is triggered", %{
      author: author,
      conn: conn,
      project: project,
      activity1: activity1,
      activity2: activity2
    } do
      # Add activities to project
      insert(:activity_registration_project, %{
        activity_registration_id: activity1.id,
        project_id: project.id,
        status: :enabled
      })

      insert(:activity_registration_project, %{
        activity_registration_id: activity2.id,
        project_id: project.id,
        status: :enabled
      })

      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Workspaces.CourseAuthor.AddActivitiesAndToolsModal,
          id: "test-modal",
          project: project,
          current_author: author,
          is_admin: true
        )

      # Trigger the show_modal event to load data and exit loading state
      lcd = manually_trigger_show_modal_event(lcd)

      # Search for activity1
      lcd
      |> element("[role='search'] form")
      |> render_change(%{search_term: activity1.title})

      # Verify only activity1 is visible
      assert has_element?(lcd, "[role='activity-item'][data-activity-id='#{activity1.id}']")
      refute has_element?(lcd, "[role='activity-item'][data-activity-id='#{activity2.id}']")

      # Click clear search button
      lcd
      |> element("[role='search'] button")
      |> render_click()

      # Verify both activities are visible again
      assert has_element?(lcd, "[role='activity-item'][data-activity-id='#{activity1.id}']")
      assert has_element?(lcd, "[role='activity-item'][data-activity-id='#{activity2.id}']")
    end

    test "switches between activities and tools tabs", %{
      author: author,
      conn: conn,
      project: project,
      activity1: activity1,
      lti_tool: lti_tool
    } do
      # Add activity and tool to project
      insert(:activity_registration_project, %{
        activity_registration_id: activity1.id,
        project_id: project.id,
        status: :enabled
      })

      insert(:activity_registration_project, %{
        activity_registration_id: lti_tool.id,
        project_id: project.id,
        status: :enabled
      })

      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Workspaces.CourseAuthor.AddActivitiesAndToolsModal,
          id: "test-modal",
          project: project,
          current_author: author,
          is_admin: true
        )

      # Trigger the show_modal event to load data and exit loading state
      lcd = manually_trigger_show_modal_event(lcd)

      # Verify activities tab is active by default
      assert lcd |> element("[role='tab'][data-tab='activities']") |> render() =~
               "data-selected=\"true\""

      assert lcd |> element("[role='tab'][data-tab='tools']") |> render() =~
               "data-selected=\"false\""

      # and the activity is listed, but not the lti tool
      assert lcd |> render() =~ activity1.title
      refute lcd |> render() =~ lti_tool.title

      # Switch to tools tab
      lcd
      |> element("[role='tab'][data-tab='tools']")
      |> render_click()

      # Verify tools tab is now active
      assert lcd |> element("[role='tab'][data-tab='tools']") |> render() =~
               "data-selected=\"true\""

      assert lcd |> element("[role='tab'][data-tab='activities']") |> render() =~
               "data-selected=\"false\""

      # and the lti tool is listed, but not the activity
      assert lcd |> render() =~ lti_tool.title
      refute lcd |> render() =~ activity1.title

      # Switch back to activities tab
      lcd
      |> element("[role='tab'][data-tab='activities']")
      |> render_click()

      # Verify activities tab is active again
      assert lcd |> element("[role='tab'][data-tab='activities']") |> render() =~
               "data-selected=\"true\""

      assert lcd |> element("[role='tab'][data-tab='tools']") |> render() =~
               "data-selected=\"false\""
    end

    test "toggles activity selection", %{
      author: author,
      conn: conn,
      project: project,
      activity1: activity1
    } do
      # Add activity to project
      insert(:activity_registration_project, %{
        activity_registration_id: activity1.id,
        project_id: project.id,
        status: :enabled
      })

      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Workspaces.CourseAuthor.AddActivitiesAndToolsModal,
          id: "test-modal",
          project: project,
          current_author: author,
          is_admin: true
        )

      # Trigger the show_modal event to load data and exit loading state
      lcd = manually_trigger_show_modal_event(lcd)

      # Verify activity is initially selected (since it's already in the project)
      assert lcd
             |> element(
               "[role='activity-item'][data-activity-id='#{activity1.id}'] input[type='checkbox']"
             )
             |> render() =~ "checked"

      # Deselect the activity to create a pending change
      lcd
      |> element("[role='activity-item'][data-activity-id='#{activity1.id}']")
      |> render_click()

      # Verify activity is now deselected
      refute lcd
             |> element(
               "[role='activity-item'][data-activity-id='#{activity1.id}'] input[type='checkbox']"
             )
             |> render() =~ "checked"

      # Select the activity again
      lcd
      |> element("[role='activity-item'][data-activity-id='#{activity1.id}']")
      |> render_click()

      # Verify activity is selected again
      assert lcd
             |> element(
               "[role='activity-item'][data-activity-id='#{activity1.id}'] input[type='checkbox']"
             )
             |> render() =~ "checked"
    end

    test "shows pending changes summary", %{
      author: author,
      conn: conn,
      project: project,
      activity1: activity1,
      activity2: activity2,
      lti_tool: lti_tool
    } do
      # Add activity to project
      insert(:activity_registration_project, %{
        activity_registration_id: activity1.id,
        project_id: project.id,
        status: :enabled
      })

      # add another activity to the project
      insert(:activity_registration_project, %{
        activity_registration_id: activity2.id,
        project_id: project.id,
        status: :enabled
      })

      # add an lti tool to the project
      insert(:activity_registration_project, %{
        activity_registration_id: lti_tool.id,
        project_id: project.id,
        status: :enabled
      })

      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Workspaces.CourseAuthor.AddActivitiesAndToolsModal,
          id: "test-modal",
          project: project,
          current_author: author,
          is_admin: true
        )

      # Trigger the show_modal event to load data and exit loading state
      lcd = manually_trigger_show_modal_event(lcd)

      # Initially no changes should be shown
      refute lcd |> render() =~ "Changes:"

      # Deselect the activity to create a pending change
      lcd
      |> element("[role='activity-item'][data-activity-id='#{activity1.id}']")
      |> render_click()

      # Verify pending changes summary is shown
      assert lcd |> render() =~ "Changes:"
      assert lcd |> render() =~ "1 activity"

      # Deselect another activity to create a second pending change
      lcd
      |> element("[role='activity-item'][data-activity-id='#{activity2.id}']")
      |> render_click()

      # Verify pending changes summary is updated
      assert lcd |> render() =~ "Changes:"
      assert lcd |> render() =~ "2 activities"

      # switch to tools tab and deselect the lti tool
      lcd
      |> element("[role='tab'][data-tab='tools']")
      |> render_click()

      lcd
      |> element("[role='tool-item'][data-tool-id='#{lti_tool.id}']")
      |> render_click()

      # Verify pending changes summary is updated
      assert lcd |> render() =~ "Changes:"
      assert lcd |> render() =~ "2 activities"
      assert lcd |> render() =~ "1 tool"
    end

    test "saves selections successfully", %{
      author: author,
      conn: conn,
      project: project,
      activity1: activity1
    } do
      # Add activity to project
      insert(:activity_registration_project, %{
        project_id: project.id,
        activity_registration_id: activity1.id,
        status: :enabled
      })

      # Mount the component
      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Workspaces.CourseAuthor.AddActivitiesAndToolsModal,
          %{
            id: "test-modal",
            project: project,
            current_author: author,
            is_admin: true
          }
        )

      # Set up message interception
      test_pid = self()

      live_component_intercept(lcd, fn
        {:flash_message, message}, socket ->
          send(test_pid, {:flash_message, message})
          {:cont, socket}

        {:refresh_tools_and_activities}, socket ->
          send(test_pid, :refresh_tools_and_activities)
          {:cont, socket}

        _other, socket ->
          {:cont, socket}
      end)

      # Trigger the show_modal event to load data and exit loading state
      lcd = manually_trigger_show_modal_event(lcd)

      # Verify activity is initially selected (since it's already in the project)
      assert lcd
             |> element(
               "[role='activity-item'][data-activity-id='#{activity1.id}'] input[type='checkbox']"
             )
             |> render() =~ "checked"

      # and the save button is disabled (since no changes have been made)
      assert lcd |> element("[role='apply-button']") |> render() =~ "disabled"

      # Deselect the activity to create a pending change
      lcd
      |> element("[role='activity-item'][data-activity-id='#{activity1.id}']")
      |> render_click()

      # Verify apply button is enabled when changes are made
      assert lcd |> element("[role='apply-button']") |> render() =~ "bg-[#0165DA]"
      refute lcd |> element("[role='apply-button']") |> render() =~ "disabled"

      # Click apply button to save changes
      lcd
      |> element("[role='apply-button']")
      |> render_click()

      # Verify the component sent the expected messages to the parent LiveView
      assert_receive {:flash_message, {:info, "Activities and tools updated successfully."}}
      assert_receive :refresh_tools_and_activities

      # check on the db that the activity is not longer in the project
      refute associated?(activity1, project)
    end

    test "shows no results message when search yields no results", %{
      author: author,
      conn: conn,
      project: project,
      activity1: activity1
    } do
      # Add activity to project
      insert(:activity_registration_project, %{
        activity_registration_id: activity1.id,
        project_id: project.id,
        status: :enabled
      })

      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Workspaces.CourseAuthor.AddActivitiesAndToolsModal,
          id: "test-modal",
          project: project,
          current_author: author,
          is_admin: true
        )

      # Trigger the show_modal event to load data and exit loading state
      lcd = manually_trigger_show_modal_event(lcd)

      # Search for something that doesn't exist
      lcd
      |> element("[role='search'] form")
      |> render_change(%{search_term: "nonexistent"})

      # Verify no results message
      assert lcd |> render() =~ "No Advanced Activities Found"
      assert lcd |> render() =~ "No advanced activities match"
      assert lcd |> render() =~ "nonexistent"

      # switch to tools tab and verify no results message
      lcd
      |> element("[role='tab'][data-tab='tools']")
      |> render_click()

      # Search for something that doesn't exist
      lcd
      |> element("[role='search'] form")
      |> render_change(%{search_term: "nonexistent"})

      # Verify no results message
      assert lcd |> render() =~ "No External Tools Found"
    end

    test "handles LTI tools correctly", %{
      author: author,
      conn: conn,
      project: project,
      lti_tool: lti_tool
    } do
      # Add LTI tool to project
      insert(:activity_registration_project, %{
        project_id: project.id,
        activity_registration_id: lti_tool.id,
        status: :enabled
      })

      # Mount the component
      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Workspaces.CourseAuthor.AddActivitiesAndToolsModal,
          %{
            id: "test-modal",
            project: project,
            current_author: author,
            is_admin: true
          }
        )

      # Trigger the show_modal event to load data and exit loading state
      lcd = manually_trigger_show_modal_event(lcd)

      # Switch to tools tab
      lcd
      |> element("[role='tab'][data-tab='tools']")
      |> render_click()

      # Verify tool is displayed
      assert has_element?(lcd, "[role='tool-item'][data-tool-id='#{lti_tool.id}']")

      assert lcd
             |> element("[role='tool-item'][data-tool-id='#{lti_tool.id}']")
             |> render() =~ lti_tool.title

      # Verify tool is initially selected (since it's already in the project)
      assert lcd
             |> element(
               "[role='tool-item'][data-tool-id='#{lti_tool.id}'] input[type='checkbox']"
             )
             |> render() =~ "checked"

      # Deselect the tool
      lcd
      |> element("[role='tool-item'][data-tool-id='#{lti_tool.id}']")
      |> render_click()

      # Verify tool is now deselected
      refute lcd
             |> element(
               "[role='tool-item'][data-tool-id='#{lti_tool.id}'] input[type='checkbox']"
             )
             |> render() =~ "checked"
    end

    test "disables apply button when no changes", %{author: author, conn: conn, project: project} do
      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Workspaces.CourseAuthor.AddActivitiesAndToolsModal,
          id: "test-modal",
          project: project,
          current_author: author,
          is_admin: true
        )

      # Trigger the show_modal event to load data and exit loading state
      lcd = manually_trigger_show_modal_event(lcd)

      # Verify apply button is disabled when no changes
      assert lcd |> element("[role='apply-button']") |> render() =~ "bg-gray-400"
      assert lcd |> element("[role='apply-button']") |> render() =~ "disabled"
    end

    test "enables apply button when changes are made", %{
      author: author,
      conn: conn,
      project: project,
      activity1: activity1
    } do
      # Add activity to project
      insert(:activity_registration_project, %{
        activity_registration_id: activity1.id,
        project_id: project.id,
        status: :enabled
      })

      {:ok, lcd, _html} =
        live_component_isolated(
          conn,
          OliWeb.Workspaces.CourseAuthor.AddActivitiesAndToolsModal,
          id: "test-modal",
          project: project,
          current_author: author,
          is_admin: true
        )

      # Trigger the show_modal event to load data and exit loading state
      lcd = manually_trigger_show_modal_event(lcd)

      # Verify apply button is initially disabled
      assert lcd |> element("[role='apply-button']") |> render() =~ "bg-gray-400"

      # Deselect the activity to create a pending change
      lcd
      |> element("[role='activity-item'][data-activity-id='#{activity1.id}']")
      |> render_click()

      # Verify apply button is now enabled
      assert lcd |> element("[role='apply-button']") |> render() =~ "bg-[#0165DA]"
      refute lcd |> element("[role='apply-button']") |> render() =~ "disabled"
    end

    test "applies changes to its own project when the event names another project", %{
      conn: conn,
      project: project,
      author: author,
      activity1: activity1
    } do
      other_project = insert(:project)
      {:ok, lcd, _html} = mount_modal(conn, project, author)

      lcd
      |> element("#test-show-modal-button")
      |> render_click(%{"project_id" => other_project.id})

      select_and_apply(lcd, activity1)

      refute associated?(activity1, other_project)
      assert associated?(activity1, project)
    end

    test "refuses to apply once the author no longer collaborates on the project", %{
      conn: conn,
      project: project,
      author: author,
      collaboration: collaboration,
      activity1: activity1
    } do
      {:ok, lcd, _html} = mount_modal(conn, project, author)
      manually_trigger_show_modal_event(lcd)
      Repo.delete!(collaboration)

      select_and_apply(lcd, activity1)

      refute associated?(activity1, project)
    end
  end

  defp mount_modal(conn, project, author) do
    live_component_isolated(
      conn,
      OliWeb.Workspaces.CourseAuthor.AddActivitiesAndToolsModal,
      %{id: "test-modal", project: project, current_author: author, is_admin: false}
    )
  end

  defp select_and_apply(lcd, activity) do
    lcd
    |> element("[role='activity-item'][data-activity-id='#{activity.id}']")
    |> render_click()

    lcd
    |> element("[role='apply-button']")
    |> render_click()
  end

  defp associated?(activity, project) do
    ActivityRegistrationProject
    |> where(activity_registration_id: ^activity.id, project_id: ^project.id)
    |> Repo.exists?()
  end
end

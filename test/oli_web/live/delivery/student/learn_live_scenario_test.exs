defmodule OliWeb.Delivery.Student.LearnLiveScenarioTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.Scenarios

  setup %{conn: conn} do
    # Create a project with 2 units, each containing 2 pages
    yaml = """
    - project:
        name: test_project
        title: Test Project
        root:
          children:
            - container: Unit 1
              children:
                - page: Unit 1 - Page 1
                - page: Unit 1 - Page 2
            - container: Unit 2
              children:
                - page: Unit 2 - Page 1
                - page: Unit 2 - Page 2

    - section:
        name: test_section
        from: test_project
        title: Test Course Section
        registration_open: true

    - user:
        name: test_student
        type: student
        email: student@test.edu

    - enroll:
        user: test_student
        section: test_section
        role: student
    """

    # Execute the scenario
    result = Scenarios.execute_yaml(yaml)

    # Check for any errors in execution
    assert result.errors == [], "Scenario execution failed with errors: #{inspect(result.errors)}"

    # Extract created entities from the result
    section = result.state.sections["test_section"]
    student = result.state.users["test_student"]

    # Ensure the student was created successfully
    refute is_nil(student), "Student was not created by scenario"
    refute is_nil(student.id), "Student does not have an ID"

    # Log in as the student using the proper test helper
    token = Oli.Accounts.generate_user_session_token(student)

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    # Mark the section as visited by the student
    Oli.Delivery.Sections.mark_section_visited_for_student(section, student)

    Oli.Delivery.Sections.SectionResourceMigration.migrate(section.id)

    {:ok, conn: conn, section: section, student: student, result: result}
  end

  describe "LearnLive view" do
    test "student can access the LearnLive page for enrolled section", %{
      conn: conn,
      section: section,
      student: student
    } do
      # Visit the LearnLive page
      {:ok, view, html} = live(conn, ~p"/sections/#{section.slug}/learn")

      # Verify the view loaded successfully (page renders without errors)
      assert view
      assert html =~ "Test Course Section"

      # Basic check that student is logged in and enrolled
      assert section.id
      assert student.id
    end

    test "robustness against deleted page revision", %{
      conn: conn,
      section: section,
      student: student,
      result: result
    } do
      test_revision_robustness(conn, section, student, result, fn revision,
                                                                  _section_resource,
                                                                  _container_section_resource ->
        # Mark the revision as deleted
        {:ok, _updated_revision} =
          Oli.Resources.update_revision(revision, %{deleted: true})
      end)
    end

    test "robustness against corrupted revision content", %{
      conn: conn,
      section: section,
      student: student,
      result: result
    } do
      test_revision_robustness(conn, section, student, result, fn revision,
                                                                  _section_resource,
                                                                  _container_section_resource ->
        # Corrupt the content field to simulate data corruption
        {:ok, _updated_revision} =
          Oli.Resources.update_revision(revision, %{
            content: %{"model" => [], "corrupt" => true}
          })
      end)
    end

    test "robustness against nil revision", %{
      conn: conn,
      section: section,
      student: student,
      result: result
    } do
      test_revision_robustness(conn, section, student, result, fn _revision,
                                                                  section_resource,
                                                                  _container_section_resource ->
        # Update the section resource to set revision_id to nil
        {:ok, _updated} =
          Ecto.Changeset.change(section_resource, %{revision_id: nil})
          |> Oli.Repo.update()
      end)
    end

    test "robustness against nil container child", %{
      conn: conn,
      section: section,
      student: student,
      result: result
    } do
      test_revision_robustness(conn, section, student, result, fn _revision,
                                                                  section_resource,
                                                                  container_section_resource ->
        # Update the container's children to remove this page's section resource id
        current_children = container_section_resource.children || []

        updated_children =
          Enum.map(current_children, fn child_id ->
            if child_id == section_resource.id do
              nil
            else
              child_id
            end
          end)

        {:ok, _updated} =
          Ecto.Changeset.change(container_section_resource, %{
            children: updated_children
          })
          |> Oli.Repo.update()
      end)
    end

    test "robustness against unknown child id", %{
      conn: conn,
      section: section,
      student: student,
      result: result
    } do
      test_revision_robustness(conn, section, student, result, fn _revision,
                                                                  section_resource,
                                                                  container_section_resource ->
        # Update the container's children to remove this page's section resource id
        current_children = container_section_resource.children || []

        updated_children =
          Enum.map(current_children, fn child_id ->
            if child_id == section_resource.id do
              # Pick an id that doesn't exist
              1_234_567_890
            else
              child_id
            end
          end)

        {:ok, _updated} =
          Ecto.Changeset.change(container_section_resource, %{
            children: updated_children
          })
          |> Oli.Repo.update()
      end)
    end
  end

  # Helper function to test LearnLive robustness with different revision/section_resource manipulations
  defp test_revision_robustness(conn, section, student, result, update_fn) do
    # Get the project and find the page revision
    project = result.state.projects["test_project"]
    page_revision = project.rev_by_title["Unit 1 - Page 1"]
    container_revision = project.rev_by_title["Unit 1"]

    # Get the section resource for this page
    section_resource =
      Oli.Repo.get_by!(Oli.Delivery.Sections.SectionResource,
        section_id: section.id,
        resource_id: page_revision.resource_id
      )

    # Get the section resource for the container (Unit 1)
    container_section_resource =
      Oli.Repo.get_by!(Oli.Delivery.Sections.SectionResource,
        section_id: section.id,
        resource_id: container_revision.resource_id
      )

    # Read the revision directly using the revision_id from section_resource
    actual_revision = Oli.Repo.get!(Oli.Resources.Revision, section_resource.revision_id)

    # Verify we have the correct revision
    assert actual_revision.id == section_resource.revision_id
    assert actual_revision.resource_id == page_revision.resource_id

    # Apply the modification to revision, section_resource, or container_section_resource
    update_fn.(actual_revision, section_resource, container_section_resource)

    Oli.Delivery.DepotCoordinator.clear(
      Oli.Delivery.Sections.SectionResourceDepot.depot_desc(),
      section.id
    )

    # Visit the LearnLive page again after modifying the revision
    {:ok, view, html} = live(conn, ~p"/sections/#{section.slug}/learn")

    # Verify the view loaded successfully (page renders without errors)
    assert view
    assert html =~ "Test Course Section"

    # Reload the container section resource to check if it was modified
    reloaded_container =
      Oli.Repo.get!(Oli.Delivery.Sections.SectionResource, container_section_resource.id)

    # Check behavior based on the type of modification
    # For the nil container child test, the page should NOT appear since it's been unlinked
    if reloaded_container.children != nil and
         (nil in reloaded_container.children or 1_234_567_890 in reloaded_container.children) do
      refute html =~ "Unit 1 - Page 1", "Page should not appear when unlinked from container"
    else
      # For other tests, the page should still appear
      assert html =~ "Unit 1 - Page 1", "Page still appears even when revision is modified"
    end

    # Basic check that student is logged in and enrolled
    assert section.id
    assert student.id
  end
end

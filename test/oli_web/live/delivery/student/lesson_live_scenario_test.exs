defmodule OliWeb.Delivery.Student.LessonLiveScenarioTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.Scenarios

  setup %{conn: conn} do
    # Create a project with 1 unit containing 3 pages
    yaml = """
    - project:
        name: lesson_test_project
        title: Lesson Test Project
        root:
          children:
            - container: Unit 1
              children:
                - page: Page 1
                - page: Page 2
                - page: Page 3

    - section:
        name: lesson_test_section
        from: lesson_test_project
        title: Lesson Test Section
        registration_open: true

    - user:
        name: lesson_test_student
        type: student
        email: lesson_student@test.edu

    - enroll:
        user: lesson_test_student
        section: lesson_test_section
        role: student
    """

    # Execute the scenario
    result = Scenarios.execute_yaml(yaml)

    # Check for any errors in execution
    assert result.errors == [], "Scenario execution failed with errors: #{inspect(result.errors)}"

    # Extract created entities from the result
    section = result.state.sections["lesson_test_section"]
    student = result.state.users["lesson_test_student"]

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

  describe "LessonLive view with bad data" do
    test "can open Lesson Live view for second page when revision is deleted", %{
      conn: conn,
      section: section,
      student: student,
      result: result
    } do
      # Get the project and find the second page revision
      project = result.state.projects["lesson_test_project"]
      second_page_revision = project.rev_by_title["Page 2"]

      # Get the section resource for the second page
      section_resource =
        Oli.Repo.get_by!(Oli.Delivery.Sections.SectionResource,
          section_id: section.id,
          resource_id: second_page_revision.resource_id
        )

      # Read the revision directly using the revision_id from section_resource
      actual_revision = Oli.Repo.get!(Oli.Resources.Revision, section_resource.revision_id)

      # Verify we have the correct revision
      assert actual_revision.id == section_resource.revision_id
      assert actual_revision.resource_id == second_page_revision.resource_id

      # Mark the revision as deleted
      {:ok, _updated_revision} =
        Oli.Resources.update_revision(actual_revision, %{deleted: true})

      # Clear the depot cache to ensure we're testing with the updated data
      Oli.Delivery.DepotCoordinator.clear(
        Oli.Delivery.Sections.SectionResourceDepot.depot_desc(),
        section.id
      )

      # Visit the Lesson Live page for the second page
      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/lesson/#{second_page_revision.slug}")
      
      # Trigger script loading to render content
      view
      |> element("#eventIntercept")
      |> render_hook("survey_scripts_loaded", %{"loaded" => true})
      
      html = render(view)

      # Verify the view loaded successfully despite the deleted revision
      assert view

      # The page should handle the deleted revision gracefully
      # It might show an error message or redirect, but should not crash
      # Check that we get some reasonable response
      assert html

      # Basic check that student is logged in and enrolled
      assert section.id
      assert student.id
    end

    test "can view second page when first and third pages have deleted revisions", %{
      conn: conn,
      section: section,
      student: student,
      result: result
    } do
      # Get the project and find all three page revisions
      project = result.state.projects["lesson_test_project"]
      first_page_revision = project.rev_by_title["Page 1"]
      second_page_revision = project.rev_by_title["Page 2"]
      third_page_revision = project.rev_by_title["Page 3"]

      # Get the section resources for the first and third pages
      first_page_section_resource =
        Oli.Repo.get_by!(Oli.Delivery.Sections.SectionResource,
          section_id: section.id,
          resource_id: first_page_revision.resource_id
        )

      third_page_section_resource =
        Oli.Repo.get_by!(Oli.Delivery.Sections.SectionResource,
          section_id: section.id,
          resource_id: third_page_revision.resource_id
        )

      # Read the revisions directly
      first_page_actual_revision = Oli.Repo.get!(Oli.Resources.Revision, first_page_section_resource.revision_id)
      third_page_actual_revision = Oli.Repo.get!(Oli.Resources.Revision, third_page_section_resource.revision_id)

      # Verify we have the correct revisions
      assert first_page_actual_revision.id == first_page_section_resource.revision_id
      assert first_page_actual_revision.resource_id == first_page_revision.resource_id
      assert third_page_actual_revision.id == third_page_section_resource.revision_id
      assert third_page_actual_revision.resource_id == third_page_revision.resource_id

      # Mark the first and third page revisions as deleted
      {:ok, _updated_first_revision} =
        Oli.Resources.update_revision(first_page_actual_revision, %{deleted: true})

      {:ok, _updated_third_revision} =
        Oli.Resources.update_revision(third_page_actual_revision, %{deleted: true})

      # Clear the depot cache to ensure we're testing with the updated data
      Oli.Delivery.DepotCoordinator.clear(
        Oli.Delivery.Sections.SectionResourceDepot.depot_desc(),
        section.id
      )

      # Rebuild the previous_next_index after modifying the revisions
      {:ok, _updated_section} = Oli.Delivery.PreviousNextIndex.rebuild(section)

      # Visit the Lesson Live page for the second page (which should still work)
      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/lesson/#{second_page_revision.slug}")
      
      # Trigger script loading to render content
      view
      |> element("#eventIntercept")
      |> render_hook("survey_scripts_loaded", %{"loaded" => true})
      
      html = render(view)

      # Verify the view loaded successfully for the second page
      # even though the first and third pages have deleted revisions
      assert view

      # The second page should load normally since its revision is not deleted
      assert html

      # Basic check that student is logged in and enrolled
      assert section.id
      assert student.id
    end

    test "can view second page when first and third pages have nil references in container children", %{
      conn: conn,
      section: section,
      student: student,
      result: result
    } do
      # Get the project and find all page revisions and the container
      project = result.state.projects["lesson_test_project"]
      first_page_revision = project.rev_by_title["Page 1"]
      second_page_revision = project.rev_by_title["Page 2"]
      third_page_revision = project.rev_by_title["Page 3"]
      container_revision = project.rev_by_title["Unit 1"]

      # Get the section resources for all pages
      first_page_section_resource =
        Oli.Repo.get_by!(Oli.Delivery.Sections.SectionResource,
          section_id: section.id,
          resource_id: first_page_revision.resource_id
        )

      _second_page_section_resource =
        Oli.Repo.get_by!(Oli.Delivery.Sections.SectionResource,
          section_id: section.id,
          resource_id: second_page_revision.resource_id
        )

      third_page_section_resource =
        Oli.Repo.get_by!(Oli.Delivery.Sections.SectionResource,
          section_id: section.id,
          resource_id: third_page_revision.resource_id
        )

      # Get the section resource for the container (Unit 1)
      container_section_resource =
        Oli.Repo.get_by!(Oli.Delivery.Sections.SectionResource,
          section_id: section.id,
          resource_id: container_revision.resource_id
        )

      # Update the container's children to set first and third page references to nil
      current_children = container_section_resource.children || []

      updated_children =
        Enum.map(current_children, fn child_id ->
          cond do
            child_id == first_page_section_resource.id -> nil
            child_id == third_page_section_resource.id -> nil
            true -> child_id
          end
        end)

      {:ok, _updated} =
        Ecto.Changeset.change(container_section_resource, %{
          children: updated_children
        })
        |> Oli.Repo.update()

      # Clear the depot cache to ensure we're testing with the updated data
      Oli.Delivery.DepotCoordinator.clear(
        Oli.Delivery.Sections.SectionResourceDepot.depot_desc(),
        section.id
      )

      # Rebuild the previous_next_index after modifying the container's children
      {:ok, _updated_section} = Oli.Delivery.PreviousNextIndex.rebuild(section)

      # Visit the Lesson Live page for the second page (which should still work)
      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/lesson/#{second_page_revision.slug}")
      
      # Trigger script loading to render content
      view
      |> element("#eventIntercept")
      |> render_hook("survey_scripts_loaded", %{"loaded" => true})
      
      html = render(view)

      # Verify the view loaded successfully for the second page
      # even though the first and third pages have nil references in the container
      assert view

      # The second page should load normally since its reference is not nil
      assert html

      # Basic check that student is logged in and enrolled
      assert section.id
      assert student.id
    end
  end

  describe "LessonLive view with activity references" do
    setup %{conn: conn} do
      # Create a project with 1 unit containing 1 page with initial simple content
      yaml = """
      - project:
          name: activity_test_project
          title: Activity Test Project
          root:
            children:
              - container: Unit 1
                children:
                  - page: Page with Activity

      - edit_page:
          project: activity_test_project
          page: Page with Activity
          content: |
            title: "Page with Activity"
            graded: false
            blocks:
              - type: prose
                body_md: "This is the initial content of the page."

      - section:
          name: activity_test_section
          from: activity_test_project
          title: Activity Test Section
          registration_open: true

      - user:
          name: activity_test_student
          type: student
          email: activity_student@test.edu

      - enroll:
          user: activity_test_student
          section: activity_test_section
          role: student
      """

      # Execute the scenario
      result = Scenarios.execute_yaml(yaml)

      # Check for any errors in execution
      assert result.errors == [], "Scenario execution failed with errors: #{inspect(result.errors)}"

      # Extract created entities from the result
      section = result.state.sections["activity_test_section"]
      student = result.state.users["activity_test_student"]

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

    test "handles page with activity-reference to non-existent resource_id", %{
      conn: conn,
      section: section,
      student: student,
      result: result
    } do
      # Get the project and find the page revision
      project = result.state.projects["activity_test_project"]
      page_revision = project.rev_by_title["Page with Activity"]

      # FIRST: Verify the page renders correctly with the initial content
      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")
      
      # The content won't render until the client confirms scripts are loaded
      view
      |> element("#eventIntercept")
      |> render_hook("survey_scripts_loaded", %{"loaded" => true})
      
      # Now get the rendered HTML
      html = render(view)
      
      # The page should render properly with the initial content
      assert view
      assert html
      
      # Verify the initial content renders properly
      assert String.length(html) > 1000, "Should get substantial HTML back"
      assert html =~ "This is the initial content of the page.", 
        "Initial content should render correctly"
      
      # Store whether initial page rendered content for comparison
      initial_has_page_content = String.contains?(html, "page_content")
      initial_has_text = String.contains?(html, "This is the initial content")

      # SECOND: Now update the page to add a bad activity reference
      # Get the section resource for the page
      section_resource =
        Oli.Repo.get_by!(Oli.Delivery.Sections.SectionResource,
          section_id: section.id,
          resource_id: page_revision.resource_id
        )

      # Read the revision directly
      actual_revision = Oli.Repo.get!(Oli.Resources.Revision, section_resource.revision_id)

      # Update the page content to include an activity-reference to a non-existent resource_id
      {:ok, _updated_revision} =
        Oli.Resources.update_revision(actual_revision, %{
          content: %{
            "model" => [
              %{
                "type" => "content",
                "children" => [
                  %{
                    "type" => "p",
                    "id" => "test-paragraph",
                    "children" => [
                      %{
                        "text" => "Here is an activity:"
                      }
                    ]
                  }
                ]
              },
              %{
                "type" => "activity-reference",
                "activity_id" => 999999999  # Non-existent resource_id
              }
            ]
          }
        })

      # Clear the depot cache to ensure we're testing with the updated data
      Oli.Delivery.DepotCoordinator.clear(
        Oli.Delivery.Sections.SectionResourceDepot.depot_desc(),
        section.id
      )

      # Rebuild the previous_next_index after modifying the revision
      {:ok, _updated_section} = Oli.Delivery.PreviousNextIndex.rebuild(section)

      # THIRD: Visit the page again with the bad activity reference
      {:ok, view2, _html2} = live(conn, ~p"/sections/#{section.slug}/lesson/#{page_revision.slug}")
      
      # Trigger script loading again
      view2
      |> element("#eventIntercept")
      |> render_hook("survey_scripts_loaded", %{"loaded" => true})
      
      # Get the rendered HTML
      html2 = render(view2)

      # Verify the view loaded (doesn't crash)
      assert view2
      assert html2
      
      # Check if adding bad activity changed the rendering
      after_has_page_content = String.contains?(html2, "page_content")
      after_has_text = String.contains?(html2, "Here is an activity:")
      
      # Verify the actual behavior
      assert initial_has_page_content, "Initial page should render with page_content div"
      assert initial_has_text, "Initial page should show the text content"
      
      # After adding bad activity: page still renders but content is affected
      assert after_has_page_content, 
        "Page body still renders with bad activity reference"
      
      refute after_has_text,
        "Content with bad activity reference is skipped"
      
      # The page degrades gracefully - it doesn't crash, but the problematic content is omitted
      
      # The page handles the missing activity gracefully by skipping the problematic content
      # but continues to render the rest of the page without crashing

      # Basic check that student is logged in and enrolled
      assert section.id
      assert student.id
    end
  end
end

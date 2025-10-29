defmodule OliWeb.Components.Delivery.LearningObjectives.ExpandedObjectiveViewTest do
  use OliWeb.ConnCase, async: true

  import LiveComponentTests
  import Oli.Factory
  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.LearningObjectives.ExpandedObjectiveView
  alias Oli.Delivery.Sections

  describe "ExpandedObjectiveView component" do
    setup %{conn: conn} do
      # Create test data using factories
      author = insert(:author)
      project = insert(:project, authors: [author])

      # Create a published section with objectives
      _publication = insert(:publication, project: project, published: nil)

      _published_publication =
        insert(:publication, project: project, published: DateTime.utc_now())

      section = insert(:section, base_project: project)

      # Create objective resource
      objective =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("objective")
        )

      # Create SectionResource record needed for the depot
      insert(:section_resource,
        section: section,
        resource_id: objective.resource_id,
        title: objective.title || "Test Objective",
        revision_id: objective.id,
        children: []
      )

      # Create some enrolled students
      student1 = insert(:user)
      student2 = insert(:user)
      student3 = insert(:user)
      instructor = insert(:user)

      # Enroll students and instructor
      {:ok, _enrollment1} =
        Sections.enroll(student1.id, section.id, [
          Lti_1p3.Roles.ContextRoles.get_role(:context_learner)
        ])

      {:ok, _enrollment2} =
        Sections.enroll(student2.id, section.id, [
          Lti_1p3.Roles.ContextRoles.get_role(:context_learner)
        ])

      {:ok, _enrollment3} =
        Sections.enroll(student3.id, section.id, [
          Lti_1p3.Roles.ContextRoles.get_role(:context_learner)
        ])

      {:ok, _enrollment_instructor} =
        Sections.enroll(instructor.id, section.id, [
          Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
        ])

      %{
        conn: conn,
        section: section,
        objective: objective,
        students: [student1, student2, student3],
        instructor: instructor
      }
    end

    test "renders correctly with basic objective data", %{
      conn: conn,
      section: section,
      objective: objective,
      instructor: instructor
    } do
      objective_data = %{
        resource_id: objective.resource_id,
        title: objective.title || "Test Objective"
      }

      {:ok, view, _html} =
        live_component_isolated(conn, ExpandedObjectiveView, %{
          id: "expanded-objective-test",
          unique_id: "test-#{objective.resource_id}",
          objective: objective_data,
          section_id: section.id,
          section_slug: section.slug,
          current_user: instructor,
          sync_load: true,
          is_expanded: true
        })

      # Data loads synchronously when sync_load and is_expanded are true
      assert has_element?(view, "h3", ~r/Estimated Learning:/)
      assert has_element?(view, "h3", ~r/\d+ Students?/)
    end

    test "displays correct student count", %{
      conn: conn,
      section: section,
      objective: objective,
      instructor: instructor
    } do
      objective_data = %{
        resource_id: objective.resource_id,
        title: objective.title || "Test Objective"
      }

      {:ok, view, _html} =
        live_component_isolated(conn, ExpandedObjectiveView, %{
          id: "expanded-objective-test",
          unique_id: "test-#{objective.resource_id}",
          objective: objective_data,
          section_id: section.id,
          section_slug: section.slug,
          current_user: instructor,
          sync_load: true,
          is_expanded: true
        })

      # Should show 3 students (excluding instructor)
      assert has_element?(view, "h3", "Estimated Learning: 3 Students")
    end

    test "handles singular student count correctly", %{
      conn: conn,
      section: section,
      objective: objective,
      instructor: instructor
    } do
      # Create a section with only one student
      single_student_section = insert(:section, base_project: section.base_project)
      single_student = insert(:user)

      {:ok, _enrollment} =
        Sections.enroll(single_student.id, single_student_section.id, [
          Lti_1p3.Roles.ContextRoles.get_role(:context_learner)
        ])

      {:ok, _enrollment_instructor} =
        Sections.enroll(instructor.id, single_student_section.id, [
          Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
        ])

      objective_data = %{
        resource_id: objective.resource_id,
        title: objective.title || "Test Objective"
      }

      {:ok, view, _html} =
        live_component_isolated(conn, ExpandedObjectiveView, %{
          id: "expanded-objective-test",
          unique_id: "test-#{objective.resource_id}",
          objective: objective_data,
          section_id: single_student_section.id,
          section_slug: single_student_section.slug,
          current_user: instructor,
          sync_load: true,
          is_expanded: true
        })

      # Should show "1 Student" (singular)
      assert has_element?(view, "h3", "Estimated Learning: 1 Student")
    end

    test "renders dots chart component", %{
      conn: conn,
      section: section,
      objective: objective,
      instructor: instructor
    } do
      objective_data = %{
        resource_id: objective.resource_id,
        title: objective.title || "Test Objective"
      }

      {:ok, view, _html} =
        live_component_isolated(conn, ExpandedObjectiveView, %{
          id: "expanded-objective-test",
          unique_id: "test-#{objective.resource_id}",
          objective: objective_data,
          section_id: section.id,
          section_slug: section.slug,
          current_user: instructor,
          sync_load: true,
          is_expanded: true
        })

      # Check that the DotDistributionChart React component is rendered
      assert has_element?(view, "[data-live-react-class='Components.DotDistributionChart']")
      assert has_element?(view, "#dot-distribution-chart-test-#{objective.resource_id}")
    end

    test "handles no sub-objectives case", %{
      conn: conn,
      section: section,
      objective: objective,
      instructor: instructor
    } do
      objective_data = %{
        resource_id: objective.resource_id,
        title: objective.title || "Test Objective"
      }

      {:ok, view, _html} =
        live_component_isolated(conn, ExpandedObjectiveView, %{
          id: "expanded-objective-test",
          unique_id: "test-#{objective.resource_id}",
          objective: objective_data,
          section_id: section.id,
          section_slug: section.slug,
          current_user: instructor,
          sync_load: true,
          is_expanded: true
        })

      # Should show "No sub-objectives found" when there are no sub-objectives
      assert has_element?(view, "div", "No sub-objectives found")
    end

    test "assigns are correctly set", %{
      conn: conn,
      section: section,
      objective: objective,
      instructor: instructor
    } do
      objective_data = %{
        resource_id: objective.resource_id,
        title: objective.title || "Test Objective"
      }

      {:ok, view, _html} =
        live_component_isolated(conn, ExpandedObjectiveView, %{
          id: "expanded-objective-test",
          unique_id: "test-#{objective.resource_id}",
          objective: objective_data,
          section_id: section.id,
          section_slug: section.slug,
          current_user: instructor,
          sync_load: true,
          is_expanded: true
        })

      # Check that the component renders with correct data structure
      # Instead of accessing internal assigns, we verify rendered content
      assert has_element?(view, ".expanded-objective-view")
      assert has_element?(view, "h3", "Estimated Learning: 3 Students")
      assert has_element?(view, "[data-live-react-class='Components.DotDistributionChart']")
    end

    test "handles missing objective title gracefully", %{
      conn: conn,
      section: section,
      objective: objective,
      instructor: instructor
    } do
      objective_data = %{
        resource_id: objective.resource_id,
        title: nil
      }

      {:ok, view, _html} =
        live_component_isolated(conn, ExpandedObjectiveView, %{
          id: "expanded-objective-test",
          unique_id: "test-#{objective.resource_id}",
          objective: objective_data,
          section_id: section.id,
          section_slug: section.slug,
          current_user: instructor,
          sync_load: true,
          is_expanded: true
        })

      # Should still render without errors
      assert has_element?(view, ".expanded-objective-view")
      assert has_element?(view, "h3", ~r/Estimated Learning:/)
    end

    test "excludes instructors from student count", %{
      conn: conn,
      section: section,
      objective: objective,
      instructor: instructor
    } do
      # Add another instructor
      instructor2 = insert(:user)

      {:ok, _enrollment} =
        Sections.enroll(instructor2.id, section.id, [
          Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
        ])

      objective_data = %{
        resource_id: objective.resource_id,
        title: objective.title || "Test Objective"
      }

      {:ok, view, _html} =
        live_component_isolated(conn, ExpandedObjectiveView, %{
          id: "expanded-objective-test",
          unique_id: "test-#{objective.resource_id}",
          objective: objective_data,
          section_id: section.id,
          section_slug: section.slug,
          current_user: instructor,
          sync_load: true,
          is_expanded: true
        })

      # Should still show 3 students (instructors excluded)
      assert has_element?(view, "h3", "Estimated Learning: 3 Students")
    end

    test "handles empty section gracefully", %{
      conn: conn,
      objective: objective,
      instructor: instructor
    } do
      # Create section with no students
      empty_section = insert(:section)

      {:ok, _enrollment} =
        Sections.enroll(instructor.id, empty_section.id, [
          Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
        ])

      objective_data = %{
        resource_id: objective.resource_id,
        title: objective.title || "Test Objective"
      }

      {:ok, view, _html} =
        live_component_isolated(conn, ExpandedObjectiveView, %{
          id: "expanded-objective-test",
          unique_id: "test-#{objective.resource_id}",
          objective: objective_data,
          section_id: empty_section.id,
          section_slug: empty_section.slug,
          current_user: instructor,
          sync_load: true,
          is_expanded: true
        })

      # Should show 0 students
      assert has_element?(view, "h3", "Estimated Learning: 0 Students")
      assert has_element?(view, ".expanded-objective-view")
    end
  end
end

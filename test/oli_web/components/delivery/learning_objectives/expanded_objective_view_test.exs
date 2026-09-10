defmodule OliWeb.Components.Delivery.LearningObjectives.ExpandedObjectiveViewTest do
  use OliWeb.ConnCase, async: true

  import LiveComponentTests
  import Oli.Factory
  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.LearningObjectives.ExpandedObjectiveView
  alias OliWeb.Components.Delivery.LearningObjectives.StudentDistributionMatrix
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
      assert has_element?(view, "h3", ~r/Student Distribution:/)
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
      assert has_element?(view, "h3", "Student Distribution: 3 Students")
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
      assert has_element?(view, "h3", "Student Distribution: 1 Student")
    end

    test "renders the Student Distribution matrix", %{
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

      # The HEEx/SVG matrix renders the three group regions, none selected by default.
      assert has_element?(
               view,
               "svg[aria-label='Student distribution matrix']"
             )

      assert has_element?(view, "g[aria-label^='Needs Support']")
      assert has_element?(view, "g[aria-label^='Excelling']")
      assert has_element?(view, "g[aria-label^='Limited Activity']")
      refute has_element?(view, "g[aria-pressed='true']")
    end

    test "renders all student dots inactive when no group is selected" do
      html =
        render_component(&StudentDistributionMatrix.matrix/1,
          students: student_distribution_matrix_fixture(),
          selected_group: nil,
          myself: nil,
          unique_id: "dot-state-test"
        )

      circles =
        html
        |> Floki.parse_fragment!()
        |> Floki.find("g[data-student-points='true'] circle")

      assert length(circles) == 3

      [needs_support_dot, excelling_dot, limited_activity_dot] =
        Enum.map(circles, &(Floki.attribute(&1, "class") |> List.first()))

      assert needs_support_dot =~ "fill-Graph-dot-low-inactive"
      assert excelling_dot =~ "fill-Graph-dot-high-inactive"
      assert limited_activity_dot =~ "fill-Graph-dot-notenoughinfo-inactive"

      refute needs_support_dot =~ "fill-Graph-dot-low-active"
      refute excelling_dot =~ "fill-Graph-dot-high-active"
      refute limited_activity_dot =~ "fill-Graph-dot-notenoughinfo-active"

      refute Enum.any?(
               [needs_support_dot, excelling_dot, limited_activity_dot],
               &(&1 =~ "stroke-white")
             )

      assert circles
             |> Enum.flat_map(&Floki.attribute(&1, "stroke-width"))
             |> Enum.all?(&(&1 == "0"))

      refute html =~ "<title>Student distribution matrix</title>"
    end

    test "renders only the selected group's student dots active" do
      html =
        render_component(&StudentDistributionMatrix.matrix/1,
          students: student_distribution_matrix_fixture(),
          selected_group: :excelling,
          myself: nil,
          unique_id: "dot-state-test"
        )

      circles =
        html
        |> Floki.parse_fragment!()
        |> Floki.find("g[data-student-points='true'] circle")

      assert length(circles) == 3

      [needs_support_dot, excelling_dot, limited_activity_dot] =
        Enum.map(circles, &(Floki.attribute(&1, "class") |> List.first()))

      assert needs_support_dot =~ "fill-Graph-dot-low-inactive"
      assert excelling_dot =~ "fill-Graph-dot-high-active"
      assert limited_activity_dot =~ "fill-Graph-dot-notenoughinfo-inactive"

      refute needs_support_dot =~ "fill-Graph-dot-low-active"
      refute excelling_dot =~ "fill-Graph-dot-high-inactive"
      refute limited_activity_dot =~ "fill-Graph-dot-notenoughinfo-active"

      assert excelling_dot =~ "stroke-white"
      refute needs_support_dot =~ "stroke-white"
      refute limited_activity_dot =~ "stroke-white"

      assert circles |> Enum.at(1) |> Floki.attribute("stroke-width") == ["1.5"]
    end

    test "student dots dispatch the same group selection event as their region" do
      html =
        render_component(&StudentDistributionMatrix.matrix/1,
          students: student_distribution_matrix_fixture(),
          selected_group: nil,
          myself: nil,
          unique_id: "dot-click-test"
        )

      circles =
        html
        |> Floki.parse_fragment!()
        |> Floki.find("g[data-student-points='true'] circle")

      assert length(circles) == 3

      assert circles
             |> Enum.map(&Floki.attribute(&1, "phx-click"))
             |> Enum.all?(&(&1 == ["select_student_group"]))

      assert circles
             |> Enum.flat_map(&Floki.attribute(&1, "phx-value-group"))
             |> Enum.sort() == ["excelling", "limited_activity", "needs_support"]
    end

    test "region labels use the hover fade hook without blocking dots or regions" do
      html =
        render_component(&StudentDistributionMatrix.matrix/1,
          students: student_distribution_matrix_fixture(),
          selected_group: nil,
          myself: nil,
          unique_id: "badge-hover-test"
        )

      assert html =~ ~s(id="student-distribution-matrix-badge-hover-test")
      assert html =~ ~s(phx-hook="StudentDistributionMatrixLabels")

      badges =
        html
        |> Floki.parse_fragment!()
        |> Floki.find("g[data-count-badge='true']")

      assert length(badges) == 3

      assert badges
             |> Enum.map(&Floki.attribute(&1, "class"))
             |> Enum.all?(fn classes ->
               [class] = classes
               class =~ "pointer-events-none" and class =~ "transition-opacity"
             end)

      assert badges
             |> Enum.map(&Floki.attribute(&1, "phx-click"))
             |> Enum.all?(&(&1 == []))
    end

    test "renders Figma dark-mode token mappings for labels and limited activity region" do
      html =
        render_component(&StudentDistributionMatrix.matrix/1,
          students: student_distribution_matrix_fixture(),
          selected_group: nil,
          myself: nil,
          unique_id: "dark-token-test"
        )

      assert html =~ "fill-Graph-region-limited-activity"
      assert html =~ "fill-Icon-icon-white"
      assert html =~ "fill-Black-Alpha-000"
      assert html =~ "fill-Text-text-charcoal"
    end

    test "selecting a region highlights it and only one region is selected at a time", %{
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

      view
      |> element("g[aria-label^='Needs Support']")
      |> render_click(%{"group" => "needs_support"})

      assert has_element?(view, "g[aria-label^='Needs Support'][aria-pressed='true']")
      assert has_element?(view, "g[aria-label^='Excelling'][aria-pressed='false']")

      view
      |> element("g[aria-label^='Excelling']")
      |> render_click(%{"group" => "excelling"})

      assert has_element?(view, "g[aria-label^='Excelling'][aria-pressed='true']")
      assert has_element?(view, "g[aria-label^='Needs Support'][aria-pressed='false']")
    end

    test "selecting the same region again deselects it", %{
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

      view
      |> element("g[aria-label^='Limited Activity']")
      |> render_click(%{"group" => "limited_activity"})

      assert has_element?(view, "g[aria-label^='Limited Activity'][aria-pressed='true']")

      view
      |> element("g[aria-label^='Limited Activity']")
      |> render_click(%{"group" => "limited_activity"})

      refute has_element?(view, "g[aria-pressed='true']")
    end

    test "keyboard activation (Enter) selects a region the same as a click", %{
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

      view
      |> element("g[aria-label^='Excelling']")
      |> render_keydown(%{"group" => "excelling", "key" => "Enter"})

      assert has_element?(view, "g[aria-label^='Excelling'][aria-pressed='true']")
    end

    test "keyboard activation (Space) selects a region the same as a click", %{
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

      view
      |> element("g[aria-label^='Excelling']")
      |> render_keydown(%{"group" => "excelling", "key" => " "})

      assert has_element?(view, "g[aria-label^='Excelling'][aria-pressed='true']")
    end

    test "an unrelated keydown while a region has focus does not select it", %{
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

      view
      |> element("g[aria-label^='Excelling']")
      |> render_keydown(%{"group" => "excelling", "key" => "Tab"})

      refute has_element?(view, "g[aria-pressed='true']")
    end

    test "an unrecognized group value is ignored instead of selecting anything", %{
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

      # A tampered/unexpected phx-value-group (e.g. a stale client or a hand-crafted socket
      # message) must not select a region or raise, even though the DOM element itself only
      # ever sends real group values.
      view
      |> element("g[aria-label^='Excelling']")
      |> render_click(%{"group" => "bogus"})

      refute has_element?(view, "g[aria-pressed='true']")
    end

    test "selecting and deselecting a region does not change the underlying student counts", %{
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

      assert has_element?(view, "h3", "Student Distribution: 3 Students")
      assert has_element?(view, "g[aria-label^='Limited Activity, 3 students']")

      view
      |> element("g[aria-label^='Limited Activity']")
      |> render_click(%{"group" => "limited_activity"})

      assert has_element?(view, "h3", "Student Distribution: 3 Students")
      assert has_element?(view, "g[aria-label^='Limited Activity, 3 students']")

      view
      |> element("g[aria-label^='Limited Activity']")
      |> render_click(%{"group" => "limited_activity"})

      assert has_element?(view, "h3", "Student Distribution: 3 Students")
      assert has_element?(view, "g[aria-label^='Limited Activity, 3 students']")
    end

    test "widens the linked-activity denominator to include effective sub-objectives", %{
      conn: conn,
      section: section,
      objective: objective,
      students: [student1, _student2, _student3],
      instructor: instructor
    } do
      objective_type_id = Oli.Resources.ResourceType.get_id_by_type("objective")
      activity_type_id = Oli.Resources.ResourceType.get_id_by_type("activity")
      activity_a = insert(:resource)
      activity_b = insert(:resource)

      sub_objective = insert(:revision, resource_type_id: objective_type_id)

      sub_objective_section_resource =
        insert(:section_resource,
          section: section,
          resource_id: sub_objective.resource_id,
          resource_type_id: objective_type_id,
          title: sub_objective.title,
          revision_id: sub_objective.id,
          children: [],
          related_activities: [activity_b.id]
        )

      parent_section_resource =
        Oli.Repo.get_by!(Oli.Delivery.Sections.SectionResource,
          section_id: section.id,
          resource_id: objective.resource_id
        )

      # Touch the depot once before applying the test-specific hierarchy, so the direct
      # cache pushes below are not later replaced by the depot's own one-time JIT
      # migration/projection (which recomputes `children` from published revision data and
      # would otherwise overwrite this test's manually-wired parent/sub-objective link).
      Oli.Delivery.Sections.SectionResourceDepot.get_section_resource(
        section.id,
        objective.resource_id
      )

      {:ok, parent_section_resource} =
        Oli.Delivery.Sections.update_section_resource(parent_section_resource, %{
          resource_type_id: objective_type_id,
          children: [sub_objective_section_resource.id],
          related_activities: [activity_a.id]
        })

      Oli.Delivery.Sections.SectionResourceDepot.update_section_resource(parent_section_resource)

      Oli.Delivery.Sections.SectionResourceDepot.update_section_resource(
        sub_objective_section_resource
      )

      # student1 attempted only the sub-objective's activity (activity_b), never the parent
      # objective's own activity (activity_a).
      insert(:resource_summary,
        section_id: section.id,
        user_id: student1.id,
        resource_id: activity_b.id,
        resource_type_id: activity_type_id,
        num_attempts: 1
      )

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

      # With the widened denominator (activity_a union activity_b = 2 linked activities),
      # student1 has attempted 1 of 2 (50% activity completion, "high activity") with no
      # proficiency estimate (0.0, "Not enough data"), landing in Needs Support. The other
      # two students have 0 attempts out of 2 and stay in Limited Activity. If the
      # denominator were not widened (parent's activity_a only, which nobody attempted),
      # student1's attempted count against that single-activity list would be 0, giving 0%
      # activity completion, and they would incorrectly remain in Limited Activity instead.
      assert has_element?(view, "g[aria-label^='Needs Support, 1 student']")
      assert has_element?(view, "g[aria-label^='Limited Activity, 2 students']")
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
      assert has_element?(view, "h3", "Student Distribution: 3 Students")

      assert has_element?(
               view,
               "svg[aria-label='Student distribution matrix']"
             )
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
      assert has_element?(view, "h3", ~r/Student Distribution:/)
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
      assert has_element?(view, "h3", "Student Distribution: 3 Students")
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
      assert has_element?(view, "h3", "Student Distribution: 0 Students")
      assert has_element?(view, ".expanded-objective-view")
    end
  end

  describe "deselect_student_group/2" do
    # No rendered control currently calls this event -- see the comment on the handler
    # itself. Tested directly at the callback level so a future close control can be wired
    # to it with confidence the behavior it dispatches to is already correct.
    test "clears the selected group and does not raise" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          selected_student_group: :needs_support,
          section_id: 1,
          objective_id: 2
        }
      }

      assert {:noreply, updated_socket} =
               ExpandedObjectiveView.handle_event("deselect_student_group", %{}, socket)

      assert updated_socket.assigns.selected_student_group == nil
    end
  end

  defp student_distribution_matrix_fixture do
    [
      %{
        id: 1,
        full_name: "Needs Support Student",
        distribution_group: :needs_support,
        proficiency_range: "Low",
        proficiency: 0.25,
        activity_completion: 0.75
      },
      %{
        id: 2,
        full_name: "Excelling Student",
        distribution_group: :excelling,
        proficiency_range: "High",
        proficiency: 0.9,
        activity_completion: 0.8
      },
      %{
        id: 3,
        full_name: "Limited Activity Student",
        distribution_group: :limited_activity,
        proficiency_range: "Not enough data",
        proficiency: 0.0,
        activity_completion: 0.25
      }
    ]
  end
end

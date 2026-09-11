defmodule OliWeb.Delivery.InstructorDashboard.LearningObjectivesTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Ecto.Query
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.ContainedObjective
  alias Oli.Repo
  alias Oli.Resources.ResourceType

  defp live_view_learning_objectives_route(section_slug, params \\ %{}) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :insights,
      :learning_objectives,
      params
    )
  end

  defp search(view, term),
    do:
      view
      |> element("form[phx-change='search_objective']")
      |> render_change(%{"objective_name" => term})

  # A collapsed row renders no aria-expanded attribute; an expanded one does.
  defp expanded?(view, resource_id),
    do: has_element?(view, "[aria-controls='details-row_#{resource_id}'][aria-expanded]")

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)

      redirect_path =
        "/users/log_in"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_learning_objectives_route(section.slug))
    end
  end

  describe "student" do
    setup [:user_conn]

    test "can not access page", %{user: user, conn: conn} do
      section = insert(:section)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_learning_objectives_route(section.slug))
    end
  end

  describe "instructor" do
    setup [:instructor_conn, :create_project_with_objectives]

    test "cannot access page if not enrolled to section", %{conn: conn, section: section} do
      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_learning_objectives_route(section.slug))
    end

    test "can access page if enrolled to section", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      # LearningObjectives tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_learning_objectives_route(section.slug)}"].border-b-2},
               "Learning Objectives"
             )

      # LearningObjectives tab content gets rendered
      assert has_element?(view, "h4", "Learning Objectives")
    end
  end

  describe "objectives" do
    setup [:instructor_conn, :create_project_with_objectives]

    test "deep-link params load learning objectives without normalizing the url", %{
      conn: conn,
      instructor: instructor,
      section: section,
      obj_revision_1: obj_revision_1
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.update_section(section, %{v25_migration: :not_started})

      params = %{
        "objective_id" => Integer.to_string(obj_revision_1.resource_id),
        "navigation_source" => "challenging_objectives_tile"
      }

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

      assert has_element?(view, "h4", "Learning Objectives")
      expected_row_id = "row_#{obj_revision_1.resource_id}"

      assert_push_event(view, "learning-objectives-scroll", %{
        id: ^expected_row_id
      })
    end

    test "loads correctly when there are no objectives", %{
      conn: conn,
      instructor: instructor
    } do
      # `base_project_with_larger_hierarchy/0` gives a section with real, populated
      # section resources (required for `decorated_numbering_map/1`, used by this tab's
      # suppression-aware container navigator) but no objective-type resources at all --
      # a realistic "course with content but no objectives yet" section, unlike a bare
      # `insert(:section, ...)`, which has no section resources and cannot occur via any
      # real section-creation flow.
      %{section: section} = Oli.Seeder.base_project_with_larger_hierarchy()

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      refute has_element?(view, "#objectives-table")
      assert has_element?(view, "h6", "There are no objectives to show")
    end

    test "container navigator dropdown shows suppression-aware unit/module numbering", %{
      conn: conn,
      instructor: instructor
    } do
      %{
        section: section,
        unit1_resource: unit1_resource
      } = Oli.Seeder.base_project_with_larger_hierarchy()

      {:ok, section} =
        Sections.update_section(section, %{unnumbered_unit_ids: [unit1_resource.id]})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      normalized_text =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.text()
        |> String.replace(~r/\s+/, " ")

      # Unit 1 (suppressed) shows only its bare title in the navigator, no "Unit : " prefix;
      # Unit 2 is renumbered to "Unit 1" since Unit 1 no longer consumes a numbering slot.
      refute normalized_text =~ "Unit : "
      assert normalized_text =~ "Unit 1: Unit 2"
    end

    test "container navigator dropdown keeps a suppressed middle unit in its document position",
         %{conn: conn, instructor: instructor} do
      author = insert(:author)
      project = insert(:project, authors: [author])

      unit_a =
        insert(:revision, resource_type_id: ResourceType.id_for_container(), title: "Alpha")

      unit_b = insert(:revision, resource_type_id: ResourceType.id_for_container(), title: "Beta")

      unit_c =
        insert(:revision, resource_type_id: ResourceType.id_for_container(), title: "Gamma")

      container_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_container(),
          children: [unit_a.resource_id, unit_b.resource_id, unit_c.resource_id],
          title: "Root Container"
        )

      all_revisions = [unit_a, unit_b, unit_c, container_revision]

      Enum.each(all_revisions, fn revision ->
        insert(:project_resource, project_id: project.id, resource_id: revision.resource_id)
      end)

      publication =
        insert(:publication, project: project, root_resource_id: container_revision.resource_id)

      Enum.each(all_revisions, fn revision ->
        insert(:published_resource,
          publication: publication,
          resource: revision.resource,
          revision: revision,
          author: author
        )
      end)

      section =
        insert(:section,
          base_project: project,
          context_id: UUID.uuid4(),
          open_and_free: true,
          registration_open: true,
          type: :enrollable
        )

      {:ok, section} = Sections.create_section_resources(section, publication)

      {:ok, section} =
        Sections.update_section(section, %{unnumbered_unit_ids: [unit_b.resource_id]})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      item_titles =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{[data-list-navigator-option] [title]})
        |> Enum.map(&(Floki.attribute(&1, "title") |> List.first()))
        |> Enum.reject(&(&1 in [nil, "All"]))

      # Beta (suppressed, no number) must stay between Alpha and Gamma -- their real
      # document order -- not get pushed to the end of the list by its nil
      # numbering_index.
      assert item_titles == ["Alpha", "Beta", "Gamma"]
    end

    test "does not show objectives that are not root-contained", %{
      conn: conn,
      instructor: instructor,
      section: section,
      project: project,
      obj_revision_1: obj_revision_1
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.update_section(section, %{v25_migration: :not_started})

      stale_objective_resource = insert(:resource)

      stale_objective_revision =
        insert(:revision, %{
          resource: stale_objective_resource,
          objectives: %{},
          resource_type_id: Oli.Resources.ResourceType.id_for_objective(),
          children: [],
          content: %{},
          deleted: false,
          slug: "old_dnu_objective",
          title: "OLD DNU Objective"
        })

      stale_section_resource =
        insert(:section_resource, %{
          section: section,
          project: project,
          resource_id: stale_objective_resource.id,
          revision_id: stale_objective_revision.id,
          resource_type_id: Oli.Resources.ResourceType.id_for_objective(),
          title: stale_objective_revision.title,
          slug: stale_objective_revision.slug,
          children: []
        })

      Oli.Delivery.Sections.SectionResourceDepot.update_section_resource(stale_section_resource)

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      assert has_element?(view, "#objectives-table")
      assert has_element?(view, "span", obj_revision_1.title)
      refute has_element?(view, "span", stale_objective_revision.title)
    end

    test "applies searching", %{
      conn: conn,
      instructor: instructor,
      section: section,
      obj_revision_1: obj_revision_1,
      obj_revision_2: obj_revision_2
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.update_section(section, %{v25_migration: :not_started})

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      assert has_element?(view, "#objectives-table")
      assert has_element?(view, "span", "#{obj_revision_1.title}")
      assert has_element?(view, "span", "#{obj_revision_2.title}")

      ## searching by objective
      params = %{
        text_search: "Objective 1"
      }

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

      assert has_element?(view, "span", "#{obj_revision_1.title}")
      refute has_element?(view, "span", "#{obj_revision_2.title}")
    end

    test "applies sorting", %{
      conn: conn,
      instructor: instructor,
      section: section,
      obj_revision_1: obj_revision_1,
      obj_revision_2: obj_revision_2
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.update_section(section, %{v25_migration: :not_started})

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      assert view
             |> element(
               "#objectives-table table.instructor_dashboard_table > tbody > tr[data-row-id='row_#{obj_revision_1.resource_id}'] > td:nth-child(2)"
             )
             |> render() =~ obj_revision_1.title

      assert view
             |> element(
               "#objectives-table table.instructor_dashboard_table > tbody > tr[data-row-id='row_#{obj_revision_2.resource_id}'] > td:nth-child(2)"
             )
             |> render() =~ obj_revision_2.title

      ## sorting by objective
      params = %{sort_order: :desc}
      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

      assert view
             |> element(
               "#objectives-table table.instructor_dashboard_table > tbody > tr[data-row-id='row_#{obj_revision_2.resource_id}'] > td:nth-child(2)"
             )
             |> render() =~ obj_revision_2.title

      assert view
             |> element(
               "#objectives-table table.instructor_dashboard_table > tbody > tr[data-row-id='row_#{obj_revision_1.resource_id}'] > td:nth-child(2)"
             )
             |> render() =~ obj_revision_1.title
    end

    test "applies pagination", %{
      conn: conn,
      instructor: instructor,
      section: section,
      obj_revision_1: obj_revision_1,
      obj_revision_2: obj_revision_2
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.update_section(section, %{v25_migration: :not_started})
      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      assert has_element?(view, "span", "#{obj_revision_1.title}")
      assert has_element?(view, "span", "#{obj_revision_2.title}")

      ## aplies pagination
      params = %{
        limit: 1
      }

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

      assert has_element?(view, "span", "#{obj_revision_1.title}")
      refute has_element?(view, "span", "#{obj_revision_2.title}")

      ## aplies pagination
      params = %{
        offset: 1
      }

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

      refute has_element?(view, "span", "#{obj_revision_1.title}")
      assert has_element?(view, "span", "#{obj_revision_2.title}")
    end

    test "display proficiency distribution", %{
      conn: conn,
      instructor: instructor,
      section: section,
      obj_revision_1: obj_revision_1,
      obj_revision_2: obj_revision_2
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.update_section(section, %{v25_migration: :not_started})
      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      assert has_element?(
               view,
               "#proficiency-data-bar-chart-for-objective-#{obj_revision_1.resource_id}"
             )

      assert has_element?(
               view,
               "#proficiency-data-bar-chart-for-objective-#{obj_revision_2.resource_id}"
             )

      html = render(view)

      for color <- ~w(#CED1D9 #CE2C31 #BF5B13 #218358 #353740 #FF8787 #FFB387 #39E581) do
        assert html =~ color
      end

      chart_props =
        html
        |> Floki.parse_fragment!()
        |> Floki.find("#proficiency-data-bar-chart-for-objective-#{obj_revision_1.resource_id}")
        |> Floki.attribute("data-live-react-props")
        |> hd()
        |> Jason.decode!()

      assert chart_props["spec"]["mark"] == %{"type" => "bar", "binSpacing" => 2}
      assert chart_props["spec"]["encoding"]["x"]["bin"] == "binned"
    end
  end

  describe "objectives filtering" do
    setup [:instructor_conn, :create_full_project_with_objectives]
    ## Course Hierarchy
    #
    # Root Container --> Page 1 --> Activity X
    #                |--> Unit Container --> Module Container 1 --> Page 2 --> Activity Y
    #                |                                                     |--> Activity Z
    #                |--> Module Container 2 --> Page 3 --> Activity W
    #
    ## Objectives Hierarchy
    #
    # Page 1 --> Objective A
    # Page 2 --> Objective B
    #
    # Note: the objectives above are not considered since they are attached to the pages
    #
    # Activity Y --> Objective C
    #           |--> SubObjective C1
    # Activity Z --> Objective D
    # Activity W --> Objective E
    #           |--> Objective F
    #
    # Note: Activity X does not have objectives
    @tag :skip
    test "applies filtering by module when contained objectives were created", %{
      conn: conn,
      instructor: instructor,
      section: section,
      revisions: revisions
    } do
      # Setup section data
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.rebuild_contained_objectives(section)

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      assert has_element?(view, "#objectives-table")

      refute has_element?(view, "span", "#{revisions.obj_revision_a.title}")
      refute has_element?(view, "span", "#{revisions.obj_revision_b.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      assert has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      ## searching by Unit Container
      params = %{
        filter_by: revisions.unit_revision.resource_id
      }

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

      assert has_element?(view, "#objectives-table")
      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      assert has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      refute has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      refute has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      ## searching by Module Container 2
      params = %{
        filter_by: revisions.module_revision_2.resource_id
      }

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

      assert has_element?(view, "#objectives-table")
      refute has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      refute has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      refute has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      # Does not have info tooltip
      refute has_element?(view, "#filter-disabled-tooltip")
      # Select is enabled
      refute has_element?(view, ".torus-select[disabled]")
    end

    test "does not allow filtering by module when section has the wrong migration status", %{
      conn: conn,
      instructor: instructor,
      section: section,
      revisions: revisions
    } do
      # Setup section data
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.rebuild_contained_objectives(section)
      Sections.update_section(section, %{v25_migration: :not_started})

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      assert has_element?(view, "#objectives-table")
      assert has_element?(view, "span", "#{revisions.obj_revision_a.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_b.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      ## List navigator is not displayed
      refute has_element?(view, "#objectives_containers_navigator")
    end

    test "filter by proficiency works correctly", %{
      conn: conn,
      instructor: instructor,
      section: section,
      revisions: revisions
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      ## Checks that all objectives are displayed
      assert has_element?(view, "span", "#{revisions.obj_revision_a.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_b.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")

      ## Set proficiency filter to Low
      params = %{
        selected_proficiency_ids: Jason.encode!([1])
      }

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))
      ## Checks that there are no objectives displayed since none of them have proficiency Low
      assert has_element?(view, "h6", "There are no objectives to show")

      ## Click on Clear All Filters button
      element(view, "button[phx-click='clear_all_filters']") |> render_click()

      ## Checks that all objectives are displayed again
      assert has_element?(view, "span", "#{revisions.obj_revision_a.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_b.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
    end

    test "searching for a subobjective shows and expands its parent objective", %{
      conn: conn,
      instructor: instructor,
      section: section,
      revisions: revisions
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.rebuild_contained_objectives(section)

      {:ok, view, _html} =
        live(
          conn,
          live_view_learning_objectives_route(section.slug, %{
            offset: 4
          })
        )

      search(view, revisions.obj_revision_c1.title)

      assert_patch(
        view,
        live_view_learning_objectives_route(section.slug, %{
          text_search: revisions.obj_revision_c1.title
        })
      )

      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      assert expanded?(view, revisions.obj_revision_c.resource_id)

      wait_until(fn ->
        has_element?(view, ".search-highlight", revisions.obj_revision_c1.title)
      end)

      refute has_element?(view, "span", "#{revisions.obj_revision_f.title}")
    end

    test "clearing the search collapses the rows the search expanded", %{
      conn: conn,
      instructor: instructor,
      section: section,
      revisions: revisions
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.rebuild_contained_objectives(section)

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      search(view, revisions.obj_revision_c1.title)
      assert expanded?(view, revisions.obj_revision_c.resource_id)

      search(view, "")
      refute expanded?(view, revisions.obj_revision_c.resource_id)
    end

    test "a row collapsed by hand stays collapsed while the search term holds", %{
      conn: conn,
      instructor: instructor,
      section: section,
      revisions: revisions
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.rebuild_contained_objectives(section)

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      search(view, revisions.obj_revision_c1.title)
      assert expanded?(view, revisions.obj_revision_c.resource_id)

      render_click(
        element(view, "[aria-controls='details-row_#{revisions.obj_revision_c.resource_id}']")
      )

      refute expanded?(view, revisions.obj_revision_c.resource_id)

      render_patch(
        view,
        live_view_learning_objectives_route(section.slug, %{
          text_search: revisions.obj_revision_c1.title,
          sort_order: "desc"
        })
      )

      refute expanded?(view, revisions.obj_revision_c.resource_id)
    end

    test "finds a subobjective that is not a row in the objectives table", %{
      conn: conn,
      instructor: instructor,
      section: section,
      revisions: revisions
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.rebuild_contained_objectives(section)

      # Without contained objectives C1 is dropped from the table dataset, but the expanded
      # panel still lists it, so search has to reach it through its parent.
      {deleted, _} =
        Repo.delete_all(
          from(co in ContainedObjective,
            where:
              co.section_id == ^section.id and
                co.objective_id == ^revisions.obj_revision_c1.resource_id
          )
        )

      assert deleted > 0

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      search(view, revisions.obj_revision_c1.title)

      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      refute has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      wait_until(fn ->
        has_element?(view, ".search-highlight", revisions.obj_revision_c1.title)
      end)
    end
  end

  describe "confidence filtering" do
    setup [:instructor_conn, :create_lkt_aoa_project_with_mixed_confidence_children]

    # Regression test for a bug where filtering by Confidence could show a parent
    # objective whose OWN (displayed) confidence did not match the selected filter,
    # because the filter incorrectly promoted the parent into view whenever ANY of
    # its sub-objectives matched, rather than checking the parent's own aggregate.
    test "only shows objectives whose own confidence matches the filter, not a differently-valued child's",
         %{
           conn: conn,
           instructor: instructor,
           section: section,
           revisions: revisions
         } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      # The parent's confidence is the attempt-weighted average of its two children
      # (High and Low, equal weights), which lands squarely in "Medium".
      params = %{selected_confidence_ids: Jason.encode!([3])}
      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

      refute has_element?(view, "span", "#{revisions.parent_revision.title}")

      params = %{selected_confidence_ids: Jason.encode!([2])}
      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

      assert has_element?(view, "span", "#{revisions.parent_revision.title}")
    end

    # Regression test for the same bug affecting the Student Proficiency filter: a
    # parent objective whose own proficiency did not match the selected filter could
    # still appear because one of its sub-objectives happened to match.
    test "only shows objectives whose own proficiency matches the filter, not a differently-valued child's",
         %{
           conn: conn,
           instructor: instructor,
           section: section,
           revisions: revisions
         } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      # The parent's proficiency is the attempt-weighted average aoa of its two
      # children (High and Low, equal weights), which lands squarely in "Medium".
      params = %{selected_proficiency_ids: Jason.encode!([3])}
      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

      refute has_element?(view, "span", "#{revisions.parent_revision.title}")

      params = %{selected_proficiency_ids: Jason.encode!([2])}
      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))

      assert has_element?(view, "span", "#{revisions.parent_revision.title}")
    end
  end

  describe "page size change" do
    setup [:instructor_conn, :create_full_project_with_objectives]

    test "lists table elements according to the default page size", %{
      conn: conn,
      instructor: instructor,
      section: section,
      revisions: revisions
    } do
      # Setup section data
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.rebuild_contained_objectives(section)

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      # It does not display pagination options
      refute has_element?(view, "nav[aria-label=\"Paging\"]")

      # It displays page size dropdown
      assert has_element?(view, "form select.torus-select option[selected]", "20")
    end

    @tag :skip
    test "updates page size and list expected elements", %{
      conn: conn,
      section: section,
      instructor: instructor,
      revisions: revisions
    } do
      # Setup section data
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.rebuild_contained_objectives(section)

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      assert has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      # Change page size from default (20) to 2
      view
      |> element("#footer_paging_page_size_form")
      |> render_change(%{limit: "2"})

      # Page 1
      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      assert has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      # Page 2 and 3
      refute has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      refute has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      refute has_element?(view, "span", "#{revisions.obj_revision_f.title}")
    end

    @tag :skip
    test "keeps showing the same elements when changing the page size", %{
      conn: conn,
      section: section,
      instructor: instructor,
      revisions: revisions
    } do
      # Setup section data
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.rebuild_contained_objectives(section)

      # Starts in page 2
      {:ok, view, _html} =
        live(
          conn,
          live_view_learning_objectives_route(section.slug, %{
            limit: 2,
            offset: 2
          })
        )

      # Page 1
      refute has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      refute has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      # Page 2
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      # Page 3
      refute has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      # Change page size from 2 to 1
      view
      |> element("#footer_paging_page_size_form")
      |> render_change(%{limit: "1"})

      # Page 1
      refute has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      # Page 2
      refute has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      # Page 3. It keeps showing the same element.
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      # Page 4
      refute has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      # Page 5
      refute has_element?(view, "span", "#{revisions.obj_revision_f.title}")

      # Change page size from 1 to 3
      view
      |> element("#footer_paging_page_size_form")
      |> render_change(%{limit: "3"})

      # Page 1. Still showing the same element.
      assert has_element?(view, "span", "#{revisions.obj_revision_c.title}")
      assert has_element?(view, "div", "#{revisions.obj_revision_c1.title}")
      assert has_element?(view, "span", "#{revisions.obj_revision_d.title}")
      # Page 2
      refute has_element?(view, "span", "#{revisions.obj_revision_e.title}")
      refute has_element?(view, "span", "#{revisions.obj_revision_f.title}")
    end
  end

  describe "deep-link initialization" do
    setup [:instructor_conn, :create_full_project_with_objectives]

    test "subobjective deep links expand the selected subobjective row", %{
      conn: conn,
      instructor: instructor,
      section: section,
      revisions: revisions
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.rebuild_contained_objectives(section)

      params = %{
        "objective_id" => Integer.to_string(revisions.obj_revision_c.resource_id),
        "subobjective_id" => Integer.to_string(revisions.obj_revision_c1.resource_id),
        "navigation_source" => "challenging_objectives_tile"
      }

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug, params))
      expected_id = "subobj-#{revisions.obj_revision_c1.resource_id}"

      assert_push_event(view, "learning-objectives-scroll", %{
        id: ^expected_id
      })

      assert expanded?(view, revisions.obj_revision_c.resource_id)
    end

    test "invalid deep-link ids fall back without crashing or forcing expansion", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.rebuild_contained_objectives(section)

      {:ok, view, _html} =
        live(
          conn,
          live_view_learning_objectives_route(section.slug, %{
            objective_id: 999_999,
            subobjective_id: 999_998,
            navigation_source: "challenging_objectives_tile"
          })
        )

      assert has_element?(view, "h4", "Learning Objectives")
      refute has_element?(view, "button[aria-expanded='true']")
    end
  end

  describe "linked activities column" do
    setup [:instructor_conn, :create_project_with_objectives]

    test "linked activities column and empty state are present for instructors", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.rebuild_contained_objectives(section)

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      assert has_element?(
               view,
               "table thead th[data-sortable='false'] span[title*='Number of activities']",
               "Linked Activities"
             )

      assert has_element?(view, "[data-linked-activities-empty]", "No linked activities")
      refute has_element?(view, "[data-linked-activities-button]", "View 0 Activities")
    end
  end

  describe "linked activities controls" do
    setup [:instructor_conn, :create_full_project_with_objectives]

    test "renders a secondary navigation button for linked activities", %{
      conn: conn,
      instructor: instructor,
      section: section,
      resources: %{obj_resource_d: objective}
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Oli.Delivery.Sections.PostProcessing.apply(section, [:related_activities])

      {:ok, view, _html} = live(conn, live_view_learning_objectives_route(section.slug))

      assert has_element?(
               view,
               "a[data-linked-activities-button][href*='/related_activities/#{objective.id}']",
               "View 1 Activity"
             )

      assert has_element?(
               view,
               "a[data-linked-activities-button].whitespace-nowrap[aria-label='View 1 linked activity'] svg[width='16'][height='16'][class*='-rotate-90']"
             )

      assert render(view) =~ "transparent_background"
    end
  end

  defp create_lkt_aoa_project_with_mixed_confidence_children(_conn) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    child_1_resource = insert(:resource)

    child_1_revision =
      insert(:revision, %{
        resource: child_1_resource,
        objectives: %{},
        resource_type_id: ResourceType.id_for_objective(),
        children: [],
        content: %{},
        deleted: false,
        slug: "child_1",
        title: "Child Objective 1"
      })

    insert(:project_resource, %{project_id: project.id, resource_id: child_1_resource.id})

    child_2_resource = insert(:resource)

    child_2_revision =
      insert(:revision, %{
        resource: child_2_resource,
        objectives: %{},
        resource_type_id: ResourceType.id_for_objective(),
        children: [],
        content: %{},
        deleted: false,
        slug: "child_2",
        title: "Child Objective 2"
      })

    insert(:project_resource, %{project_id: project.id, resource_id: child_2_resource.id})

    parent_resource = insert(:resource)

    parent_revision =
      insert(:revision, %{
        resource: parent_resource,
        objectives: %{},
        resource_type_id: ResourceType.id_for_objective(),
        children: [child_1_resource.id, child_2_resource.id],
        content: %{},
        deleted: false,
        slug: "parent_objective",
        title: "Parent Objective"
      })

    insert(:project_resource, %{project_id: project.id, resource_id: parent_resource.id})

    page_1_resource = insert(:resource)

    page_1_revision =
      insert(:revision, %{
        objectives: %{"attached" => [child_1_resource.id]},
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: ResourceType.id_for_page(),
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Page 1",
        resource: page_1_resource,
        slug: "page_1"
      })

    insert(:project_resource, %{project_id: project.id, resource_id: page_1_resource.id})

    page_2_resource = insert(:resource)

    page_2_revision =
      insert(:revision, %{
        objectives: %{"attached" => [child_2_resource.id]},
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: ResourceType.id_for_page(),
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Page 2",
        resource: page_2_resource,
        slug: "page_2"
      })

    insert(:project_resource, %{project_id: project.id, resource_id: page_2_resource.id})

    root_resource = insert(:resource)

    root_revision =
      insert(:revision, %{
        resource: root_resource,
        objectives: %{},
        resource_type_id: ResourceType.id_for_container(),
        children: [page_1_resource.id, page_2_resource.id],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    insert(:project_resource, %{project_id: project.id, resource_id: root_resource.id})

    publication =
      insert(:publication, %{project: project, root_resource_id: root_resource.id, published: nil})

    [
      {child_1_resource, child_1_revision},
      {child_2_resource, child_2_revision},
      {parent_resource, parent_revision},
      {page_1_resource, page_1_revision},
      {page_2_resource, page_2_revision},
      {root_resource, root_revision}
    ]
    |> Enum.each(fn {resource, revision} ->
      insert(:published_resource, %{
        publication: publication,
        resource: resource,
        revision: revision,
        author: author
      })
    end)

    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable,
        learning_model_version: :lkt_aoa
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)
    {:ok, _} = Sections.rebuild_contained_objectives(section)

    student = insert(:user)
    Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.insert_all("learning_states", [
      %{
        section_id: section.id,
        user_id: student.id,
        learning_objective_id: child_1_resource.id,
        attempt_count: 5,
        success_score: 4.75,
        failure_score: 0.25,
        recency_logit: 0.0,
        aoa: 0.95,
        unique_activity_part_count: 5,
        confidence: 0.95,
        inserted_at: now,
        updated_at: now
      },
      %{
        section_id: section.id,
        user_id: student.id,
        learning_objective_id: child_2_resource.id,
        attempt_count: 5,
        success_score: 1.0,
        failure_score: 4.0,
        recency_logit: 0.0,
        aoa: 0.2,
        unique_activity_part_count: 5,
        confidence: 0.2,
        inserted_at: now,
        updated_at: now
      }
    ])

    %{
      project: project,
      section: section,
      publication: publication,
      revisions: %{
        parent_revision: parent_revision,
        child_1_revision: child_1_revision,
        child_2_revision: child_2_revision
      }
    }
  end
end

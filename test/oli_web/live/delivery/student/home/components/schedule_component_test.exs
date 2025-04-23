defmodule OliWeb.Delivery.Student.Home.Components.ScheduleComponentTest do
  use OliWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import LiveComponentTests
  import Oli.Factory

  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Sections
  alias OliWeb.Delivery.Student.Utils
  alias Oli.Resources.ResourceType
  alias OliWeb.Delivery.Student.Home.Components.ScheduleComponent
  alias Lti_1p3.Tool.ContextRoles

  defp enroll_as_student(%{user: user, section: section} = context) do
    Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
    context
  end

  defp mark_section_visited(%{section: section, user: user} = context) do
    Sections.mark_section_visited_for_student(section, user)
    context
  end

  defp set_progress(
         section_id,
         resource_id,
         user_id,
         progress,
         revision,
         attempt_state \\ :evaluated
       ) do
    {:ok, resource_access} =
      Core.track_access(resource_id, section_id, user_id)
      |> Core.update_resource_access(%{progress: progress})

    insert(:resource_attempt, %{
      resource_access: resource_access,
      revision: revision,
      lifecycle_state: attempt_state,
      date_submitted: if(attempt_state == :evaluated, do: Oli.DateTime.utc_now(), else: nil)
    })
  end

  defp build_project(_) do
    create_project(true)
  end

  defp build_project_without_schedule(_) do
    create_project(false)
  end

  defp create_project(add_schedule?) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # This week's schedule
    # Graded 1 in Unit 1
    graded_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: %{"model" => []},
        title: "Graded 1",
        graded: true
      )

    # Graded 2 in Unit 1 > Module 1 same due date as Practice 1
    graded_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: %{"model" => []},
        title: "Graded 2",
        graded: true
      )

    # Practice 1 in Unit 1 > Module 1 same due date as Graded 2
    practice_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: %{"model" => []},
        title: "Practice 1"
      )

    # Next week's schedule
    # Exploration 1 in Unit 1 > Module 2
    exploration_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: %{"model" => []},
        title: "Exploration 1",
        graded: true,
        purpose: :application
      )

    # Practice 2 in Unit 1 > Module 2
    practice_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: %{"model" => []},
        title: "Practice 2"
      )

    # Units and modules

    module_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          graded_2_revision.resource_id,
          practice_1_revision.resource_id
        ],
        title: "Module 1"
      })

    module_2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          exploration_1_revision.resource_id,
          practice_2_revision.resource_id
        ],
        title: "Module 2"
      })

    unit_1_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.id_for_container(),
        children: [
          graded_1_revision.resource_id,
          module_1_revision.resource_id,
          module_2_revision.resource_id
        ],
        title: "Unit 1"
      })

    ## 12 more units with 1 page each
    {more_pages, more_units} =
      Enum.reduce(2..11, {[], []}, fn x, {more_pages, more_units} ->
        a_page =
          insert(:revision, %{
            resource_type_id: ResourceType.id_for_page(),
            title: "A Page #{x}"
          })

        a_unit =
          insert(:revision, %{
            resource_type_id: ResourceType.id_for_container(),
            children: [a_page.resource_id],
            title: "Unit #{x}"
          })

        {
          [a_page | more_pages],
          [a_unit | more_units]
        }
      end)

    all_units =
      [unit_1_revision] ++ more_units

    all_units_resource_ids =
      Enum.map(all_units, & &1.resource_id)

    container_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.id_for_container(),
        children: all_units_resource_ids,
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    all_revisions =
      more_pages ++
        [
          graded_1_revision,
          graded_2_revision,
          practice_1_revision,
          exploration_1_revision,
          practice_2_revision,
          module_1_revision,
          module_2_revision
        ] ++
        all_units ++
        [
          container_revision
        ]

    # asociate resources to project
    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: project.id,
        resource_id: revision.resource_id
      })
    end)

    # publish project
    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_revision.resource_id
      })

    # publish resources
    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

    # create section...
    section =
      insert(:section,
        base_project: project,
        title: "The best course ever!",
        start_date: ~U[2024-05-05 20:00:00Z],
        analytics_version: :v2
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)
    {:ok, _} = Sections.rebuild_contained_objectives(section)

    if add_schedule? do
      # schedule start and end date for Unit 1 section_resource
      # schedule start and end date for Unit 1 section_resource
      Sections.get_section_resource(section.id, unit_1_revision.resource_id)
      |> Sections.update_section_resource(%{
        start_date: ~U[2024-05-05 20:00:00Z],
        end_date: ~U[2024-05-18 20:00:00Z]
      })

      # schedule start and end date for Module 1 section_resource
      Sections.get_section_resource(section.id, module_1_revision.resource_id)
      |> Sections.update_section_resource(%{
        start_date: ~U[2024-05-05 20:00:00Z],
        end_date: ~U[2024-05-11 20:00:00Z]
      })

      # schedule start and end date for Module 2 section_resource
      Sections.get_section_resource(section.id, module_2_revision.resource_id)
      |> Sections.update_section_resource(%{
        start_date: ~U[2024-05-12 20:00:00Z],
        end_date: ~U[2024-05-18 20:00:00Z]
      })

      # schedule start and end date for Graded 1 section_resource
      Sections.get_section_resource(section.id, graded_1_revision.resource_id)
      |> Sections.update_section_resource(%{
        start_date: ~U[2024-05-05 20:00:00Z],
        end_date: ~U[2024-05-06 20:00:00Z]
      })

      # schedule start and end date for Graded 2 and Practice 1 section_resources
      Sections.get_section_resource(section.id, graded_2_revision.resource_id)
      |> Sections.update_section_resource(%{
        start_date: ~U[2024-05-06 20:00:00Z],
        end_date: ~U[2024-05-07 20:00:00Z]
      })

      Sections.get_section_resource(section.id, practice_1_revision.resource_id)
      |> Sections.update_section_resource(%{
        start_date: ~U[2024-05-06 20:00:00Z],
        end_date: ~U[2024-05-07 20:00:00Z]
      })

      # schedule start and end date for Exploration 1 section_resource
      Sections.get_section_resource(section.id, exploration_1_revision.resource_id)
      |> Sections.update_section_resource(%{
        start_date: ~U[2024-05-12 20:00:00Z],
        end_date: ~U[2024-05-14 20:00:00Z]
      })

      # schedule start and end date for Practice 2 section_resource
      Sections.get_section_resource(section.id, practice_2_revision.resource_id)
      |> Sections.update_section_resource(%{
        start_date: ~U[2024-05-15 20:00:00Z],
        end_date: ~U[2024-05-17 20:00:00Z]
      })
    end

    session_context = %OliWeb.Common.SessionContext{
      browser_timezone: "America/Montevideo",
      local_tz: "America/Montevideo",
      author: author,
      user: author,
      is_liveview: true
    }

    [
      project: project,
      publication: publication,
      section: section,
      graded_1_revision: graded_1_revision,
      graded_2_revision: graded_2_revision,
      practice_1_revision: practice_1_revision,
      exploration_1_revision: exploration_1_revision,
      practice_2_revision: practice_2_revision,
      module_1_revision: module_1_revision,
      module_2_revision: module_2_revision,
      unit_1_revision: unit_1_revision,
      container_revision: container_revision,
      author: author,
      session_context: session_context
    ]
  end

  describe "live component with schedule" do
    setup [:user_conn, :build_project, :enroll_as_student, :mark_section_visited]

    # use a mocked datetime to have past, present and future items
    # also include a graded page with attempt made and attempt in progress
    test "renders default schedule", %{
      conn: conn,
      section: section,
      user: user,
      session_context: session_context
    } do
      stub_current_time(~U[2024-05-07 20:00:00Z])

      grouped_agenda_resources = Utils.grouped_agenda_resources(section, nil, user.id, true)

      {:ok, lcd, _html} =
        live_component_isolated(conn, ScheduleComponent, %{
          ctx: session_context,
          grouped_agenda_resources: grouped_agenda_resources,
          section_start_date: section.start_date,
          section_slug: section.slug
        })

      ## Displays current week
      assert has_element?(lcd, ~s{#schedule_week_1 div[role="schedule_title"]}, "This Week")

      assert element(lcd, ~s{#schedule_week_1 div[role="schedule_date_range"]}) |> render() =~
               "May 5<sup>th</sup> - May 11<sup>th</sup> 2024"

      # Displays Graded 1 in Unit 1
      assert has_element?(lcd, ~s{#schedule_item_1_1 div[role="container_label"]}, "Unit 1")
      assert has_element?(lcd, ~s{#schedule_item_1_1 div[role="resource_type"]}, "Assignment")
      assert has_element?(lcd, ~s{#schedule_item_1_1 div[role="title"]}, "Graded 1")

      assert has_element?(
               lcd,
               ~s{#schedule_item_1_1 div[role="details"]},
               "Past suggested date by"
             )

      # Displays Lesson group in Unit 1 > Module 1 (contains Graded 2 and Practice 1)
      assert has_element?(lcd, ~s{#schedule_item_1_2 div[role="container_label"]}, "Unit 1")
      assert has_element?(lcd, ~s{#schedule_item_1_2 div[role="container_label"]}, "Module 1")
      assert has_element?(lcd, ~s{#schedule_item_1_2 div[role="resource_type"]}, "Lesson")
      assert has_element?(lcd, ~s{#schedule_item_1_2 div[role="title"]}, "Module 1")

      assert has_element?(
               lcd,
               ~s{#schedule_item_1_2 div[role="group"] div[role="count"]},
               "2 pages"
             )

      assert has_element?(lcd, ~s{#schedule_item_1_2 div[role="details"]}, "Suggested for Today")

      ## Displays next week
      assert has_element?(lcd, ~s{#schedule_week_2 div[role="schedule_title"]}, "Next Week")

      assert element(lcd, ~s{#schedule_week_2 div[role="schedule_date_range"]}) |> render() =~
               "May 12<sup>th</sup> - May 18<sup>th</sup> 2024"

      # Displays Exploration 1 in Unit 1 > Module 2
      assert has_element?(lcd, ~s{#schedule_item_2_1 div[role="container_label"]}, "Unit 1")
      assert has_element?(lcd, ~s{#schedule_item_2_1 div[role="container_label"]}, "Module 2")
      assert has_element?(lcd, ~s{#schedule_item_2_1 div[role="resource_type"]}, "Exploration")
      assert has_element?(lcd, ~s{#schedule_item_2_1 div[role="title"]}, "Exploration 1")
      assert has_element?(lcd, ~s{#schedule_item_2_1 div[role="details"]}, "7 days left")

      # Displays Practice 2 in Unit 1 > Module 2
      assert has_element?(lcd, ~s{#schedule_item_2_2 div[role="container_label"]}, "Unit 1")
      assert has_element?(lcd, ~s{#schedule_item_2_2 div[role="container_label"]}, "Module 2")
      assert has_element?(lcd, ~s{#schedule_item_2_2 div[role="resource_type"]}, "Practice")
      assert has_element?(lcd, ~s{#schedule_item_2_2 div[role="title"]}, "Practice 2")
      assert has_element?(lcd, ~s{#schedule_item_2_2 div[role="details"]}, "10 days left")
    end

    test "renders schedule with completed items", %{
      conn: conn,
      section: section,
      user: user,
      graded_2_revision: graded_2,
      practice_1_revision: practice_1,
      practice_2_revision: practice_2,
      session_context: session_context
    } do
      stub_current_time(~U[2024-05-07 20:00:00Z])

      # Complete Practice 2
      set_progress(section.id, practice_2.resource_id, user.id, 1.0, practice_2)

      # Complete Lesson group
      set_progress(section.id, graded_2.resource_id, user.id, 1.0, graded_2)
      set_progress(section.id, practice_1.resource_id, user.id, 1.0, practice_1)

      grouped_agenda_resources = Utils.grouped_agenda_resources(section, nil, user.id, true)

      {:ok, lcd, _html} =
        live_component_isolated(conn, ScheduleComponent, %{
          ctx: session_context,
          grouped_agenda_resources: grouped_agenda_resources,
          section_start_date: section.start_date,
          section_slug: section.slug
        })

      # Practice 2 is completed
      assert has_element?(lcd, ~s{#schedule_item_2_2 div[role="details"]}, "Completed")

      # Lesson group is completed
      assert has_element?(lcd, ~s{#schedule_item_1_2 div[role="details"]}, "Completed")
    end

    test "shows attempts info for graded pages", %{
      conn: conn,
      section: section,
      user: user,
      graded_1_revision: graded_1,
      exploration_1_revision: exploration_1,
      session_context: session_context
    } do
      stub_current_time(~U[2024-05-07 20:00:00Z])

      # Complete Graded 1
      set_progress(section.id, graded_1.resource_id, user.id, 1.0, graded_1)

      # Leave Exploration 1 in progress
      set_progress(section.id, exploration_1.resource_id, user.id, 1.0, exploration_1, :active)

      grouped_agenda_resources = Utils.grouped_agenda_resources(section, nil, user.id, true)

      {:ok, lcd, _html} =
        live_component_isolated(conn, ScheduleComponent, %{
          ctx: session_context,
          grouped_agenda_resources: grouped_agenda_resources,
          section_start_date: section.start_date,
          section_slug: section.slug
        })

      # Graded 1 is completed and displays attempts info
      assert has_element?(lcd, ~s{#schedule_item_1_1 div[role="details"]}, "Attempt 1 of ∞")
      assert has_element?(lcd, ~s{#schedule_item_1_1 div[role="details"]}, "Last Submitted")
      assert has_element?(lcd, ~s{#schedule_item_1_1 div[role="details"]}, "Tue May 7, 2024")

      # Exploration 1 is in progress and does not display remaining time (since the attempt does not have time limit)
      assert has_element?(lcd, ~s{#schedule_item_2_1 div[role="details"]}, "Attempt 1 of ∞")
      refute has_element?(lcd, ~s{#schedule_item_2_1 div[role="details"]}, "Time Remaining")
    end

    test "it expands a lesson group", %{
      conn: conn,
      section: section,
      user: user,
      practice_1_revision: practice_1,
      session_context: session_context
    } do
      stub_current_time(~U[2024-05-07 20:00:00Z])

      # Complete Practice 1 (inside Lesson group)
      set_progress(section.id, practice_1.resource_id, user.id, 1.0, practice_1)

      grouped_agenda_resources = Utils.grouped_agenda_resources(section, nil, user.id, true)

      {:ok, lcd, _html} =
        live_component_isolated(conn, ScheduleComponent, %{
          ctx: session_context,
          grouped_agenda_resources: grouped_agenda_resources,
          section_start_date: section.start_date,
          section_slug: section.slug
        })

      lcd
      |> element(~s{#schedule_item_1_2 button[phx-click=expand_item]})
      |> render_click()

      # Now displays Practice 1 and completed status
      assert has_element?(
               lcd,
               ~s{#schedule_item_1_2 div[role="group_item"]},
               "Practice 1"
             )

      assert has_element?(
               lcd,
               ~s{#schedule_item_1_2 div[role="group_item"]:first-of-type div[role="check icon"]}
             )

      # Now displays Graded 2
      assert has_element?(
               lcd,
               ~s{#schedule_item_1_2 div[role="group_item"]},
               "Graded 2"
             )
    end
  end

  describe "live component without schedule" do
    setup [:user_conn, :build_project_without_schedule, :enroll_as_student, :mark_section_visited]

    test "renders 6 first containers as ordered in the curriculum", %{
      conn: conn,
      section: section,
      user: user,
      session_context: session_context
    } do
      # no schedule
      grouped_agenda_resources = Utils.grouped_agenda_resources(section, nil, user.id, false)

      {:ok, lcd, _html} =
        live_component_isolated(conn, ScheduleComponent, %{
          ctx: session_context,
          grouped_agenda_resources: grouped_agenda_resources,
          section_start_date: section.start_date,
          section_slug: section.slug
        })

      ## Does not display current week (no schedule)
      refute has_element?(lcd, ~s{#schedule_week_1 div[role="schedule_title"]}, "This Week")

      # Displays first 6 containers (as ordered in the curriculum)
      assert has_element?(lcd, ~s{#schedule_item_1_1 div[role="container_label"]}, "Unit 1")
      assert has_element?(lcd, ~s{#schedule_item_1_2 div[role="container_label"]}, "Module 1")
      assert has_element?(lcd, ~s{#schedule_item_1_3 div[role="container_label"]}, "Module 2")
      assert has_element?(lcd, ~s{#schedule_item_1_4 div[role="container_label"]}, "Unit 2")
      assert has_element?(lcd, ~s{#schedule_item_1_5 div[role="container_label"]}, "Unit 3")
      assert has_element?(lcd, ~s{#schedule_item_1_6 div[role="container_label"]}, "Unit 4")

      Enum.each(5..11, fn x ->
        refute render(lcd) =~ "Unit #{x}"
      end)
    end
  end
end

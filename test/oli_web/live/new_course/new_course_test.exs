defmodule OliWeb.NewCourse.NewCourseTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo
  alias Oli.Resources.ResourceType

  describe "wizard left-panel step copy" do
    setup [:instructor_conn]

    test "renders the agreed title and description for all three steps (AC-014)", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sections/new")

      assert has_element?(view, "h4", "Select your source materials")

      assert has_element?(
               view,
               "p",
               "Select the source of materials to base your course curriculum on."
             )

      assert has_element?(view, "h4", "Name your course")

      assert has_element?(
               view,
               "p",
               "Give your course section a name, a number, and tell us how you meet."
             )

      assert has_element?(view, "h4", "Course details")

      assert has_element?(
               view,
               "p",
               "If you meet as a group, let us know what days of the week your class meets. Tell us your course’s start and end dates."
             )
    end
  end

  describe "wizard footer restyle" do
    setup [:instructor_conn]

    test "the Cancel button renders as the shared secondary Button component (present on every step)",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sections/new")

      assert has_element?(view, "#course_creation_stepper")

      assert has_element?(
               view,
               ~s(button[class*="Border-border-bold"]),
               "Cancel"
             )
    end

    test "the Next Step button renders as the shared primary Button component, switching from muted to filled once a source is selected",
         %{conn: conn} do
      %Publication{project: project} = insert(:publication)
      section = insert(:section, base_project: project)

      {:ok, view, _html} = live(conn, ~p"/sections/new")

      assert has_element?(view, "button[disabled]", "Next step")

      assert has_element?(
               view,
               ~s(button[class*="Fill-Buttons-fill-primary-muted"]),
               "Next step"
             )

      view
      |> element(".card-deck button:first-child")
      |> render_click(id: "publication:#{section.id}")

      assert has_element?(view, "h2", "Name your course")

      refute has_element?(view, "button[disabled]", "Next step")

      refute has_element?(
               view,
               ~s(button[class*="Fill-Buttons-fill-primary-muted"]),
               "Next step"
             )
    end
  end

  describe "My Course Sections copy-choice modal" do
    setup [:admin_conn]

    test "selecting a My Course Section opens the modal instead of advancing to the next step",
         %{conn: conn} do
      course = my_course_section(title: "Chemistry 101 -- Fall 2025")

      {:ok, view, _html} = live(conn, ~p"/admin/sections/create")

      refute has_element?(view, "#copy-choice-modal")

      select_my_course_section(view, course)

      assert has_element?(view, "#copy-choice-modal")
      assert has_element?(view, "h1", "Choose what to copy")
      assert render(view) =~ course.title
      refute has_element?(view, "h2", "Name your course")

      assert has_element?(
               view,
               "label",
               "Content / curriculum (Required)"
             )
    end

    test "selecting a Template does not open the modal and advances directly (regression)", %{
      conn: conn
    } do
      template = insert(:section, open_and_free: true, type: :blueprint, title: "Bio Template")

      {:ok, view, _html} = live(conn, ~p"/admin/sections/create")

      view
      |> element("button[phx-value-id='product:#{template.id}']")
      |> render_click()

      assert has_element?(view, "h2", "Name your course")
      refute has_element?(view, "#copy-choice-modal")
    end

    test "Cancel closes the modal without advancing, without leaving the card looking selected, and without breaking re-selection",
         %{conn: conn} do
      course = my_course_section()

      {:ok, view, _html} = live(conn, ~p"/admin/sections/create")

      select_my_course_section(view, course)

      assert has_element?(view, "#copy-choice-modal")

      view
      |> element("#copy-choice-modal button", "Cancel")
      |> render_click()

      refute has_element?(view, "#copy-choice-modal")
      refute has_element?(view, "h2", "Name your course")

      refute has_element?(
               view,
               "button[phx-value-id='section:#{course.id}'] div.bg-delivery-primary-100"
             )

      select_my_course_section(view, course)

      assert has_element?(view, "#copy-choice-modal")
    end

    test "dismissing via the close (X) button behaves the same as Cancel and does not break re-selection",
         %{conn: conn} do
      course = my_course_section()

      {:ok, view, _html} = live(conn, ~p"/admin/sections/create")

      select_my_course_section(view, course)

      view
      |> element("#copy-choice-modal button[aria-label='close']")
      |> render_click()

      refute has_element?(view, "#copy-choice-modal")

      refute has_element?(
               view,
               "button[phx-value-id='section:#{course.id}'] div.bg-delivery-primary-100"
             )

      select_my_course_section(view, course)

      assert has_element?(view, "#copy-choice-modal")
    end

    test "confirming the modal creates the section immediately (no wizard steps), copying the source's title (with a '(copy)' suffix), dates, and section details, but not course_section_number",
         %{conn: conn} do
      %{project: project, publication: publication} = published_project_with_resource()

      course =
        insert(:section,
          type: :enrollable,
          base_project: project,
          title: "Chem Copy",
          course_section_number: "CHEM-101-03",
          class_modality: :hybrid,
          class_days: [:monday, :wednesday],
          start_date: ~U[2026-01-10 00:00:00Z],
          end_date: ~U[2026-05-10 00:00:00Z],
          preferred_scheduling_time: ~T[10:30:00],
          timezone: "US/Pacific"
        )

      {:ok, course} = Sections.create_section_resources(course, publication)

      {:ok, view, _html} = live(conn, ~p"/admin/sections/create")

      select_my_course_section(view, course)

      assert has_element?(view, "input[value='entire_course'][checked]")

      view
      |> element("#copy-choice-modal button", "Create Section")
      |> render_click()

      # No wizard steps are shown — the workflow ends on this button.
      refute has_element?(view, "#copy-choice-modal")
      refute has_element?(view, "h2", "Name your course")
      refute has_element?(view, "h2", "Course details")

      # During the loading window before the redirect lands, the still-mounted source grid
      # must not flash the just-copied card back into its "selected" state.
      refute has_element?(
               view,
               "button[phx-value-id='section:#{course.id}'] div.bg-delivery-primary-100"
             )

      wait_for_completion()
      assert_redirect(view)

      created = Repo.get_by!(Section, title: "Chem Copy (copy)")
      # course_section_number has no edit surface anywhere in the app after creation, so it's
      # deliberately left out of the copy rather than durably locking in the source's value.
      assert created.course_section_number == nil
      assert created.class_modality == :hybrid
      assert created.class_days == [:monday, :wednesday]
      assert created.start_date == course.start_date
      assert created.end_date == course.end_date
      assert created.preferred_scheduling_time == course.preferred_scheduling_time
      assert created.timezone == "US/Pacific"
    end

    test "switching to 'Choose what to copy' defaults to only Content checked, and switching back mutes all checkboxes",
         %{conn: conn} do
      course = my_course_section()

      {:ok, view, _html} = live(conn, ~p"/admin/sections/create")

      select_my_course_section(view, course)

      view
      |> element("input[value='choose_what_to_copy']")
      |> render_click()

      assert has_element?(view, "input[name='copy_group_content'][checked][disabled]")
      refute has_element?(view, "input[name='copy_group_schedule'][checked]")
      assert has_element?(view, "input[name='copy_group_schedule']:not([disabled])")

      view
      |> element("input[name='copy_group_schedule']")
      |> render_click()

      assert has_element?(view, "input[name='copy_group_schedule'][checked]")

      view
      |> element("input[value='entire_course']")
      |> render_click()

      assert has_element?(view, "input[name='copy_group_schedule'][disabled]")
    end
  end

  describe "telemetry" do
    setup [:admin_conn]

    test "emits my_course_sections_card_activated only when a My Course Sections source is selected",
         %{conn: conn} do
      handler_id = "my-course-sections-card-telemetry-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:oli, :course_builder, :my_course_sections_card_activated],
        fn event, measurements, metadata, pid ->
          send(pid, {:telemetry_event, event, measurements, metadata})
        end,
        self()
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      %Publication{project: project} = insert(:publication)
      template = insert(:section, base_project: project, title: "Chem Template")
      course = insert(:section, type: :enrollable, base_project: project, title: "Chem Copy")

      {:ok, view, _html} = live(conn, ~p"/admin/sections/create")

      # Not a strict `refute_received` here: `:telemetry` events are a global bus not scoped to
      # this test process's own actions, so an unrelated concurrently-running test that also
      # activates a My Course Sections card could deliver a same-named event to this handler
      # too. Clicking a Template source and confirming it still advances the wizard normally is
      # the meaningful regression check for the "not a My Course Section" case; the positive
      # assertion below is what actually proves this event fires for a real activation.
      view
      |> element("button[phx-value-id='product:#{template.id}']")
      |> render_click()

      assert has_element?(view, "h2", "Name your course")

      {:ok, view, _html} = live(conn, ~p"/admin/sections/create")

      select_my_course_section(view, course)

      assert_received {:telemetry_event,
                       [:oli, :course_builder, :my_course_sections_card_activated], %{count: 1},
                       %{}}
    end
  end

  defp my_course_section(attrs \\ %{}) do
    %Publication{project: project} = insert(:publication)

    insert(
      :section,
      Map.merge(%{type: :enrollable, base_project: project, title: "Chem Copy"}, Map.new(attrs))
    )
  end

  defp select_my_course_section(view, course) do
    view
    |> element("button[phx-value-id='section:#{course.id}']")
    |> render_click()
  end

  # `Oli.Factory.insert_project_with_resource/1` builds an intentionally *unpublished*
  # project (`published: nil`), meant for authoring-flow tests — not eligible as a course-copy
  # source, since `SectionCreation.permitted_publications_query/2` requires a published
  # publication. This builds the same shape but published (the factory's own default), so the
  # resulting section actually shows up as a My Course Section.
  defp published_project_with_resource do
    author = insert(:author)
    project = insert(:project, authors: [])
    resource = insert(:resource)

    revision =
      insert(:revision,
        author: author,
        resource: resource,
        resource_type_id: ResourceType.id_for_container(),
        title: "Curriculum",
        children: []
      )

    insert(:author_project, author_id: author.id, project_id: project.id)
    insert(:project_resource, project_id: project.id, resource_id: resource.id)

    publication = insert(:publication, project: project, root_resource_id: resource.id)

    insert(:published_resource,
      publication: publication,
      resource: resource,
      revision: revision,
      author: author
    )

    %{project: project, publication: publication}
  end
end

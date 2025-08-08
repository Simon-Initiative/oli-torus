defmodule OliWeb.Admin.Institutions.SectionsAndStudentsViewTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections

  defp live_view_sections_and_students_live(institution_id, selected_tab) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Admin.Institutions.SectionsAndStudentsView,
      institution_id,
      selected_tab
    )
  end

  defp create_project(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...
    container_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [],
        content: %{},
        deleted: false,
        title: "Root Container"
      })

    # asociate resources to project
    insert(:project_resource, %{
      project_id: project.id,
      resource_id: container_revision.resource_id
    })

    # publish project and resources
    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_revision.resource_id
      })

    # publish project and resources
    insert(:published_resource, %{
      publication: publication,
      resource: container_revision.resource,
      revision: container_revision,
      author: author
    })

    # create sections with the same institution...
    [institution_1, institution_2] = insert_pair(:institution)

    section_1 =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable,
        institution: institution_1,
        requires_payment: true,
        amount: Money.new(40, "USD")
      )

    section_2 =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable,
        institution: institution_1,
        requires_payment: true,
        amount: Money.new(10, "USD")
      )

    [section_3, section_4] =
      insert_pair(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable,
        institution: institution_1,
        requires_payment: true,
        amount: Money.new(30, "USD")
      )

    {:ok, section_1} = Sections.create_section_resources(section_1, publication)
    {:ok, section_2} = Sections.create_section_resources(section_2, publication)
    {:ok, section_3} = Sections.create_section_resources(section_3, publication)
    {:ok, section_4} = Sections.create_section_resources(section_4, publication)

    # enroll students to sections
    student_1 = insert(:user, email: "student@1.com")
    student_2 = insert(:user, email: "student@2.com")
    student_3 = insert(:user, email: "student@3.com")
    student_4 = insert(:user, email: "student@4.com")

    Sections.enroll(student_1.id, section_1.id, [ContextRoles.get_role(:context_learner)])
    Sections.enroll(student_1.id, section_2.id, [ContextRoles.get_role(:context_learner)])
    Sections.enroll(student_1.id, section_3.id, [ContextRoles.get_role(:context_learner)])
    Sections.enroll(student_1.id, section_4.id, [ContextRoles.get_role(:context_learner)])

    Sections.enroll(student_2.id, section_1.id, [ContextRoles.get_role(:context_learner)])
    Sections.enroll(student_2.id, section_2.id, [ContextRoles.get_role(:context_learner)])
    Sections.enroll(student_2.id, section_3.id, [ContextRoles.get_role(:context_learner)])

    Sections.enroll(student_3.id, section_1.id, [ContextRoles.get_role(:context_learner)])
    Sections.enroll(student_3.id, section_2.id, [ContextRoles.get_role(:context_learner)])

    Sections.enroll(student_4.id, section_1.id, [ContextRoles.get_role(:context_learner)])

    %{
      section_1: section_1,
      section_2: section_2,
      section_3: section_3,
      section_4: section_4,
      institution_1: institution_1,
      institution_2: institution_2,
      student_1: student_1,
      student_2: student_2,
      student_3: student_3,
      student_4: student_4
    }
  end

  defp table_as_list_of_maps(view, tab_name) do
    keys =
      case tab_name do
        :sections ->
          [
            :title,
            :type,
            :enrollments_count,
            :requires_payment,
            :start_date,
            :end_date,
            :status,
            :base,
            :instructor,
            :institution
          ]

        :students ->
          [
            :name,
            :email,
            :independent_learner,
            :author
          ]
      end

    rows =
      view
      |> render()
      |> Floki.parse_fragment!()
      |> Floki.find(~s{.instructor_dashboard_table tbody tr})
      |> Enum.map(fn row ->
        Floki.find(row, "td")
        |> Enum.map(fn data ->
          case Floki.find(data, "select") do
            [] ->
              Floki.text(data) |> String.trim()

            select ->
              Floki.find(select, "option[selected]") |> Floki.text()
          end
        end)
      end)

    Enum.map(rows, fn a ->
      Enum.zip(keys, a)
      |> Enum.into(%{})
    end)
  end

  describe "admin" do
    setup [:create_project]

    test "is redirected to new session when not logged in", %{conn: conn, section_1: section_1} do
      {:error, {:redirect, %{to: "/authors/log_in"}}} =
        live(conn, live_view_sections_and_students_live(section_1.institution_id, :sections))
    end
  end

  describe "student" do
    setup [:create_project, :user_conn]

    test "cannot access page", %{conn: conn, section_1: section_1} do
      redirect_path =
        "/authors/log_in"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(
                 conn,
                 live_view_sections_and_students_live(section_1.institution_id, :sections)
               )
    end
  end

  describe "sections tab" do
    setup [:admin_conn, :create_project]

    test "gets rendered correctly", %{conn: conn, institution_1: institution_1} do
      {:ok, view, _html} =
        live(
          conn,
          live_view_sections_and_students_live(institution_1.id, :sections)
        )

      assert view
             |> element("h4", institution_1.name)
             |> has_element?()
    end

    test "gets rendered correctly for an institution not assigned to any section", %{
      conn: conn,
      institution_2: institution_2
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_sections_and_students_live(institution_2.id, :sections)
        )

      assert view
             |> element("h4", institution_2.name)
             |> has_element?()

      assert view
             |> render() =~ "None exist"
    end

    test "table content shows all sections for the selected institution", %{
      conn: conn,
      section_1: section_1,
      section_2: section_2,
      section_3: section_3,
      section_4: section_4,
      institution_1: institution
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_sections_and_students_live(institution.id, :sections)
        )

      [section_1, section_2, section_3, section_4] =
        [section_1, section_2, section_3, section_4] |> Enum.sort_by(& &1.title)

      [s_1, s_2, s_3, s_4] = rendered_sections = table_as_list_of_maps(view, :sections)

      assert length(rendered_sections) == 4

      assert s_1.title == section_1.title
      assert s_1.institution =~ institution.name

      assert s_2.title == section_2.title
      assert s_2.institution =~ institution.name

      assert s_3.title == section_3.title
      assert s_3.institution =~ institution.name

      assert s_4.title == section_4.title
      assert s_4.institution =~ institution.name
    end

    test "a section's institution can be changed through the edit button", %{
      conn: conn,
      section_1: section_1,
      institution_1: institution_1,
      institution_2: institution_2
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_sections_and_students_live(institution_1.id, :sections)
        )

      assert view
             |> render() =~ section_1.title

      # click institution edit button for section 1
      view
      |> element(~s{button[phx-click="edit_section"][value='#{section_1.id}']}, "Edit")
      |> render_click

      # the modal is shown...
      assert view
             |> element("#edit_institution_for_section_modal")
             |> has_element?()

      # ...with the current institution pre-selected
      assert view
             |> element(
               "select[id=institution_id] option[selected]",
               section_1.institution.name
             )
             |> has_element?

      # we change the institution to be = institution 2 and submit
      view
      |> form("form[phx-submit=submit_modal]")
      |> render_submit(%{"institution_id" => institution_2.id})

      # the modal is closed and a confirmation message is shown
      refute view
             |> element("#edit_institution_for_section_modal")
             |> has_element?()

      assert view
             |> element("div[role='alert']", "Institution updated")
             |> has_element?()

      # that section is no longer listed (as it now has another institution assigned)
      refute view
             |> render() =~ section_1.title

      # and we now see that section listed in the new assigns institution...
      {:ok, view, _html} =
        live(
          conn,
          live_view_sections_and_students_live(institution_2.id, :sections)
        )

      [s_1] = table_as_list_of_maps(view, :sections)

      assert s_1.title == section_1.title
    end
  end

  describe "students tab" do
    setup [:admin_conn, :create_project]

    test "gets rendered correctly", %{conn: conn, institution_1: institution_1} do
      {:ok, view, _html} =
        live(
          conn,
          live_view_sections_and_students_live(institution_1.id, :students)
        )

      assert view
             |> element("h4", institution_1.name)
             |> has_element?()
    end

    test "gets rendered correctly for an institution not assigned to any section", %{
      conn: conn,
      institution_2: institution_2
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_sections_and_students_live(institution_2.id, :students)
        )

      assert view
             |> element("h4", institution_2.name)
             |> has_element?()

      assert view
             |> render() =~ "None exist"
    end

    test "table content shows all students for the selected institution", %{
      conn: conn,
      student_1: student_1,
      student_2: student_2,
      student_3: student_3,
      student_4: student_4,
      institution_1: institution
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_sections_and_students_live(institution.id, :students)
        )

      [student_1, student_2, student_3, student_4] =
        [student_1, student_2, student_3, student_4] |> Enum.sort_by(& &1.name)

      [s_1, s_2, s_3, s_4] = students = table_as_list_of_maps(view, :students)

      assert length(students) == 4

      assert s_1.name == OliWeb.Common.Utils.name(student_1)
      assert s_1.email =~ student_1.email

      assert s_2.name == OliWeb.Common.Utils.name(student_2)
      assert s_2.email =~ student_2.email

      assert s_3.name == OliWeb.Common.Utils.name(student_3)
      assert s_3.email =~ student_3.email

      assert s_4.name == OliWeb.Common.Utils.name(student_4)
      assert s_4.email =~ student_4.email
    end

    test "sorting by cost is doing correctly", %{
      conn: conn,
      institution_1: institution
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_sections_and_students_live(institution.id, :sections)
        )

      view
      |> element("th[phx-value-sort_by=requires_payment]")
      |> render_click()

      # test order desc
      assert view
             |> element("table > tbody > tr:first-child > td:nth-child(4) > div")
             |> render() =~ "$10.00"

      view
      |> element("th[phx-value-sort_by=requires_payment]")
      |> render_click()

      # test order asc
      assert view
             |> element("table > tbody > tr:first-child > td:nth-child(4) > div")
             |> render() =~ "$40.00"
    end
  end
end

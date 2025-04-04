defmodule OliWeb.Sections.GatingAndSchedulingTest do
  use OliWeb.ConnCase

  import Ecto.Query, warn: false
  import Oli.Factory
  import Phoenix.{ConnTest, LiveViewTest}

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.{Gating, Sections}
  alias Oli.Delivery.Gating.GatingCondition
  alias Oli.Delivery.Sections.Section
  alias Oli.{Repo, Seeder}
  alias Oli.Repo.{Paging, Sorting}

  @endpoint OliWeb.Endpoint

  defp gating_condition_edit_route(section_slug, gating_condition_id),
    do:
      Routes.live_path(
        @endpoint,
        OliWeb.Sections.GatingAndScheduling.Edit,
        section_slug,
        gating_condition_id
      )

  defp gating_condition_new_route(section_slug),
    do:
      Routes.live_path(
        @endpoint,
        OliWeb.Sections.GatingAndScheduling.New,
        section_slug
      )

  defp create_gating_condition_through_ui(view, type, start_date, end_date) do
    view
    |> element("button[phx-click=\"show-resource-picker\"]")
    |> render_click()

    # Since Oli.Publishing.DeliveryResolver.find_in_hierarchy generates dynamic uuids every
    # time is called, and that is what is used to select one resource, is necessary to parse the
    # HTML element to get the actual uuid :(

    element_splitted =
      view
      |> element("div[phx-click=\"HierarchyPicker.select\"]", "Page one")
      |> render()
      |> String.split("\"")

    prev_uuid_index =
      Enum.with_index(element_splitted)
      |> Enum.find(fn elem -> elem(elem, 0) == " phx-value-uuid=" end)
      |> elem(1)

    uuid = Enum.at(element_splitted, prev_uuid_index + 1)

    render_hook(view, "select_resource", %{selection: "#{uuid}"})
    render_hook(view, "select-condition", %{value: type})
    render_hook(view, "schedule_start_date_changed", %{value: start_date})
    render_hook(view, "schedule_end_date_changed", %{value: end_date})

    view
    |> element("button[phx-click=\"create_gate\"]")
    |> render_click()
  end

  describe "gating and scheduling live test admin" do
    setup [:setup_admin_session]

    test "mount listing for admin", %{conn: conn, section_1: section} do
      {:ok, _view, html} =
        live(conn, Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug))

      assert html =~ "Admin"
      assert html =~ "Advanced Gating"
    end

    @tag :skip
    test "renders ok description", %{conn: conn, section_1: section} do
      {:ok, view, _html} =
        live(conn, Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug))

      assert view
             |> element("ul>li:nth-child(1)")
             |> render() =~
               "Time-Based Restrictions for Units/Modules"

      assert view
             |> element("ul>li:nth-child(2)")
             |> render() =~
               "Conditional Accessibility Based on Student Performance"
    end

    test "default sorting will order by the order of the resources in the course section", %{
      conn: conn,
      section_1: section
    } do
      {:ok, view, _html} =
        live(conn, Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug))

      # get gating conditions (here also we're testing the context function)
      [page_one, nested_page_one, nested_page_two] =
        Gating.browse_gating_conditions(
          %Section{id: section.id, slug: section.slug},
          %Paging{limit: 25, offset: 0},
          %Sorting{field: :numbering_index, direction: :asc},
          nil
        )

      # get the numbering index of the resources in the course section
      page_one_sr =
        Sections.get_section_resource(section.id, page_one.resource_id).numbering_index

      nested_page_one_sr =
        Sections.get_section_resource(section.id, nested_page_one.resource_id).numbering_index

      nested_page_two_sr =
        Sections.get_section_resource(section.id, nested_page_two.resource_id).numbering_index

      # assert that the resources are ordered by the numbering index
      assert page_one_sr < nested_page_one_sr && nested_page_one_sr < nested_page_two_sr

      # assert that the resources are ordered by the numbering index in the view
      assert view
             |> element("table tbody tr:nth-child(1) td:nth-child(1)")
             |> render() =~
               page_one.revision.title

      assert view
             |> element("table tbody tr:nth-child(2) td:nth-child(1)")
             |> render() =~
               nested_page_one.revision.title

      assert view
             |> element("table tbody tr:nth-child(3) td:nth-child(1)")
             |> render() =~
               nested_page_two.revision.title

      # sort by title to check that the sorting is working
      view
      |> element("th[phx-click=\"paged_table_sort\"]:first-of-type")
      |> render_click(%{sort_by: :title})

      # assert that the resources are ordered by title
      assert view
             |> element("table tbody tr:nth-child(1) td:nth-child(1)")
             |> render() =~
               nested_page_one.revision.title

      assert view
             |> element("table tbody tr:nth-child(2) td:nth-child(1)")
             |> render() =~
               nested_page_two.revision.title

      assert view
             |> element("table tbody tr:nth-child(3) td:nth-child(1)")
             |> render() =~
               page_one.revision.title
    end
  end

  describe "gating and scheduling live test instructor" do
    setup [:setup_instructor_session]

    test "mount listing for instructor", %{conn: conn, section_1: section} do
      {:ok, _view, html} =
        live(conn, Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug))

      refute html =~ "Admin"
      assert html =~ "Advanced Gating"
    end

    test "mount new for instructor", %{conn: conn, section_1: section} do
      {:ok, _view, html} =
        live(
          conn,
          Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling.New, section.slug)
        )

      assert html =~ "Create Gating Condition"
    end

    test "mount edit for instructor", %{conn: conn, section_1: section, page1: page1} do
      gc = gating_condition_fixture(%{section_id: section.id, resource_id: page1.id})

      {:ok, _view, html} =
        live(
          conn,
          Routes.live_path(
            @endpoint,
            OliWeb.Sections.GatingAndScheduling.Edit,
            section.slug,
            gc.id
          )
        )

      assert html =~ "Edit Gating Condition"
    end
  end

  describe "gating and scheduling edit live test" do
    setup [:setup_admin_session, :create_gating_condition]

    test "displays gating condition info correctly using UTC when local timezone is not set",
         %{
           conn: conn,
           section_1: section,
           gating_condition: gating_condition,
           revision: revision
         } do
      {:ok, view, html} =
        live(
          conn,
          gating_condition_edit_route(section.slug, gating_condition.id)
        )

      timezone = "Etc/UTC"

      assert html =~ "Edit Gating Condition"
      assert has_element?(view, "input[value=\"#{revision.title}\"]")

      assert view
             |> element("#start_date")
             |> render() =~
               utc_datetime_to_localized_datestring(
                 gating_condition.data.start_datetime,
                 timezone
               )

      assert view
             |> element("#end_date")
             |> render() =~
               utc_datetime_to_localized_datestring(gating_condition.data.end_datetime, timezone)
    end

    test "displays gating condition dates correctly using the local timezone when it is set", %{
      conn: conn,
      section_1: section,
      gating_condition: gating_condition
    } do
      {:ok, conn: conn, ctx: _} = set_timezone(%{conn: conn})

      {:ok, view, html} =
        live(
          conn,
          gating_condition_edit_route(section.slug, gating_condition.id)
        )

      timezone = Plug.Conn.get_session(conn, :browser_timezone)

      assert view
             |> element("#start_date")
             |> render() =~
               utc_datetime_to_localized_datestring(
                 gating_condition.data.start_datetime,
                 timezone
               )

      assert view
             |> element("#end_date")
             |> render() =~
               utc_datetime_to_localized_datestring(gating_condition.data.end_datetime, timezone)

      refute html =~ "Your local timezone is not set in the browser"
    end

    test "displays a confirm modal before deleting a gating condition", %{
      conn: conn,
      section_1: section,
      gating_condition: gating_condition
    } do
      {:ok, view, _html} =
        live(
          conn,
          gating_condition_edit_route(section.slug, gating_condition.id)
        )

      view
      |> element("button[phx-click=\"show-delete-gating-condition\"]")
      |> render_click()

      assert view
             |> element("#delete_gating_condition h5.modal-title")
             |> render() =~
               "Are you absolutely sure?"
    end

    test "deletes the gating condition and redirects to the index page", %{
      conn: conn,
      section_1: section,
      gating_condition: gating_condition
    } do
      {:ok, view, _html} =
        live(
          conn,
          gating_condition_edit_route(section.slug, gating_condition.id)
        )

      view
      |> element("button[phx-click=\"show-delete-gating-condition\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"delete-gating-condition\"]")
      |> render_click()

      flash =
        assert_redirected(
          view,
          Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug)
        )

      assert flash["info"] == "Gating condition successfully deleted."

      assert_raise Ecto.NoResultsError,
                   ~r/^expected at least one result but got none in query/,
                   fn -> Gating.get_gating_condition!(gating_condition.id) end
    end

    test "displays error message when dates are not consistent", %{
      conn: conn,
      section_1: section,
      gating_condition: gating_condition
    } do
      {:ok, view, _html} =
        live(
          conn,
          gating_condition_edit_route(section.slug, gating_condition.id)
        )

      render_hook(view, "schedule_start_date_changed", %{value: "2022-01-12T13:48"})
      render_hook(view, "schedule_end_date_changed", %{value: "2022-01-10T13:48"})

      view
      |> element("button[phx-click=\"update_gate\"]")
      |> render_click()

      assert view
             |> element("div#flash")
             |> render() =~
               "Gating condition couldn&#39;t be updated."
    end

    test "updates the gating condition when dates are consistent", %{
      conn: conn,
      section_1: section,
      gating_condition: gating_condition
    } do
      {:ok, view, _html} =
        live(
          conn,
          gating_condition_edit_route(section.slug, gating_condition.id)
        )

      render_hook(view, "schedule_start_date_changed", %{value: "2022-01-12T13:48"})
      render_hook(view, "schedule_end_date_changed", %{value: "2022-01-13T13:48"})

      view
      |> element("button[phx-click=\"update_gate\"]")
      |> render_click()

      flash =
        assert_redirected(
          view,
          Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug)
        )

      assert flash["info"] == "Gating condition successfully updated."
    end

    test "shifts input datestring to utc when local timezone is not set",
         %{
           conn: conn,
           section_1: section,
           gating_condition: gating_condition
         } do
      {:ok, view, _html} =
        live(
          conn,
          gating_condition_edit_route(section.slug, gating_condition.id)
        )

      input_start_date = "2022-01-12T13:48"
      input_end_date = "2022-01-13T13:48"

      render_hook(view, "schedule_start_date_changed", %{value: input_start_date})
      render_hook(view, "schedule_end_date_changed", %{value: input_end_date})

      view
      |> element("button[phx-click=\"update_gate\"]")
      |> render_click()

      updated_gating_condition = Gating.get_gating_condition!(gating_condition.id)

      assert utc_datetime_to_localized_datestring(
               updated_gating_condition.data.start_datetime,
               "Etc/UTC"
             ) == input_start_date

      assert utc_datetime_to_localized_datestring(
               updated_gating_condition.data.end_datetime,
               "Etc/UTC"
             ) == input_end_date
    end

    test "shifts input datestring to utc using the local timezone when it is set", %{
      conn: conn,
      section_1: section,
      gating_condition: gating_condition
    } do
      {:ok, conn: conn, ctx: _} = set_timezone(%{conn: conn})

      {:ok, view, _html} =
        live(
          conn,
          gating_condition_edit_route(section.slug, gating_condition.id)
        )

      timezone = Plug.Conn.get_session(conn, :browser_timezone)

      input_start_date = "2022-01-12T13:48"
      input_end_date = "2022-01-13T13:48"

      render_hook(view, "schedule_start_date_changed", %{value: input_start_date})
      render_hook(view, "schedule_end_date_changed", %{value: input_end_date})

      view
      |> element("button[phx-click=\"update_gate\"]")
      |> render_click()

      updated_gating_condition = Gating.get_gating_condition!(gating_condition.id)

      assert utc_datetime_to_localized_datestring(
               updated_gating_condition.data.start_datetime,
               timezone
             ) == input_start_date

      assert utc_datetime_to_localized_datestring(
               updated_gating_condition.data.end_datetime,
               timezone
             ) == input_end_date
    end

    @tag :flaky
    test "create student exceptions for more than one student works correctly", %{
      conn: conn,
      section_1: section,
      gating_condition: gating_condition,
      revision: revision
    } do
      user = user_fixture(%{family_name: "Curry", given_name: "Stephen"})
      user_2 = user_fixture(%{family_name: "Durant", given_name: "Kevin"})

      # create a student exception for the user
      gating_condition_fixture(%{
        section_id: section.id,
        resource_id: revision.resource_id,
        parent_id: gating_condition.id,
        user_id: user.id
      })

      # create a student exception for the user_2
      gating_condition_fixture(%{
        section_id: section.id,
        resource_id: revision.resource_id,
        parent_id: gating_condition.id,
        user_id: user_2.id
      })

      {:ok, view, _html} =
        live(
          conn,
          gating_condition_edit_route(section.slug, gating_condition.id)
        )

      # get the count of exceptions for the gating condition
      count_exceptions = Gating.count_exceptions(gating_condition.id)

      # assert that the count of exceptions is 2
      assert count_exceptions == 2

      # assert that the view displays the correct message
      assert view |> element("div.alert.alert-primary > div") |> render() =~
               "This gate has #{count_exceptions} student-specific exceptions."

      # click on the "Manage Student Exceptions" button
      view
      |> element(
        "~s(a[href='/sections/#{section.slug}/gating_and_scheduling/exceptions/#{gating_condition.id}'])",
        "Manage Student Exceptions"
      )
      |> render_click()

      # assert that we are redirected to the exceptions page
      assert_redirected(
        view,
        ~p"/sections/#{section.slug}/gating_and_scheduling/exceptions/#{gating_condition.id}"
      )

      {:ok, view, _html} =
        live(
          conn,
          ~p"/sections/#{section.slug}/gating_and_scheduling/exceptions/#{gating_condition.id}"
        )

      # assert that we have the correct exceptions in the view
      assert view
             |> element("tbody > tr:first-child > td:first-child a")
             |> render() =~
               "#{user.family_name}, #{user.given_name}"

      assert view
             |> element("tbody > tr:nth-child(2) > td:first-child a")
             |> render() =~
               "#{user_2.family_name}, #{user_2.given_name}"

      # assert that we have the button to create a new exception
      assert has_element?(view, "a", "New Student Exception")
    end
  end

  describe "gating and scheduling new live test" do
    setup [:setup_admin_session]

    test "displays error message when dates are not consistent", %{
      conn: conn,
      section_1: section
    } do
      {:ok, view, _html} =
        live(
          conn,
          gating_condition_new_route(section.slug)
        )

      create_gating_condition_through_ui(view, "schedule", "2022-01-12T13:48", "2022-01-10T13:48")

      assert view
             |> element("div#flash")
             |> render() =~
               "Gating condition couldn&#39;t be created."
    end

    test "creates the gating condition when dates are consistent", %{
      conn: conn,
      section_1: section
    } do
      {:ok, view, _html} =
        live(
          conn,
          gating_condition_new_route(section.slug)
        )

      create_gating_condition_through_ui(view, "schedule", "2022-01-12T13:48", "2022-01-13T13:48")

      flash =
        assert_redirected(
          view,
          Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug)
        )

      assert flash["info"] == "Gating condition successfully created."
    end

    test "shifts input datestring to utc when local timezone is not set",
         %{
           conn: conn,
           section_1: section
         } do
      {:ok, view, _html} =
        live(
          conn,
          gating_condition_new_route(section.slug)
        )

      input_start_date = "2022-01-12T13:48"
      input_end_date = "2022-01-13T13:48"

      create_gating_condition_through_ui(view, "schedule", input_start_date, input_end_date)

      created_gating_condition =
        Repo.one(
          from(g in GatingCondition,
            where: g.section_id == ^section.id,
            order_by: [desc: g.id],
            limit: 1
          )
        )

      assert utc_datetime_to_localized_datestring(
               created_gating_condition.data.start_datetime,
               "Etc/UTC"
             ) == input_start_date

      assert utc_datetime_to_localized_datestring(
               created_gating_condition.data.end_datetime,
               "Etc/UTC"
             ) == input_end_date
    end

    test "shifts input datestring to utc using the local timezone when it is set", %{
      conn: conn,
      section_1: section
    } do
      {:ok, conn: conn, ctx: _} = set_timezone(%{conn: conn})

      {:ok, view, _html} =
        live(
          conn,
          gating_condition_new_route(section.slug)
        )

      timezone = Plug.Conn.get_session(conn, :browser_timezone)

      input_start_date = "2022-01-12T13:48"
      input_end_date = "2022-01-13T13:48"

      create_gating_condition_through_ui(view, "schedule", input_start_date, input_end_date)

      created_gating_condition =
        Repo.one(
          from(g in GatingCondition,
            where: g.section_id == ^section.id,
            order_by: [desc: g.id],
            limit: 1
          )
        )

      assert utc_datetime_to_localized_datestring(
               created_gating_condition.data.start_datetime,
               timezone
             ) == input_start_date

      assert utc_datetime_to_localized_datestring(
               created_gating_condition.data.end_datetime,
               timezone
             ) == input_end_date
    end

    test "select a type works correctly", %{conn: conn, section_1: section} do
      {:ok, view, _html} =
        live(
          conn,
          gating_condition_new_route(section.slug)
        )

      # change select option to "schedule"
      view
      |> element("select[phx-change=\"select-condition\"]")
      |> render_change(%{"value" => "schedule"})

      assert view
             |> element("div[id=\"start_date\"]")

      assert view
             |> element("div[id=\"end_date\"]")

      # change select option to "always open"
      view
      |> element("select[phx-change=\"select-condition\"]")
      |> render_change(%{"value" => "always_open"})

      assert view
             |> element("div[class=\"alert alert-secondary\"][role=\"alert\"]")
             |> render() =~
               "This will always be open to this student."

      # change select option to "started"
      view
      |> element("select[phx-change=\"select-condition\"]")
      |> render_change(%{"value" => "started"})

      assert view
             |> element("label[for=\"source\"]")
             |> render() =~
               "Resource That Must Be Started"

      # change select option to "finished"
      view
      |> element("select[phx-change=\"select-condition\"]")
      |> render_change(%{"value" => "finished"})

      assert view
             |> element("label[for=\"source\"]")
             |> render() =~
               "Resource That Must Be Finished"

      assert view
             |> element("input[phx-click=\"toggle-min-score\"]")

      assert view
             |> element("input[phx-value-change=\"change-min-score\"]")

      # change select option to "progress"
      view
      |> element("select[phx-change=\"select-condition\"]")
      |> render_change(%{"value" => "progress"})

      assert view
             |> element("label[for=\"source\"]")
             |> render() =~
               "Resource That Must Have Progress"

      assert view
             |> element("input[phx-click=\"toggle-min-score\"]")

      assert view
             |> element("input[phx-value-change=\"change-min-score\"]")
    end
  end

  defp setup_admin_session(%{conn: conn}) do
    map = Seeder.base_project_with_resource4()
    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().system_admin})

    Seeder.create_schedule_gating_condition(
      DateTime.add(yesterday(), -(60 * 60 * 24), :second),
      yesterday(),
      map.page1.id,
      map.section_1.id
    )

    Seeder.create_schedule_gating_condition(
      DateTime.add(yesterday(), -(60 * 60 * 24), :second),
      yesterday(),
      map.nested_page1.id,
      map.section_1.id
    )

    Seeder.create_schedule_gating_condition(
      DateTime.add(yesterday(), -(60 * 60 * 24), :second),
      yesterday(),
      map.nested_page2.id,
      map.section_1.id
    )

    conn =
      Plug.Test.init_test_session(conn, [])
      |> log_in_author(admin)

    {:ok, Map.merge(map, %{conn: conn, admin: admin})}
  end

  defp setup_instructor_session(%{conn: conn}) do
    map = Seeder.base_project_with_resource4()

    instructor = user_fixture()
    Sections.enroll(instructor.id, map.section_1.id, [ContextRoles.get_role(:context_instructor)])

    Seeder.create_schedule_gating_condition(
      DateTime.add(yesterday(), -(60 * 60 * 24), :second),
      yesterday(),
      map.page1.id,
      map.section_1.id
    )

    conn =
      Plug.Test.init_test_session(conn, [])
      |> log_in_user(instructor)

    {:ok, Map.merge(map, %{conn: conn, instructor: instructor})}
  end

  defp create_gating_condition(%{section_1: section}) do
    project = insert(:project)

    section_project_publication =
      insert(:section_project_publication, %{section: section, project: project})

    revision = insert(:revision)

    insert(:section_resource, %{
      section: section,
      project: project,
      resource_id: revision.resource.id
    })

    insert(:published_resource, %{
      resource: revision.resource,
      revision: revision,
      publication: section_project_publication.publication
    })

    gating_condition = insert(:gating_condition, %{section: section, resource: revision.resource})

    [gating_condition: gating_condition, revision: revision]
  end
end

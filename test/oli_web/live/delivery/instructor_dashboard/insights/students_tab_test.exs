defmodule OliWeb.Delivery.InstructorDashboard.StudentsTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory
  import Ecto.Query

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.{Paywall, Sections}
  alias Oli.Delivery.Attempts.Core
  alias Oli.{Repo, Seeder}

  defp live_view_students_route(section_slug, params \\ %{}) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :overview,
      :students,
      params
    )
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)

      redirect_path =
        "/users/log_in"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_students_route(section.slug))
    end
  end

  describe "student" do
    setup [:user_conn]

    test "can not access page", %{user: user, conn: conn} do
      section = insert(:section)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_students_route(section.slug))
    end
  end

  describe "instructor" do
    setup [:instructor_conn, :set_timezone, :section_with_assessment]

    test "cannot access page if not enrolled to section", %{conn: conn, section: section} do
      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_students_route(section.slug))
    end

    test "can access page if enrolled to section", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      user = insert(:user)

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug))

      # Students tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_route(section.slug)}"].border-b-2},
               "Students"
             )

      # Students table gets rendered
      assert has_element?(view, "h4", "Students")

      assert render(view) =~
               OliWeb.Common.Utils.name(user.name, user.given_name, user.family_name)
    end

    test "students email gets rendered correctly", %{
      conn: conn,
      section: section,
      instructor: instructor
    } do
      student_1 =
        insert(:user, %{given_name: "Kevin", family_name: "Durant", email: "kevin.durant@nba.com"})

      student_2 =
        insert(:user, %{given_name: "LeBron", family_name: "James", email: "lebron.james@nba.com"})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(student_1.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(student_2.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug))

      [student_1_email, student_2_email] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tbody tr td:nth-child(2)})
        |> Enum.map(fn td -> Floki.text(td) end)

      assert student_1_email == student_1.email
      assert student_2_email == student_2.email
    end

    test "students last interaction gets rendered (for a student with interaction and yet with no interaction)",
         %{instructor: instructor, conn: conn, ctx: ctx} do
      %{section: section, mod1_pages: mod1_pages} =
        Oli.Seeder.base_project_with_larger_hierarchy()

      [page_1, page_2, _page_3] = mod1_pages

      student_1 = insert(:user, %{given_name: "Commited", family_name: "Student"})
      student_2 = insert(:user, %{given_name: "Lazy", family_name: "Student"})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(student_1.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, %{updated_at: student_2_enrollment_timestamp}} =
        Sections.enroll(student_2.id, section.id, [ContextRoles.get_role(:context_learner)])

      # we set 2 interactions for student_1, but only the latest one should be rendered
      set_interaction(
        section,
        page_1,
        student_1,
        ~U[2023-04-04 12:25:42Z]
      )

      set_interaction(
        section,
        page_2,
        student_1,
        ~U[2023-04-05 12:25:42Z]
      )

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug))

      [student_1_last_interaction] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tbody tr:nth-child(1) td:nth-child(3)})
        |> Enum.map(fn td -> Floki.text(td) end)

      [student_2_last_interaction] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tbody tr:nth-child(2) td:nth-child(3)})
        |> Enum.map(fn td -> Floki.text(td) end)

      assert student_1_last_interaction =~
               ~U[2023-04-05 12:25:42Z]
               |> OliWeb.Common.FormatDateTime.convert_datetime(ctx)
               |> Timex.format!("{Mshort}. {0D}, {YYYY} - {h12}:{m} {AM}")

      assert student_2_last_interaction =~
               student_2_enrollment_timestamp
               |> OliWeb.Common.FormatDateTime.convert_datetime(ctx)
               |> Timex.format!("{Mshort}. {0D}, {YYYY} - {h12}:{m} {AM}")
    end

    test "students table gets rendered considering the given url params", %{
      instructor: instructor,
      conn: conn
    } do
      stub_real_current_time()

      %{section: section, mod1_pages: mod1_pages, mod1_resource: mod1_resource} =
        Oli.Seeder.base_project_with_larger_hierarchy()

      [page_1, _page_2, _page_3] = mod1_pages

      user_1 = insert(:user, %{given_name: "Lionel", family_name: "Messi"})
      user_2 = insert(:user, %{given_name: "Luis", family_name: "Suarez"})
      user_3 = insert(:user, %{given_name: "Neymar", family_name: "Jr"})
      user_4 = insert(:user, %{given_name: "Angelito", family_name: "Di Maria"})
      user_5 = insert(:user, %{given_name: "Lionel", family_name: "Scaloni"})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user_1.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_2.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_3.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_4.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_5.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, _} = Sections.rebuild_contained_pages(section)

      set_interaction(
        section,
        page_1,
        user_1,
        ~U[2020-04-05 12:25:42Z]
      )

      set_interaction(
        section,
        page_1,
        user_2,
        ~U[2021-04-05 12:26:42Z]
      )

      set_interaction(
        section,
        page_1,
        user_3,
        ~U[2023-04-05 12:28:42Z]
      )

      set_interaction(
        section,
        page_1,
        user_4,
        ~U[2019-04-05 13:28:42Z]
      )

      ### sorting by last interaction

      params = %{
        sort_order: :asc,
        sort_by: :last_interaction
      }

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug, params))

      [student_for_tr_1, student_for_tr_2, student_for_tr_3, student_for_tr_4] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert student_for_tr_1 =~ "Di Maria, Angelito"
      assert student_for_tr_2 =~ "Messi, Lionel"
      assert student_for_tr_3 =~ "Suarez, Luis"
      assert student_for_tr_4 =~ "Jr, Neymar"

      ###

      set_progress(section.id, page_1.published_resource.resource_id, user_1.id, 0)
      set_progress(section.id, page_1.published_resource.resource_id, user_2.id, 0.2)
      set_progress(section.id, page_1.published_resource.resource_id, user_3.id, 0.2)
      set_progress(section.id, page_1.published_resource.resource_id, user_4.id, 0.3)
      set_progress(section.id, page_1.published_resource.resource_id, user_5.id, 0.7)

      ### sorting by student
      params = %{
        sort_order: :desc,
        sort_by: :name
      }

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug, params))

      [student_for_tr_1, student_for_tr_2, student_for_tr_3, student_for_tr_4] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert student_for_tr_4 =~ "Di Maria, Angelito"
      assert student_for_tr_3 =~ "Jr, Neymar"
      assert student_for_tr_2 =~ "Messi, Lionel"
      assert student_for_tr_1 =~ "Suarez, Luis"

      ### sorting by progress
      params = %{
        sort_order: :asc,
        sort_by: :progress
      }

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug, params))

      [student_for_tr_1, student_for_tr_2, student_for_tr_3, student_for_tr_4] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert student_for_tr_1 =~ "Messi, Lionel"

      # it sorts by name when progress is the same
      assert student_for_tr_2 =~ "Jr, Neymar"
      assert student_for_tr_3 =~ "Suarez, Luis"

      assert student_for_tr_4 =~ "Di Maria, Angelito"

      ### text filtering
      params = %{
        text_search: "Messi"
      }

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug, params))

      [student_for_tr_1] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert student_for_tr_1 =~ "Messi, Lionel"

      assert element(view, "#students_search_input-input") |> render() =~ ~s'value="Messi"'

      refute render(view) =~ "Jr, Neymar"
      refute render(view) =~ "Suarez, Luis"
      refute render(view) =~ "Di Maria, Angelito"

      ### pagination
      params = %{
        offset: 2,
        limit: 2,
        sort_order: :desc
      }

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug, params))

      [student_for_tr_1, student_for_tr_2] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert student_for_tr_1 =~ "Jr, Neymar"
      assert student_for_tr_2 =~ "Di Maria, Angelito"

      assert element(view, "#footer_paging > div:first-child") |> render() =~
               "3 - 4 of 4 results"

      assert element(view, "li.page-item.active a", "2")
      refute render(view) =~ "Suarez, Luis"
      refute render(view) =~ "Messi, Lionel"

      ### filtering by container
      params = %{container_id: mod1_resource.id}

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug, params))

      progress =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr [data-progress-check]})
        |> Enum.map(fn div_tag -> Floki.text(div_tag) |> String.trim() end)

      assert progress == ["3%", "2%", "0%", "2%"]

      ### filtering by no container
      ### (we want to get the progress across all course section)
      params = %{container_id: nil}

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug, params))

      progress =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr [data-progress-check]})
        |> Enum.map(fn div_tag -> Floki.text(div_tag) |> String.trim() end)

      assert progress == ["3%", "2%", "0%", "2%"]

      ### filtering by non existing container
      params = %{container_id: 99999}

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug, params))

      progress =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr [data-progress-check]})
        |> Enum.map(fn div_tag -> Floki.text(div_tag) |> String.trim() end)

      assert progress == ["3%", "2%", "0%", "2%"]

      ### filtering by page
      params = %{page_id: page_1.published_resource.resource_id}

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug, params))

      progress =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr [data-progress-check]})
        |> Enum.map(fn div_tag -> Floki.text(div_tag) |> String.trim() end)

      assert progress == ["30%", "20%", "0%", "20%"]

      ### filtering by non students option
      params = %{filter_by: :non_students}

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug, params))

      refute render(view) =~ "Messi, Lionel"
      refute render(view) =~ "Suarez, Luis"

      ### filtering by not paid option
      params = %{filter_by: :not_paid}

      {:ok, section_with_payment} =
        Sections.update_section(section, %{
          requires_payment: true,
          amount: %{amount: "1000", currency: "USD"},
          has_grace_period: false
        })

      {:ok, view, _html} = live(conn, live_view_students_route(section_with_payment.slug, params))

      [not_paid_1, not_paid_2, not_paid_3, not_paid_4] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert not_paid_1 =~ "Di Maria, Angelito"
      assert not_paid_2 =~ "Jr, Neymar"
      assert not_paid_3 =~ "Messi, Lionel"
      assert not_paid_4 =~ "Suarez, Luis"
      refute render(view) =~ "Scaloni, Lionel"

      ### filtering by paid option
      params = %{filter_by: :paid}

      enrollment_user_1 = Sections.get_enrollment(section_with_payment.slug, user_1.id)

      insert(:payment, %{
        enrollment: enrollment_user_1,
        section: section_with_payment,
        application_date: yesterday()
      })

      {:ok, view, _html} = live(conn, live_view_students_route(section_with_payment.slug, params))

      [paid_1] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert paid_1 =~ "Messi, Lionel"
      refute render(view) =~ "Scaloni, Lionel"
      refute render(view) =~ "Di Maria, Angelito"
      refute render(view) =~ "Jr, Neymar"

      ### filtering by withing grace period option
      params = %{filter_by: :grace_period}

      {:ok, section_with_grace_period} =
        Sections.update_section(section_with_payment, %{
          start_date: yesterday(),
          end_date: tomorrow(),
          requires_payment: true,
          amount: %{amount: "1000", currency: "USD"},
          has_grace_period: true,
          grace_period_days: 10
        })

      {:ok, view, _html} =
        live(conn, live_view_students_route(section_with_grace_period.slug, params))

      [grace_period_1, grace_period_2, grace_period_3] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert grace_period_1 =~ "Di Maria, Angelito"
      assert grace_period_2 =~ "Jr, Neymar"
      assert grace_period_3 =~ "Suarez, Luis"
      refute render(view) =~ "Messi, Lionel"

      [payment_status_1, payment_status_2, payment_status_3] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table td:last-child})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert payment_status_1 =~ "Grace Period: 8d remaining"
      assert payment_status_2 =~ "Grace Period: 8d remaining"
      assert payment_status_3 =~ "Grace Period: 8d remaining"
    end

    test "sort by payment status column works correctly", %{conn: conn, instructor: instructor} do
      stub_real_current_time()

      %{section: section} = Oli.Seeder.base_project_with_larger_hierarchy()

      {:ok, section} =
        Sections.update_section(section, %{
          requires_payment: true,
          amount: Money.new(:USD, 100),
          grace_period_days: 1
        })

      user_1 = insert(:user, %{given_name: "Lionel", family_name: "Messi"})
      user_2 = insert(:user, %{given_name: "Luis", family_name: "Suarez"})
      user_3 = insert(:user, %{given_name: "Neymar", family_name: "Jr"})
      user_4 = insert(:user, %{given_name: "Angelito", family_name: "Di Maria"})
      user_5 = insert(:user, %{given_name: "Lionel", family_name: "Scaloni"})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user_1.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_2.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_3.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_4.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_5.id, section.id, [ContextRoles.get_role(:context_learner)])

      enrollment_1 = Sections.get_enrollment(section.slug, user_1.id)
      enrollment_4 = Sections.get_enrollment(section.slug, user_4.id)
      enrollment_5 = Sections.get_enrollment(section.slug, user_5.id)

      # Messi has paid
      Paywall.create_payment(%{
        generation_date: ~U[2024-08-01 10:16:10.686389Z],
        application_date: ~U[2024-08-01 10:16:10.686389Z],
        amount: Money.new(100, "USD"),
        section_id: section.id,
        enrollment_id: enrollment_1.id
      })

      # Di Maria has paid
      Paywall.create_payment(%{
        generation_date: ~U[2024-08-20 10:16:10.686389Z],
        application_date: ~U[2024-08-20 10:16:10.686389Z],
        amount: Money.new(100, "USD"),
        section_id: section.id,
        enrollment_id: enrollment_4.id
      })

      # Scaloni has paid
      Paywall.create_payment(%{
        generation_date: ~U[2024-09-15 10:16:10.686389Z],
        application_date: ~U[2024-09-15 10:16:10.686389Z],
        amount: Money.new(100, "USD"),
        section_id: section.id,
        enrollment_id: enrollment_5.id
      })

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug))

      # sorting by payment status in asc order
      view
      |> element(".instructor_dashboard_table th[phx-value-sort_by=\"payment_status\"]")
      |> render_click()

      [payment_status_1, payment_status_2, payment_status_3, payment_status_4, payment_status_5] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table td:last-child})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      # asserts the order of the payment status is ascending
      assert payment_status_1 =~ "Not Paid"
      assert payment_status_2 =~ "Not Paid"
      assert payment_status_3 =~ "Paid on August 1, 2024 6:16 AM"
      assert payment_status_4 =~ "Paid on August 20, 2024 6:16 AM"
      assert payment_status_5 =~ "Paid on September 15, 2024 6:16 AM"

      # sorting by payment status in desc order
      view
      |> element(".instructor_dashboard_table th[phx-value-sort_by=\"payment_status\"]")
      |> render_click()

      # asserts the order of the payment status is descending
      [payment_status_1, payment_status_2, payment_status_3, payment_status_4, payment_status_5] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table td:last-child})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert payment_status_1 =~ "Paid on September 15, 2024 6:16 AM"
      assert payment_status_2 =~ "Paid on August 20, 2024 6:16 AM"
      assert payment_status_3 =~ "Paid on August 1, 2024 6:16 AM"
      assert payment_status_4 =~ "Not Paid"
      assert payment_status_5 =~ "Not Paid"
    end

    test "cards to filter works correctly", %{conn: conn, instructor: instructor} do
      %{
        section: section,
        mod1_pages: mod1_pages,
        mod2_pages: mod2_pages,
        mod3_pages: mod3_pages,
        mod1_resource: mod1_resource
      } =
        Oli.Seeder.base_project_with_larger_hierarchy()

      [page_1, page_2, page_3] = mod1_pages
      [page_4, page_5, page_6] = mod2_pages
      [page_7, page_8, page_9, _page_10] = mod3_pages

      user_1 = insert(:user, %{given_name: "Lionel", family_name: "Messi"})
      user_2 = insert(:user, %{given_name: "Luis", family_name: "Suarez"})
      user_3 = insert(:user, %{given_name: "Neymar", family_name: "Jr"})
      user_4 = insert(:user, %{given_name: "Angelito", family_name: "Di Maria"})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user_1.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_2.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_3.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_4.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, _} = Sections.rebuild_contained_pages(section)

      set_progress(section.id, page_1.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_2.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_3.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_4.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_5.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_6.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_7.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_8.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_9.published_resource.resource_id, user_1.id, 1)

      params = %{container_id: mod1_resource.id}

      {:ok, view, _html} =
        live(conn, live_view_students_route(section.slug, params))

      # Low Progress card it should have 3 students
      assert element(view, "div[phx-value-selected=\"low_progress\"]") |> render() =~
               "Low Progress"

      assert element(view, "div[phx-value-selected=\"low_progress\"]") |> render() =~ "3"
      assert element(view, "div[phx-value-selected=\"low_progress\"]") |> render() =~ "Students"

      # Low Proficiency card it should have 0 students
      assert element(view, "div[phx-value-selected=\"low_proficiency\"]") |> render() =~
               "Low Proficiency"

      assert element(view, "div[phx-value-selected=\"low_proficiency\"]") |> render() =~ "0"

      assert element(view, "div[phx-value-selected=\"low_proficiency\"]") |> render() =~
               "Students"

      # Zero Interaction in a week card it should have 2 students
      assert element(view, "div[phx-value-selected=\"zero_interaction_in_a_week\"]") |> render() =~
               "Zero interaction in a week"

      assert element(view, "div[phx-value-selected=\"zero_interaction_in_a_week\"]") |> render() =~
               "0"

      assert element(view, "div[phx-value-selected=\"zero_interaction_in_a_week\"]") |> render() =~
               "Students"

      ## Filtering by Low Progress
      element(view, "div[phx-value-selected=\"low_progress\"]") |> render_click()

      assert has_element?(view, "table tr td div a", user_2.family_name)
      assert has_element?(view, "table tr td div a", user_3.family_name)
      assert has_element?(view, "table tr td div a", user_4.family_name)
      refute has_element?(view, "table tr td div a", user_1.family_name)

      ## Filtering by Low Proficiency
      element(view, "div[phx-value-selected=\"low_proficiency\"]") |> render_click()

      assert has_element?(view, "p", "None exist")

      ## Filtering by Zero Interaction in a week

      element(view, "div[phx-value-selected=\"zero_interaction_in_a_week\"]") |> render_click()

      refute has_element?(view, "table tr td div a", user_1.family_name)
      refute has_element?(view, "table tr td div a", user_2.family_name)
      refute has_element?(view, "table tr td div a", user_3.family_name)
      refute has_element?(view, "table tr td div a", user_4.family_name)
    end

    test "selecting and deselecting a card works correctly", %{conn: conn, instructor: instructor} do
      %{
        section: section,
        mod1_pages: mod1_pages,
        mod2_pages: mod2_pages,
        mod3_pages: mod3_pages,
        mod1_resource: mod1_resource
      } =
        Oli.Seeder.base_project_with_larger_hierarchy()

      [page_1, page_2, page_3] = mod1_pages
      [page_4, page_5, page_6] = mod2_pages
      [page_7, page_8, page_9, _page_10] = mod3_pages

      user_1 = insert(:user, %{given_name: "Lionel", family_name: "Messi"})
      user_2 = insert(:user, %{given_name: "Luis", family_name: "Suarez"})
      user_3 = insert(:user, %{given_name: "Neymar", family_name: "Jr"})
      user_4 = insert(:user, %{given_name: "Angelito", family_name: "Di Maria"})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user_1.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_2.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_3.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_4.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, _} = Sections.rebuild_contained_pages(section)

      set_progress(section.id, page_1.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_2.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_3.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_4.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_5.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_6.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_7.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_8.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_9.published_resource.resource_id, user_1.id, 1)

      params = %{container_id: mod1_resource.id}

      {:ok, view, _html} =
        live(conn, live_view_students_route(section.slug, params))

      # Low Progress card it should have 3 students
      assert element(view, "div[phx-value-selected=\"low_progress\"]") |> render() =~
               "Low Progress"

      assert element(view, "div[phx-value-selected=\"low_progress\"]") |> render() =~ "3"
      assert element(view, "div[phx-value-selected=\"low_progress\"]") |> render() =~ "Students"

      ## Select Low Progress card
      element(view, "div[phx-value-selected=\"low_progress\"]") |> render_click()

      ## Check that only 3 students are displayed
      assert has_element?(view, "table tr td div a", user_2.family_name)
      assert has_element?(view, "table tr td div a", user_3.family_name)
      assert has_element?(view, "table tr td div a", user_4.family_name)
      refute has_element?(view, "table tr td div a", user_1.family_name)

      ## Click again to deselect Low Progress card
      element(view, "div[phx-value-selected=\"low_progress\"]") |> render_click()

      ## Check that all students are displayed
      assert has_element?(view, "table tr td div a", user_2.family_name)
      assert has_element?(view, "table tr td div a", user_3.family_name)
      assert has_element?(view, "table tr td div a", user_4.family_name)
      assert has_element?(view, "table tr td div a", user_1.family_name)
    end

    test "navigation between containers works correctly", %{conn: conn, instructor: instructor} do
      %{
        section: section,
        unit1_container: unit1_container,
        unit2_container: unit2_container
      } = Seeder.base_project_with_larger_hierarchy()

      user_1 = insert(:user, %{given_name: "Diego", family_name: "Forlán"})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user_1.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, _} = Sections.rebuild_contained_pages(section)

      {:ok, view, _html} =
        live(
          conn,
          ~p"/sections/#{section.slug}/instructor_dashboard/insights/content"
        )

      ## Click on Unit 2 container
      element(
        view,
        "a",
        unit2_container.revision.title
      )
      |> render_click()

      ## Check that Unit 2 container title is displayed
      assert has_element?(view, "div", unit2_container.revision.title)
      assert has_element?(view, "div", "Navigate within 2 filtered units")
      assert has_element?(view, "div", "Navigate within ALL units")

      ## Click to navigate to Unit 1 container
      element(
        view,
        "button[phx-click=\"change_navigation\"][value=\"#{unit1_container.resource.id}\"]"
      )
      |> render_click()

      ## Check that Unit 1 container title is displayed
      assert has_element?(view, "div", unit1_container.revision.title)

      ## Click to navigate to ALL units
      element(
        view,
        "form[phx-change=\"select_option\"]"
      )
      |> render_change(%{
        "_target" => ["container", "option"],
        "container" => %{"option" => "by_all"}
      })

      ## Check again that Unit 1 container title is displayed
      assert has_element?(view, "div", unit1_container.revision.title)
    end

    test "button to back to units/modules works correctly", %{conn: conn, instructor: instructor} do
      %{
        section: section,
        mod1_pages: mod1_pages,
        unit2_container: unit2_container
      } = Seeder.base_project_with_larger_hierarchy()

      [page_1, page_2, page_3] = mod1_pages

      user_1 = insert(:user, %{given_name: "Diego", family_name: "Forlán"})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user_1.id, section.id, [ContextRoles.get_role(:context_learner)])

      set_progress(section.id, page_1.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_2.published_resource.resource_id, user_1.id, 1)
      set_progress(section.id, page_3.published_resource.resource_id, user_1.id, 1)

      {:ok, _} = Sections.rebuild_contained_pages(section)

      {:ok, view, _html} =
        live(
          conn,
          ~p"/sections/#{section.slug}/instructor_dashboard/insights/content"
        )

      ## Filtering by zero student progress card
      element(view, "div[phx-value-selected=\"zero_student_progress\"]") |> render_click()

      ## Click on Unit 2 container
      element(
        view,
        "a",
        unit2_container.revision.title
      )
      |> render_click()

      ## Check that Unit 2 container title is displayed
      element(view, "h4", "Students Enrolled in #{unit2_container.revision.title}")

      ## Click on back to units/modules button
      element(view, ~s{a[role="back button"]}) |> render_click()

      params = %{
        offset: 0,
        limit: 20,
        sort_by: :numbering_index,
        sort_order: :asc,
        container_filter_by: :units,
        selected_card_value: :zero_student_progress,
        progress_percentage: 100,
        progress_selector: :is_less_than_or_equal,
        selected_proficiency_ids: Jason.encode!([])
      }

      ## Check that the page is back to the units/modules view
      assert_redirected(
        view,
        ~p"/sections/#{section.slug}/instructor_dashboard/insights/content?#{params}"
      )
    end
  end

  describe "page size change" do
    setup [:instructor_conn, :set_timezone, :section_with_assessment]

    test "lists table elements according to the default page size", %{
      instructor: instructor,
      conn: conn
    } do
      %{section: section, mod1_pages: mod1_pages} =
        Oli.Seeder.base_project_with_larger_hierarchy()

      [page_1, _page_2, _page_3] = mod1_pages

      user_1 = insert(:user, %{given_name: "Lionel", family_name: "Messi"})
      user_2 = insert(:user, %{given_name: "Luis", family_name: "Suarez"})
      user_3 = insert(:user, %{given_name: "Neymar", family_name: "Jr"})
      user_4 = insert(:user, %{given_name: "Angelito", family_name: "Di Maria"})
      user_5 = insert(:user, %{given_name: "Lionel", family_name: "Scaloni"})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user_1.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_2.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_3.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_4.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_5.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, _} = Sections.rebuild_contained_pages(section)

      set_progress(section.id, page_1.published_resource.resource_id, user_1.id, 0.9)
      set_progress(section.id, page_1.published_resource.resource_id, user_2.id, 0.6)
      set_progress(section.id, page_1.published_resource.resource_id, user_3.id, 0)
      set_progress(section.id, page_1.published_resource.resource_id, user_4.id, 0.3)
      set_progress(section.id, page_1.published_resource.resource_id, user_5.id, 0.7)

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug))

      [student_for_tr_1, student_for_tr_2, student_for_tr_3, student_for_tr_4] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      assert student_for_tr_1 =~ "Di Maria, Angelito"
      assert student_for_tr_2 =~ "Jr, Neymar"
      assert student_for_tr_3 =~ "Messi, Lionel"
      assert student_for_tr_4 =~ "Suarez, Luis"

      # It does not display pagination options
      refute has_element?(view, "nav[aria-label=\"Paging\"]")

      # It displays page size dropdown
      assert has_element?(view, "form select.torus-select option[selected]", "20")
    end

    test "updates page size and list expected elements", %{
      instructor: instructor,
      conn: conn
    } do
      %{section: section, mod1_pages: mod1_pages} =
        Oli.Seeder.base_project_with_larger_hierarchy()

      [page_1, _page_2, _page_3] = mod1_pages

      user_1 = insert(:user, %{given_name: "Lionel", family_name: "Messi"})
      user_2 = insert(:user, %{given_name: "Luis", family_name: "Suarez"})
      user_3 = insert(:user, %{given_name: "Neymar", family_name: "Jr"})
      user_4 = insert(:user, %{given_name: "Angelito", family_name: "Di Maria"})
      user_5 = insert(:user, %{given_name: "Lionel", family_name: "Scaloni"})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user_1.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_2.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_3.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_4.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_5.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, _} = Sections.rebuild_contained_pages(section)

      set_progress(section.id, page_1.published_resource.resource_id, user_1.id, 0.9)
      set_progress(section.id, page_1.published_resource.resource_id, user_2.id, 0.6)
      set_progress(section.id, page_1.published_resource.resource_id, user_3.id, 0)
      set_progress(section.id, page_1.published_resource.resource_id, user_4.id, 0.3)
      set_progress(section.id, page_1.published_resource.resource_id, user_5.id, 0.7)

      {:ok, view, _html} = live(conn, live_view_students_route(section.slug))

      # Change page size from default (20) to 2
      view
      |> element("#footer_paging_page_size_form")
      |> render_change(%{limit: "2"})

      [student_for_tr_1, student_for_tr_2] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      # Page 1
      assert student_for_tr_1 =~ "Di Maria, Angelito"
      assert student_for_tr_2 =~ "Jr, Neymar"
    end

    test "keeps showing the same elements when changing the page size", %{
      instructor: instructor,
      conn: conn
    } do
      %{section: section, mod1_pages: mod1_pages} =
        Oli.Seeder.base_project_with_larger_hierarchy()

      [page_1, _page_2, _page_3] = mod1_pages

      user_1 = insert(:user, %{given_name: "Lionel", family_name: "Messi"})
      user_2 = insert(:user, %{given_name: "Luis", family_name: "Suarez"})
      user_3 = insert(:user, %{given_name: "Neymar", family_name: "Jr"})
      user_4 = insert(:user, %{given_name: "Angelito", family_name: "Di Maria"})
      user_5 = insert(:user, %{given_name: "Lionel", family_name: "Scaloni"})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user_1.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_2.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_3.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_4.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user_5.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, _} = Sections.rebuild_contained_pages(section)

      set_progress(section.id, page_1.published_resource.resource_id, user_1.id, 0.9)
      set_progress(section.id, page_1.published_resource.resource_id, user_2.id, 0.6)
      set_progress(section.id, page_1.published_resource.resource_id, user_3.id, 0)
      set_progress(section.id, page_1.published_resource.resource_id, user_4.id, 0.3)
      set_progress(section.id, page_1.published_resource.resource_id, user_5.id, 0.7)

      # Starts in page 2
      {:ok, view, _html} =
        live(
          conn,
          live_view_students_route(section.slug, %{
            limit: 2,
            offset: 2
          })
        )

      [student_for_tr_3, student_for_tr_4] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      # Page 1
      assert student_for_tr_3 =~ "Messi, Lionel"
      assert student_for_tr_4 =~ "Suarez, Luis"

      # Change page size from 2 to 1
      view
      |> element("#footer_paging_page_size_form")
      |> render_change(%{limit: "1"})

      [student_for_tr_3] =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find(~s{.instructor_dashboard_table tr a})
        |> Enum.map(fn a_tag -> Floki.text(a_tag) end)

      # Page 3. It keeps showing the same element.
      assert student_for_tr_3 =~ "Messi, Lionel"
    end
  end

  describe "instructor - invitations" do
    setup [:setup_enrollments_view]

    test "can invite new users to the section", %{section: section, conn: conn} do
      students_url = live_view_students_route(section.slug)
      {:ok, view, _html} = live(conn, students_url)

      user_1 = insert(:user)
      user_2 = insert(:user)
      non_existant_email_1 = "non_existant_user_1@test.com"
      non_existant_email_2 = "non_existant_user_2@test.com"

      assert [] ==
               [user_1.email, user_2.email, non_existant_email_1, non_existant_email_2]
               |> get_emails_of_users_enrolled_in_section(section.slug)

      # Open "Add enrollments modal"
      view
      |> with_target("#students_table_add_enrollments_modal")
      |> render_click("open")

      assert has_element?(view, "h5", "Add enrollments")
      assert has_element?(view, "input[placeholder=\"user@email.com\"]")

      # Add emails to the list
      view
      |> with_target("#students_table")
      |> render_hook("add_enrollments_update_list", %{
        value: [user_1.email, user_2.email, non_existant_email_1, non_existant_email_2]
      })

      assert has_element?(view, "p", user_1.email)
      assert has_element?(view, "p", user_2.email)
      assert has_element?(view, "p", non_existant_email_1)
      assert has_element?(view, "p", non_existant_email_2)

      # Go to second step
      view
      |> with_target("#students_table")
      |> render_hook("add_enrollments_go_to_step_2")

      assert has_element?(view, "p", "The following emails don't exist in the database")

      assert has_element?(
               view,
               "#students_table_add_enrollments_modal li ul p",
               non_existant_email_1
             )

      assert has_element?(
               view,
               "#students_table_add_enrollments_modal li ul p",
               non_existant_email_2
             )

      refute has_element?(view, "#students_table_add_enrollments_modal li ul p", user_1.email)
      refute has_element?(view, "#students_table_add_enrollments_modal li ul p", user_2.email)

      # Remove an email from the "Users not found" list
      view
      |> with_target("#students_table")
      |> render_hook("add_enrollments_remove_from_list", %{email: non_existant_email_2})

      refute has_element?(
               view,
               "#students_table_add_enrollments_modal li ul p",
               non_existant_email_2
             )

      view
      |> with_target("#students_table")
      |> render_hook("add_enrollments_go_to_step_3")

      assert has_element?(view, "p", "You're signed with two accounts.")
      assert has_element?(view, "p", "Please select the one to use as an inviter:")

      # when logged in under two accounts, "author" selected by default
      assert view |> element("fieldset input#author") |> render() =~ "checked=\"checked\""
      refute view |> element("fieldset input#user") |> render() =~ "checked=\"checked\""

      # can change to "user" account
      view |> element("fieldset input#user") |> render_click()
      refute view |> element("fieldset input#author") |> render() =~ "checked=\"checked\""
      assert view |> element("fieldset input#user") |> render() =~ "checked=\"checked\""

      # Send the invitations (this mocks the POST request made by the form)
      conn =
        post(
          conn,
          Routes.invite_path(conn, :create_bulk, section.slug,
            emails: [user_1.email, user_2.email, non_existant_email_1],
            role: "instructor",
            "g-recaptcha-response": "any",
            inviter: "user"
          )
        )

      emails_sent = [user_1.email, user_2.email, non_existant_email_1] |> Enum.sort()
      assert emails_sent == get_emails_of_users_enrolled_in_section(emails_sent, section.slug)

      assert redirected_to(conn) == students_url

      new_users =
        Oli.Accounts.User
        |> where([u], u.email in [^user_1.email, ^user_2.email, ^non_existant_email_1])
        |> select([u], {u.email, u.invitation_token})
        |> Repo.all()
        |> Enum.into(%{})

      assert length(Map.keys(new_users)) == 3
      assert Map.get(new_users, user_1.email) == nil
      assert Map.get(new_users, user_2.email) == nil
      assert Map.get(new_users, non_existant_email_1) != nil
    end

    test "can't invite new users to the section if section is not open and free", %{conn: conn} do
      section = insert(:section)

      {:ok, _view, html} = live(conn, live_view_students_route(section.slug))

      refute html =~ "Add Enrollments"
    end
  end

  defp get_emails_of_users_enrolled_in_section(emails, section_slug) when is_list(emails) do
    from(s in Oli.Delivery.Sections.Section,
      join: e in assoc(s, :enrollments),
      join: u in assoc(e, :user),
      where: s.slug == ^section_slug and u.email in ^emails,
      select: u.email
    )
    |> Repo.all()
    |> Enum.sort()
  end

  defp set_progress(section_id, resource_id, user_id, progress) do
    Core.track_access(resource_id, section_id, user_id)
    |> Core.update_resource_access(%{progress: progress})
  end

  defp set_interaction(section, resource, user, timestamp) do
    insert(:resource_access, %{
      section: section,
      resource: resource,
      user: user,
      inserted_at: timestamp,
      updated_at: timestamp
    })
  end

  defp setup_enrollments_view(%{conn: conn}) do
    map = Seeder.base_project_with_resource2()

    section = make(map.project, map.institution, "a", %{open_and_free: true})

    enroll(section)

    admin =
      author_fixture(%{
        system_role_id: Oli.Accounts.SystemRole.role_id().system_admin,
        preferences:
          %Oli.Accounts.AuthorPreferences{show_relative_dates: false} |> Map.from_struct()
      })

    user = user_fixture()

    conn =
      Plug.Test.init_test_session(conn, [])
      |> log_in_author(admin)
      |> log_in_user(user)

    map
    |> Map.merge(%{
      conn: conn,
      section: section,
      admin: admin
    })
  end

  def enroll(section) do
    to_attrs = fn v ->
      %{
        sub: UUID.uuid4(),
        name: "#{v}",
        given_name: "#{v}",
        family_name: "#{v}",
        middle_name: "",
        picture: "https://platform.example.edu/jane.jpg",
        email: "test#{v}@example.edu",
        locale: "en-US"
      }
    end

    Enum.map(1..11, fn v -> to_attrs.(v) |> user_fixture() end)
    |> Enum.with_index(fn user, index ->
      roles =
        case rem(index, 2) do
          0 ->
            [ContextRoles.get_role(:context_learner)]

          _ ->
            [ContextRoles.get_role(:context_learner), ContextRoles.get_role(:context_instructor)]
        end

      {:ok, enrollment} = Sections.enroll(user.id, section.id, roles)

      # Have the first enrolled student also have made a payment for this section
      case index do
        2 ->
          Oli.Delivery.Paywall.create_payment(%{
            type: :direct,
            generation_date: DateTime.utc_now(),
            application_date: DateTime.utc_now(),
            amount: "$100.00",
            provider_type: :stripe,
            provider_id: "1",
            provider_payload: %{},
            pending_user_id: user.id,
            pending_section_id: section.id,
            enrollment_id: enrollment.id,
            section_id: section.id
          })

        _ ->
          true
      end
    end)
  end
end

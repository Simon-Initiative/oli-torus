defmodule OliWeb.Sections.EnrollmentsViewTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Ecto.Query
  import Phoenix.{ConnTest, LiveViewTest}

  alias Oli.Seeder
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Repo

  @endpoint OliWeb.Endpoint

  # Create and enroll 11 users, with 6 being students and 5 being instructors
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

  describe "gating and scheduling live test admin" do
    setup [:setup_enrollments_view]

    test "mount enrollments for admin", %{section: section, conn: conn} do
      {:ok, _view, html} =
        live(conn, Routes.live_path(@endpoint, OliWeb.Sections.EnrollmentsViewLive, section.slug))

      [e | _] =
        Oli.Delivery.Sections.list_enrollments(section.slug)
        |> Enum.sort_by(fn e ->
          OliWeb.Common.Utils.name(e.user.name, e.user.given_name, e.user.family_name)
        end)

      assert html =~ "Admin"
      assert html =~ "Enrollments"
      assert html =~ "Download as .CSV"
      assert html =~ "Add Enrollments"
      assert html =~ OliWeb.Common.Utils.name(e.user.name, e.user.given_name, e.user.family_name)
    end
  end

  describe "breadcrumbs" do
    test "mount enrollments for instructor", %{conn: conn} do
      section = insert(:section, %{type: :enrollable})
      user = insert(:user)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])

      conn =
        Plug.Test.init_test_session(conn, lti_session: nil, section_slug: section.slug)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      {:ok, _view, html} =
        live(conn, Routes.live_path(@endpoint, OliWeb.Sections.EnrollmentsViewLive, section.slug))

      refute html =~ "Admin"
      assert html =~ "Enrollments"
    end
  end

  describe "admin - invitations" do
    setup [:setup_enrollments_view]

    test "can invite new users to the section", %{section: section, conn: conn} do
      enrollments_url =
        Routes.live_path(@endpoint, OliWeb.Sections.EnrollmentsViewLive, section.slug)

      {:ok, view, _html} = live(conn, enrollments_url)

      user_1 = insert(:user)
      user_2 = insert(:user)
      non_existant_email_1 = "non_existant_user_1@test.com"
      non_existant_email_2 = "non_existant_user_2@test.com"

      # Open "Add enrollments modal"
      view
      |> with_target("#enrollments_view_add_enrollments_modal")
      |> render_click("open")

      assert has_element?(view, "h5", "Add enrollments")
      assert has_element?(view, "input[placeholder=\"user@email.com\"]")

      # Add emails to the list
      view
      |> with_target("#enrollments_view")
      |> render_hook("add_enrollments_update_list", %{
        value: [user_1.email, user_2.email, non_existant_email_1, non_existant_email_2]
      })

      assert has_element?(view, "p", user_1.email)
      assert has_element?(view, "p", user_2.email)
      assert has_element?(view, "p", non_existant_email_1)
      assert has_element?(view, "p", non_existant_email_2)

      # Go to second step
      view
      |> with_target("#enrollments_view")
      |> render_hook("add_enrollments_go_to_step_2")

      assert has_element?(view, "p", "The following emails don't exist in the database")

      assert has_element?(
               view,
               "#enrollments_view_add_enrollments_modal li ul p",
               non_existant_email_1
             )

      assert has_element?(
               view,
               "#enrollments_view_add_enrollments_modal li ul p",
               non_existant_email_2
             )

      refute has_element?(view, "#enrollments_view_add_enrollments_modal li ul p", user_1.email)
      refute has_element?(view, "#enrollments_view_add_enrollments_modal li ul p", user_2.email)

      # Remove an email from the "Users not found" list
      view
      |> with_target("#enrollments_view")
      |> render_hook("add_enrollments_remove_from_list", %{user: non_existant_email_2})

      refute has_element?(
               view,
               "#enrollments_view_add_enrollments_modal li ul p",
               non_existant_email_2
             )

      view
      |> with_target("#enrollments_view")
      |> render_hook("add_enrollments_go_to_step_3")

      assert has_element?(view, "p", "Are you sure you want to enroll 3 users?")

      # Send the invitations (this mocks the POST request made by the form)
      conn =
        post(
          conn,
          Routes.invite_path(conn, :create_bulk, section.slug,
            emails: [user_1.email, user_2.email, non_existant_email_1],
            role: "instructor",
            "g-recaptcha-response": "any"
          )
        )

      assert redirected_to(conn, 302) =~ enrollments_url

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

    test "can' invite new users to the section if section is not open and free", %{conn: conn} do
      section = insert(:section)

      enrollments_url =
        Routes.live_path(@endpoint, OliWeb.Sections.EnrollmentsViewLive, section.slug)

      {:ok, _view, html} = live(conn, enrollments_url)

      refute html =~ "Add Enrollments"
    end
  end

  defp setup_enrollments_view(%{conn: conn}) do
    map = Seeder.base_project_with_resource2()

    section = make(map.project, map.institution, "a", %{open_and_free: true})

    enroll(section)

    admin =
      author_fixture(%{
        system_role_id: Oli.Accounts.SystemRole.role_id().admin,
        preferences:
          %Oli.Accounts.AuthorPreferences{show_relative_dates: false} |> Map.from_struct()
      })

    conn =
      Plug.Test.init_test_session(conn, [])
      |> Pow.Plug.assign_current_user(admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    map
    |> Map.merge(%{
      conn: conn,
      section: section,
      admin: admin
    })
  end
end

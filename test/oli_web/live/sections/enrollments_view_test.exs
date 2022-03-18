defmodule OliWeb.Sections.EnrollmentsViewTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.{ConnTest, LiveViewTest}

  alias Oli.Seeder
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

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

      # Between the first two enrollments, delay enough that we get distinctly different
      # enrollment times
      case index do
        1 -> :timer.sleep(1500)
        _ -> true
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

    test "mount enrollments for admin", %{conn: conn, section: section} do
      {:ok, _view, html} =
        live(conn, Routes.live_path(@endpoint, OliWeb.Sections.EnrollmentsView, section.slug))

      assert html =~ "Admin"
      assert html =~ "Enrollments"
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
        live(conn, Routes.live_path(@endpoint, OliWeb.Sections.EnrollmentsView, section.slug))

      refute html =~ "Admin"
      assert html =~ "Enrollments"
    end
  end

  defp setup_enrollments_view(%{conn: conn}) do
    map = Seeder.base_project_with_resource2()

    section = make(map.project, map.institution, "a", %{})

    enroll(section)

    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().admin})

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

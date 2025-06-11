defmodule OliWeb.Sections.EditLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Lti_1p3.Roles.ContextRoles

  defp live_view_edit_route(section_slug) do
    ~p"/sections/#{section_slug}/edit"
  end

  defp live_view_edit_section_route(section_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, section_slug)
  end

  defp create_section(_conn) do
    section = insert(:section)

    [section: section]
  end

  describe "user cannot access when is not logged in" do
    setup [:create_section]

    test "redirects to new session when accessing the section edit view", %{
      conn: conn,
      section: section
    } do
      redirect_path =
        "/users/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_edit_route(section.slug))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :create_section]

    test "redirects to new session when accessing the section edit view", %{
      conn: conn,
      section: section
    } do
      conn = get(conn, live_view_edit_route(section.slug))

      redirect_path = "/users/log_in"
      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "user cannot access when is logged in as an instructor but is not enrolled in the section" do
    setup [:user_conn]

    test "redirects to new session when accessing the section edit view", %{
      conn: conn
    } do
      section = insert(:section, %{type: :enrollable})

      conn = get(conn, live_view_edit_route(section.slug))

      redirect_path = "/unauthorized"
      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "user cannot access when is logged in as a student and is enrolled in the section" do
    setup [:user_conn]

    test "redirects to new session when accessing the section edit view", %{
      conn: conn,
      user: user
    } do
      section = insert(:section, %{type: :enrollable})
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, live_view_edit_route(section.slug))

      redirect_path = "/unauthorized"
      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "user can access when is logged in as an instructor and is enrolled in the section" do
    setup [:user_conn]

    test "loads correctly", %{
      conn: conn,
      user: user
    } do
      section = insert(:section, %{type: :enrollable})
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, _view, html} = live(conn, live_view_edit_route(section.slug))

      refute html =~ "Admin"
      assert html =~ "Edit Section Details"
      assert html =~ "Settings"
    end
  end

  describe "instructor cannot modify payment data" do
    setup [:instructor_conn]

    test "when working on the edit form - LTI case", %{conn: conn, instructor: instructor} do
      section = insert(:section, requires_payment: true, type: :enrollable)
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_edit_route(section.slug))

      assert section.requires_payment == true

      assert has_element?(view, "#section_requires_payment[checked=\"checked\"]")

      view
      |> element("form[phx-change=\"validate\"")
      |> render_change(section: %{title: "New title"})

      # Validate event shouldn't change section_requires_payment
      assert has_element?(view, "#section_requires_payment[checked=\"checked\"]")

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(section: %{title: "New title"})

      # Save event shouldn't change section_requires_payment
      assert has_element?(view, "#section_requires_payment[checked=\"checked\"]")
      assert Oli.Repo.get(Section, section.id).requires_payment == true
    end

    test "when working on the edit form - Open and Free case", %{
      conn: conn,
      instructor: instructor
    } do
      section =
        insert(:section,
          requires_payment: true,
          type: :enrollable,
          open_and_free: true,
          requires_payment: false,
          has_grace_period: true
        )

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_edit_route(section.slug))

      assert Oli.Repo.get(Section, section.id).has_grace_period == true
      assert has_element?(view, "#section_has_grace_period[checked=\"checked\"]")

      # Handle event "validate" shouldn't change has_grace_period
      view
      |> element("form[phx-change=\"validate\"")
      |> render_change(section: %{title: "New title"})

      assert has_element?(view, "#section_has_grace_period[checked=\"checked\"]")

      # Handle event "save" shouldn't change has_grace_period
      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(section: %{title: "New title"})

      assert has_element?(view, "#section_has_grace_period[checked=\"checked\"]")
      assert Oli.Repo.get(Section, section.id).has_grace_period == true
    end
  end

  describe "admin can modify payment data" do
    setup [:admin_conn]

    test "when working on the edit form", %{conn: conn} do
      section = insert(:section, requires_payment: true, type: :enrollable)

      {:ok, view, _html} = live(conn, live_view_edit_route(section.slug))

      assert section.requires_payment == true

      assert has_element?(view, "#section_requires_payment[checked=\"checked\"]")

      view
      |> element("form[phx-change=\"validate\"")
      |> render_change(section: %{requires_payment: "false"})

      refute has_element?(view, "#section_requires_payment[checked=\"checked\"]")

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(section: %{requires_payment: "false"})

      refute has_element?(view, "#section_requires_payment[checked=\"checked\"]")
      assert Oli.Repo.get(Section, section.id).requires_payment == false
    end
  end

  describe "edit live view" do
    setup [:admin_conn, :create_section]

    test "returns 404 when section not exists", %{conn: conn} do
      conn = get(conn, live_view_edit_route("not_exists"))

      assert response(conn, 404)
    end

    test "loads section data correctly", %{conn: conn} do
      section = insert(:section, requires_payment: true)

      {:ok, view, html} = live(conn, live_view_edit_route(section.slug))

      assert html =~ "Edit Section Details"
      assert html =~ "Payment Settings"
      assert has_element?(view, "input[name=\"section[pay_by_institution]\"]")
    end

    test "loads open and free section data correctly", %{conn: conn} do
      welcome_title = %{
        type: "p",
        children: [
          %{
            id: "2748906063",
            type: "p",
            children: [%{text: "Welcome Title"}]
          }
        ]
      }

      section =
        insert(:section,
          open_and_free: true,
          welcome_title: welcome_title,
          encouraging_subtitle: "Encouraging subtitle"
        )

      {:ok, view, html} = live(conn, live_view_edit_route(section.slug))

      assert html =~ "Edit Section Details"
      assert html =~ "Settings"
      assert html =~ "Manage the course section settings"
      assert html =~ "Direct Delivery"
      assert html =~ "Direct Delivery section settings"
      assert has_element?(view, "input[value=\"#{section.title}\"]")
      assert has_element?(view, "input[value=\"#{section.description}\"]")
      assert has_element?(view, "input[value=\"#{section.encouraging_subtitle}\"]")

      # Loads the welcome title
      view
      |> render()
      |> Floki.parse_fragment!()
      |> Floki.find(~s{div[data-live-react-class="Components.RichTextEditor"]})
      |> Floki.attribute("data-live-react-props")
      |> hd() =~ "Welcome Title"

      assert view
             |> element(
               "select[id=section_brand_id] option[selected=selected][value=#{section.brand_id}]"
             )
             |> has_element?()

      assert view
             |> element(
               "select[id=section_institution_id] option[selected=selected][value=#{section.institution_id}]"
             )
             |> has_element?()
    end

    test "institution dropdown is disabled for LTI sections", %{conn: conn} do
      section = insert(:section)

      {:ok, view, _html} = live(conn, live_view_edit_route(section.slug))

      assert view
             |> element("select[id=section_institution_id][disabled=disabled]")
             |> has_element?()
    end

    test "institution dropdown is enabled for non LTI sections", %{conn: conn} do
      section = insert(:section, lti_1p3_deployment: nil)

      {:ok, view, _html} = live(conn, live_view_edit_route(section.slug))

      refute view
             |> element("select[id=section_institution_id][disabled=disabled]")
             |> has_element?()

      assert view
             |> element("select[id=section_institution_id]")
             |> has_element?()
    end

    test "loads open and free section datetimes correctly using the local timezone", context do
      {:ok, conn: conn, ctx: _} = set_timezone(context)
      timezone = Plug.Conn.get_session(conn, :browser_timezone)

      section = insert(:section_with_dates, open_and_free: true)

      {:ok, view, _html} = live(conn, live_view_edit_route(section.slug))

      assert view
             |> element("#section_start_date")
             |> render() =~
               utc_datetime_to_localized_datestring(section.start_date, timezone)

      assert view
             |> element("#section_end_date")
             |> render() =~
               utc_datetime_to_localized_datestring(section.end_date, timezone)

      assert view
             |> element("small")
             |> render() =~ "Timezone: " <> timezone
    end

    test "loads section data correctly when is created with a brand", %{conn: conn} do
      brand = insert(:brand)
      section = insert(:section, %{brand: brand})

      {:ok, view, _html} = live(conn, live_view_edit_route(section.slug))

      assert render(view) =~ "Settings"

      assert view
             |> element("option[selected=\"selected\"][value=\"#{section.brand_id}\"]")
             |> render() =~
               "#{brand.name}"
    end

    test "save event updates curriculum numbering visibility", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, live_view_edit_route(section.slug))
      assert section.display_curriculum_item_numbering

      assert view
             |> element("#section_display_curriculum_item_numbering")
             |> render() =~ "checked"

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{
        "section" => %{"display_curriculum_item_numbering" => "false"}
      })

      updated_section = Sections.get_section!(section.id)
      refute updated_section.display_curriculum_item_numbering

      refute view
             |> element("#section_display_curriculum_item_numbering")
             |> render() =~ "checked"
    end

    test "update section with a long title shows an error alert", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, live_view_edit_section_route(section.slug))

      long_title =
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum"

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{section: %{title: long_title}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Couldn&#39;t update product title"

      assert view
             |> element("#section_title")
             |> render() =~ long_title

      assert has_element?(view, "span", "Title should be at most 255 character(s)")

      updated_section = Sections.get_section!(section.id)
      refute updated_section.title == long_title
    end

    test "update section with a valid title shows an info alert", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, live_view_edit_section_route(section.slug))

      valid_title = "Valid title"

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{section: %{title: valid_title}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Product changes saved"

      assert view
             |> element("#section_title")
             |> render() =~ valid_title

      updated_section = Sections.get_section!(section.id)
      assert updated_section.title == valid_title
    end

    test "update section with a valid welcome title shows an info alert", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_edit_section_route(section.slug))

      welcome_title = %{
        "type" => "p",
        "children" => [
          %{
            "id" => "2748906063",
            "type" => "p",
            "children" => [%{"text" => "Welcome Title"}]
          }
        ]
      }

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{section: %{welcome_title: Poison.encode!(welcome_title)}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Product changes saved"

      view
      |> render()
      |> Floki.parse_fragment!()
      |> Floki.find(~s{div[data-live-react-class="Components.RichTextEditor"]})
      |> Floki.attribute("data-live-react-props")
      |> hd() =~ "Welcome Title"

      updated_section = Sections.get_section!(section.id)
      assert updated_section.welcome_title == welcome_title
    end

    test "update section with a valid encouraging subtitle shows an info alert", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_edit_section_route(section.slug))

      valid_subtitle = "Valid subtitle"

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{section: %{encouraging_subtitle: valid_subtitle}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Product changes saved"

      assert view
             |> element("#section_encouraging_subtitle")
             |> render() =~ valid_subtitle

      updated_section = Sections.get_section!(section.id)
      assert updated_section.encouraging_subtitle == valid_subtitle
    end

    test "update section with an invalid start/end date shows an error", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_edit_route(section.slug))

      today = DateTime.utc_now()
      yesterday = DateTime.add(today, -1, :day)

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{section: %{start_date: today, end_date: yesterday}})

      assert has_element?(view, "p", "must be before the end date")
      assert has_element?(view, "p", "must be after the start date")
    end

    test "section's preferred_scheduling_time is viewable and editable", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_edit_route(section.slug))

      # the initial value corresponds to the default value.
      assert view
             |> element("#section_preferred_scheduling_time")
             |> render() =~ "23:59:59"

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{section: %{preferred_scheduling_time: ~T[20:00:00]}})

      updated_section = Sections.get_section!(section.id)
      assert updated_section.preferred_scheduling_time == ~T[20:00:00]
    end
  end
end

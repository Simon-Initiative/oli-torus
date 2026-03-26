defmodule OliWeb.Components.Delivery.Students.EmailButtonTest do
  use OliWeb.ConnCase, async: true
  import LiveComponentTests
  require Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.Students.EmailButton

  describe "EmailButton component" do
    test "renders full variant by default with dropdown options", %{conn: conn} do
      attrs = %{
        selected_students: [1],
        selected_emails: "student1@test.com",
        students: [
          %{id: 1, email: "student1@test.com", name: "Student 1"}
        ],
        section_title: "Test Course",
        instructor_email: "instructor@test.com",
        section_slug: "test-section"
      }

      {:ok, _lcd, html} = live_component_isolated(conn, EmailButton, attrs)

      assert html =~ "Email"
      assert html =~ "Copy email addresses"
      assert html =~ "Send email"
    end

    test "renders disabled when no students selected", %{conn: conn} do
      attrs = %{
        selected_students: [],
        selected_emails: "",
        students: [],
        section_title: "Test Course",
        instructor_email: "instructor@test.com",
        section_slug: "test-section"
      }

      {:ok, _lcd, html} = live_component_isolated(conn, EmailButton, attrs)

      assert html =~ "Email"
      assert html =~ "cursor-not-allowed"
      assert html =~ "disabled"
    end

    test "renders minimal variant as direct modal action", %{conn: conn} do
      attrs = %{
        variant: :minimal,
        selected_students: [1],
        selected_emails: "student1@test.com",
        students: [
          %{id: 1, email: "student1@test.com", name: "Student 1"}
        ],
        section_title: "Test Course",
        instructor_email: "instructor@test.com",
        section_slug: "test-section"
      }

      {:ok, _lcd, html} = live_component_isolated(conn, EmailButton, attrs)

      assert html =~ "Email Selected"
      assert html =~ "show_email_modal"
      refute html =~ "Copy email addresses"
      refute html =~ "Send email"
      refute html =~ "chevron_down"
    end
  end
end

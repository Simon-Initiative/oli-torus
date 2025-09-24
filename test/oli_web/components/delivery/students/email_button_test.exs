defmodule OliWeb.Components.Delivery.Students.EmailButtonTest do
  use OliWeb.ConnCase, async: true
  import LiveComponentTests
  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.Students.EmailButton

  describe "EmailButton component" do
    test "renders disabled when no students selected", %{conn: conn} do
      attrs = %{
        selected_students: [],
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

    test "renders enabled when students are selected", %{conn: conn} do
      attrs = %{
        selected_students: [1, 2],
        students: [
          %{id: 1, email: "student1@test.com", name: "Student 1"},
          %{id: 2, email: "student2@test.com", name: "Student 2"}
        ],
        section_title: "Test Course",
        instructor_email: "instructor@test.com",
        section_slug: "test-section"
      }

      {:ok, _lcd, html} = live_component_isolated(conn, EmailButton, attrs)

      assert html =~ "Email"
      refute html =~ "cursor-not-allowed"
      refute html =~ "disabled"
    end

    test "shows dropdown options when clicked", %{conn: conn} do
      attrs = %{
        selected_students: [1],
        students: [
          %{id: 1, email: "student1@test.com", name: "Student 1"}
        ],
        section_title: "Test Course",
        instructor_email: "instructor@test.com",
        section_slug: "test-section"
      }

      {:ok, _lcd, html} = live_component_isolated(conn, EmailButton, attrs)

      assert html =~ "Copy email addresses"
      assert html =~ "Send email"
    end
  end
end

defmodule OliWeb.Components.Delivery.Students.EmailModalTest do
  use OliWeb.ConnCase, async: true

  import LiveComponentTests
  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.Students.EmailModal

  describe "EmailModal component - Initial Render" do
    test "renders modal with correct title and structure when show_modal is true", %{conn: conn} do
      students = [
        %{id: 1, full_name: "Smith, John", email: "john@test.com"},
        %{id: 2, full_name: "Doe, Jane", email: "jane@test.com"}
      ]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1, 2],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      assert has_element?(view, "#email_modal_wrapper")
      assert has_element?(view, "#email_modal")
      assert render(view) =~ "Email Students"
    end

    test "renders with show_modal false", %{conn: conn} do
      students = [%{id: 1, full_name: "Smith, John", email: "john@test.com"}]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: false,
          email_handler_id: "test-handler"
        })

      # Modal wrapper should exist but modal should not be shown
      assert has_element?(view, "#email_modal_wrapper")
    end

    test "initializes with empty email message", %{conn: conn} do
      students = [%{id: 1, full_name: "Smith, John", email: "john@test.com"}]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      textarea_html = render(view) |> Floki.parse_document!() |> Floki.find("#email_message")
      assert Floki.text(textarea_html) == ""
    end
  end

  describe "EmailModal component - Recipient Message Display" do
    test "displays correct message for single student with email", %{conn: conn} do
      students = [%{id: 1, full_name: "Smith, John", email: "john@test.com"}]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      html = render(view)
      assert html =~ "This email will send to"
      assert html =~ "Smith, John"
      assert html =~ "john@test.com"
    end

    test "displays warning message for single student without email", %{conn: conn} do
      students = [%{id: 1, full_name: "Smith, John", email: nil}]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      html = render(view)
      assert html =~ "Email cannot be sent because the student does not have an email address"
      assert html =~ "text-Text-text-danger"
    end

    test "displays correct message for multiple students with emails", %{conn: conn} do
      students = [
        %{id: 1, full_name: "Smith, John", email: "john@test.com"},
        %{id: 2, full_name: "Doe, Jane", email: "jane@test.com"},
        %{id: 3, full_name: "Brown, Charlie", email: "charlie@test.com"}
      ]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1, 2, 3],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      html = render(view)
      assert html =~ "This email will send separately to"
      assert html =~ "3 students"
      refute html =~ "do not have an associated email"
    end

    test "displays correct message for multiple students with some missing emails", %{
      conn: conn
    } do
      students = [
        %{id: 1, full_name: "Smith, John", email: "john@test.com"},
        %{id: 2, full_name: "Doe, Jane", email: nil},
        %{id: 3, full_name: "Brown, Charlie", email: "charlie@test.com"}
      ]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1, 2, 3],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      html = render(view)
      assert html =~ "This email will send separately to"
      assert html =~ "2 students"
      assert html =~ "1 of the selected students do not have an associated email"
    end
  end

  describe "EmailModal component - Email Templates" do
    test "renders both email templates", %{conn: conn} do
      students = [%{id: 1, full_name: "Smith, John", email: "john@test.com"}]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      html = render(view)
      assert html =~ "LOW STUDENT PROGRESS"
      assert html =~ "APPROACHING DUE DATE"
      assert html =~ "Your progress on [course material] appears to be below expected levels"
      assert html =~ "This is a reminder that [course material] is due soon"
    end

    test "template buttons have correct copy text data attributes", %{conn: conn} do
      students = [%{id: 1, full_name: "Smith, John", email: "john@test.com"}]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      html = render(view)
      assert html =~ "email_modal_below_expected_button"
      assert html =~ "email_modal_due_soon_button"
      assert html =~ "phx-hook=\"CopyToClipboard\""
    end

    test "clicking low_progress template copies template to email message", %{conn: conn} do
      students = [%{id: 1, full_name: "Smith, John", email: "john@test.com"}]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      view
      |> element("#email_modal_below_expected_button")
      |> render_click()

      html = render(view)
      assert html =~ "Your progress on [course material] appears to be below expected levels"
      assert html =~ "[Instructor Name]"
    end

    test "clicking approaching_due_date template copies template to email message", %{
      conn: conn
    } do
      students = [%{id: 1, full_name: "Smith, John", email: "john@test.com"}]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      view
      |> element("#email_modal_due_soon_button")
      |> render_click()

      html = render(view)
      assert html =~ "This is a reminder that [course material] is due soon"
      assert html =~ "[Instructor Name]"
    end
  end

  describe "EmailModal component - Message Input" do
    test "textarea accepts user input via update_message event", %{conn: conn} do
      students = [%{id: 1, full_name: "Smith, John", email: "john@test.com"}]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      # Simulate typing in the textarea
      view
      |> element("#email_message")
      |> render_blur(%{"value" => "This is a test message"})

      html = render(view)
      assert html =~ "This is a test message"
    end

    test "textarea updates on keyup events", %{conn: conn} do
      students = [%{id: 1, full_name: "Smith, John", email: "john@test.com"}]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      view
      |> element("#email_message")
      |> render_keyup(%{"value" => "Typing updates state"})

      html = render(view)
      assert html =~ "Typing updates state"
    end

    test "send button is disabled when email message is empty", %{conn: conn} do
      students = [%{id: 1, full_name: "Smith, John", email: "john@test.com"}]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      send_button_html =
        view
        |> element("button[role='send email']")
        |> render()

      assert send_button_html =~ "disabled"
      assert send_button_html =~ "cursor-not-allowed"
      assert send_button_html =~ "bg-Fill-Buttons-fill-muted"
    end

    test "send button is enabled when email message has content", %{conn: conn} do
      students = [%{id: 1, full_name: "Smith, John", email: "john@test.com"}]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      # Add content to the email message
      view
      |> element("#email_message")
      |> render_blur(%{"value" => "Test message"})

      send_button_html =
        view
        |> element("button[role='send email']")
        |> render()

      refute send_button_html =~ "disabled"
      assert send_button_html =~ "bg-Fill-Buttons-fill-primary"
      refute send_button_html =~ "cursor-not-allowed"
    end

    test "send button enables on keyup when message has content", %{conn: conn} do
      students = [%{id: 1, full_name: "Smith, John", email: "john@test.com"}]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      view
      |> element("#email_message")
      |> render_keyup(%{"value" => "Test message"})

      send_button_html =
        view
        |> element("button[role='send email']")
        |> render()

      refute send_button_html =~ "disabled"
      assert send_button_html =~ "bg-Fill-Buttons-fill-primary"
      refute send_button_html =~ "cursor-not-allowed"
    end

    test "send button remains disabled when email message is only whitespace", %{conn: conn} do
      students = [%{id: 1, full_name: "Smith, John", email: "john@test.com"}]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      # Add only whitespace to the email message
      view
      |> element("#email_message")
      |> render_blur(%{"value" => "   \n   "})

      send_button_html =
        view
        |> element("button[role='send email']")
        |> render()

      assert send_button_html =~ "disabled"
      assert send_button_html =~ "cursor-not-allowed"
    end
  end

  describe "EmailModal component - Cancel Button" do
    test "cancel button triggers close_email_modal event", %{conn: conn} do
      students = [%{id: 1, full_name: "Smith, John", email: "john@test.com"}]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      cancel_button_html =
        view
        |> element("button[role='cancel']")
        |> render()

      assert cancel_button_html =~ "phx-click"
      assert cancel_button_html =~ "close_email_modal"
      assert cancel_button_html =~ "Cancel"
    end
  end

  describe "EmailModal component - Edge Cases" do
    test "handles empty selected_students list", %{conn: conn} do
      students = [%{id: 1, full_name: "Smith, John", email: "john@test.com"}]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      # Should render without crashing
      assert has_element?(view, "#email_modal")
    end

    test "handles all students without emails", %{conn: conn} do
      students = [
        %{id: 1, full_name: "Smith, John", email: nil},
        %{id: 2, full_name: "Doe, Jane", email: nil}
      ]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1, 2],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      html = render(view)
      assert html =~ "This email will send separately to"
      assert html =~ "0 students"
      assert html =~ "2 of the selected students do not have an associated email"
    end

    test "handles students list with missing id in selected_students", %{conn: conn} do
      students = [%{id: 1, full_name: "Smith, John", email: "john@test.com"}]

      {:ok, view, _html} =
        live_component_isolated(conn, EmailModal, %{
          id: "test-email-modal",
          selected_students: [1, 999],
          students: students,
          section_title: "Test Course",
          instructor_email: "instructor@test.com",
          show_modal: true,
          email_handler_id: "test-handler"
        })

      # Should handle gracefully - only existing student should be counted
      html = render(view)
      assert html =~ "This email will send separately to"
      assert html =~ "1 students"
    end
  end
end

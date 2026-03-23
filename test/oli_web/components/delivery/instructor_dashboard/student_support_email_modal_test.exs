defmodule OliWeb.Components.Delivery.InstructorDashboard.StudentSupportEmailModalTest do
  use OliWeb.ConnCase, async: false
  use Oban.Testing, repo: Oli.Repo

  import LiveComponentTests
  import Phoenix.LiveViewTest

  alias Oli.Mailer.SendEmailWorker
  alias Oli.Repo

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.StudentSupportEmailModal

  setup do
    Repo.delete_all(Oban.Job)
    :ok
  end

  describe "StudentSupportEmailModal" do
    test "renders recipient chips and temporary bucket-based default subject", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentSupportEmailModal, base_attrs(%{show_modal: true}))

      html = render(view)

      assert html =~ "Draft Email"
      assert html =~ "student1@example.edu"
      assert html =~ "student2@example.edu"
      assert html =~ "Checking in about your course progress"
      assert html =~ "Cancel"
    end

    test "removing the last recipient disables send", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          StudentSupportEmailModal,
          base_attrs(%{
            show_modal: true,
            students: [%{id: 1, display_name: "Student 1", email: "student1@example.edu"}]
          })
        )

      view
      |> element(~s{button[aria-label="Recipient: student1@example.edu, remove"]})
      |> render_click()

      send_button_html =
        view
        |> element("button[role='send email']")
        |> render()

      assert send_button_html =~ "disabled"
      assert send_button_html =~ "cursor-not-allowed"
    end

    test "sending uses the latest subject and body and excludes removed recipients", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentSupportEmailModal, base_attrs(%{show_modal: true}))

      view
      |> element(~s{button[aria-label="Recipient: student1@example.edu, remove"]})
      |> render_click()

      view
      |> element("#student_support_email_subject")
      |> render_blur(%{"value" => "Custom outreach subject"})

      view
      |> element("#student_support_email_body")
      |> render_blur(%{"value" => "Custom outreach body"})

      view
      |> element("button[role='send email']")
      |> render_click()

      [job] = Repo.all(Oban.Job)
      email = SendEmailWorker.deserialize_email(job.args["email"])

      assert email.subject == "Custom outreach subject"
      assert email.text_body == "Custom outreach body"
      assert email.to == [{"", "student2@example.edu"}]
      assert email.reply_to == {"Instructor Example", "instructor@example.edu"}
    end
  end

  defp base_attrs(overrides) do
    Map.merge(
      %{
        id: "student_support_email_modal_test",
        students: [
          %{id: 1, display_name: "Student 1", email: "student1@example.edu"},
          %{id: 2, display_name: "Student 2", email: "student2@example.edu"}
        ],
        section_title: "Demo Section",
        instructor_email: "instructor@example.edu",
        instructor_name: "Instructor Example",
        section_slug: "demo-section",
        selected_bucket_id: "struggling",
        show_modal: false,
        email_handler_id: "student_support_tile"
      },
      overrides
    )
  end
end

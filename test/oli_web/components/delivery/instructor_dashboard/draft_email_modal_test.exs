defmodule OliWeb.Components.Delivery.InstructorDashboard.DraftEmailModalTest do
  use OliWeb.ConnCase, async: false
  use Oban.Testing, repo: Oli.Repo

  import LiveComponentTests
  import Phoenix.LiveViewTest

  alias Oli.Repo

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.DraftEmailModal
  alias Oli.InstructorDashboard.Email.SendWorker

  setup do
    Repo.delete_all(Oban.Job)
    :ok
  end

  describe "rendering" do
    test "renders modal with title, controls, and footer", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, DraftEmailModal, base_attrs(%{show_modal: true}))

      html = render(view)

      assert html =~ "Draft Email"
      assert html =~ "Generate New Draft"
      assert html =~ "Neutral"
      assert html =~ "Encouraging"
      assert html =~ "Firm"
      assert html =~ "Subject:"
      assert html =~ "Body:"
      assert html =~ "Cancel"
      assert html =~ "Send"
      assert html =~ "will be personalized automatically"
    end

    test "renders recipient chips", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, DraftEmailModal, base_attrs(%{show_modal: true}))

      html = render(view)

      assert html =~ "student1@example.edu"
      assert html =~ "student2@example.edu"
      assert html =~ ~s(aria-label="Recipient: student1@example.edu, remove")
    end

    test "shows excluded recipients note", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{
            show_modal: true,
            students: [
              %{id: 1, display_name: "Student 1", email: "student1@example.edu"},
              %{id: 2, display_name: "Student 2", email: nil}
            ]
          })
        )

      assert has_element?(view, ~s{span[title="Student 2"]}, "1 selected student")
    end

    test "shows empty recipients message when no students have email", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{
            show_modal: true,
            students: [%{id: 1, display_name: "Student 1", email: nil}]
          })
        )

      assert has_element?(view, "p", "No students currently need this message")
    end
  end

  describe "tone selection" do
    test "neutral is selected by default", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, DraftEmailModal, base_attrs(%{show_modal: true}))

      html = render(view)
      assert html =~ ~s(aria-pressed="true")
    end

    test "clicking a tone button selects it", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, DraftEmailModal, base_attrs(%{show_modal: true}))

      view
      |> element(~s{button[phx-value-tone="encouraging"]})
      |> render_click()

      encouraging_button =
        view
        |> element(~s{button[phx-value-tone="encouraging"]})
        |> render()

      assert encouraging_button =~ ~s(aria-pressed="true")

      neutral_button =
        view
        |> element(~s{button[phx-value-tone="neutral"]})
        |> render()

      assert neutral_button =~ ~s(aria-pressed="false")
    end
  end

  describe "recipient management" do
    test "removing a recipient updates the chip list", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, DraftEmailModal, base_attrs(%{show_modal: true}))

      view
      |> element(~s{button[aria-label="Recipient: student1@example.edu, remove"]})
      |> render_click()

      html = render(view)
      refute html =~ "student1@example.edu"
      assert html =~ "student2@example.edu"
    end

    test "removing all recipients disables send", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{
            show_modal: true,
            students: [%{id: 1, display_name: "Student 1", email: "student1@example.edu"}]
          })
        )

      view
      |> element(~s{button[aria-label="Recipient: student1@example.edu, remove"]})
      |> render_click()

      send_button =
        view
        |> element(~s{[id$="_send_button"]})
        |> render()

      assert send_button =~ "disabled"
    end

    test "removing a recipient excludes them from the email actually sent", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{show_modal: true, id: "remove_recipient_send"})
        )

      # Populate subject + body so Send is enabled.
      deliver_draft(view, "remove_recipient_send", "Subject", "Body content")

      # Remove student1 (id 1) via the chip.
      view
      |> element(~s{button[aria-label="Recipient: student1@example.edu, remove"]})
      |> render_click()

      # Let the real send path run; swallow the parent-bound messages.
      live_component_intercept(view, fn
        {:flash_message, _}, socket -> {:halt, socket}
        {:hide_email_modal, _}, socket -> {:halt, socket}
        _other, socket -> {:cont, socket}
      end)

      view |> element(~s{[id$="_send_button"]}) |> render_click()

      enqueued_user_ids =
        [worker: SendWorker]
        |> all_enqueued()
        |> Enum.map(& &1.args["user_id"])
        |> Enum.sort()

      refute 1 in enqueued_user_ids
      assert enqueued_user_ids == [2]
    end
  end

  describe "subject editing" do
    test "updating subject reflects in state", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, DraftEmailModal, base_attrs(%{show_modal: true}))

      view
      |> element(~s{input[id$="_subject"]})
      |> render_blur(%{"value" => "New subject line"})

      html = render(view)
      assert html =~ "New subject line"
    end
  end

  describe "body editing" do
    test "delivering a draft populates body and enables send with subject", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{show_modal: true, id: "body_edit_test"})
        )

      deliver_draft(view, "body_edit_test", "Test Subject", "Body content here")

      html = render(view)
      assert html =~ "Test Subject"

      send_button =
        view
        |> element(~s{[id$="_send_button"]})
        |> render()

      refute send_button =~ "disabled=\"disabled\""
    end
  end

  describe "generate draft" do
    test "clicking generate sends message to parent", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, DraftEmailModal, base_attrs(%{show_modal: true}))

      test_pid = self()

      live_component_intercept(view, fn
        {:generate_draft, _component_id, _context}, socket ->
          send(test_pid, :generate_requested)
          {:halt, socket}

        _other, socket ->
          {:cont, socket}
      end)

      view
      |> element(~s{button}, "Generate New Draft")
      |> render_click()

      assert_receive :generate_requested
    end

    test "shows loading state while generating", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, DraftEmailModal, base_attrs(%{show_modal: true}))

      live_component_intercept(view, fn
        {:generate_draft, _, _}, socket -> {:halt, socket}
        _other, socket -> {:cont, socket}
      end)

      view
      |> element(~s{button}, "Generate New Draft")
      |> render_click()

      html = render(view)
      assert html =~ "Generating draft"
      assert html =~ "ai-spinning"
    end

    test "successful draft result populates subject and shows regenerate", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{show_modal: true, id: "draft_success_test"})
        )

      deliver_draft(view, "draft_success_test", "Generated Subject", "First paragraph.")

      html = render(view)
      assert html =~ "Generated Subject"
      assert html =~ "Regenerate Draft"
    end

    test "failed draft result shows error", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{show_modal: true, id: "draft_fail_test"})
        )

      LiveComponentTests.Driver.run(view, fn socket ->
        DraftEmailModal.deliver_draft_result("draft_fail_test", {:error, :timeout})
        {:reply, :ok, socket}
      end)

      _ = render(view)
      html = render(view)
      assert html =~ "Draft generation timed out"
    end
  end

  describe "send email" do
    test "send is disabled with empty subject even when body has content", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{show_modal: true, id: "send_disabled_subj"})
        )

      # Deliver a draft (populates subject + body), then clear the subject
      deliver_draft(view, "send_disabled_subj", "Will be cleared", "Body content")

      view
      |> element(~s{input[id$="_subject"]})
      |> render_blur(%{"value" => ""})

      send_button =
        view
        |> element(~s{[id$="_send_button"]})
        |> render()

      assert send_button =~ "disabled"
    end

    test "send is disabled when body is empty", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, DraftEmailModal, base_attrs(%{show_modal: true}))

      view
      |> element(~s{input[id$="_subject"]})
      |> render_blur(%{"value" => "Subject here"})

      send_button =
        view
        |> element(~s{[id$="_send_button"]})
        |> render()

      assert send_button =~ "disabled"
    end

    test "send is enabled after draft delivery with subject and body", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{show_modal: true, id: "send_enabled_test"})
        )

      deliver_draft(view, "send_enabled_test", "Test subject", "Test body")

      send_button =
        view
        |> element(~s{[id$="_send_button"]})
        |> render()

      refute send_button =~ "disabled=\"disabled\""
    end
  end

  describe "context builder error" do
    test "shows error and disables generate when email context fails to build", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{show_modal: true, situation_key: :nonexistent_situation})
        )

      html = render(view)
      assert html =~ "Unable to prepare email context"

      generate_button =
        view
        |> element(~s{button}, "Generate New Draft")
        |> render()

      assert generate_button =~ "disabled"
    end
  end

  describe "close modal" do
    test "close button sends message to parent", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, DraftEmailModal, base_attrs(%{show_modal: true}))

      test_pid = self()

      live_component_intercept(view, fn
        {:hide_email_modal, handler_id}, socket ->
          send(test_pid, {:hide_requested, handler_id})
          {:halt, socket}

        _other, socket ->
          {:cont, socket}
      end)

      assert has_element?(view, ~s{button[aria-label="Close draft email modal"]})

      view
      |> element(~s{button[aria-label="Close draft email modal"]})
      |> render_click()

      assert_receive {:hide_requested, "draft_email_tile"}
    end
  end

  describe "live announcements" do
    test "generating draft announces to screen readers", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, DraftEmailModal, base_attrs(%{show_modal: true}))

      live_component_intercept(view, fn
        {:generate_draft, _, _}, socket -> {:halt, socket}
        _other, socket -> {:cont, socket}
      end)

      view
      |> element(~s{button}, "Generate New Draft")
      |> render_click()

      html = render(view)
      assert html =~ "Generating email draft"
    end
  end

  defp deliver_draft(view, component_id, subject, body_markdown) do
    LiveComponentTests.Driver.run(view, fn socket ->
      DraftEmailModal.deliver_draft_result(
        component_id,
        {:ok, %{subject_template: subject, body_template: body_markdown, metadata: %{}}}
      )

      {:reply, :ok, socket}
    end)

    # Allow send_update to be processed
    _ = render(view)
  end

  defp base_attrs(overrides) do
    Map.merge(
      %{
        id: "draft_email_modal_test",
        students: [
          %{
            id: 1,
            display_name: "Student 1",
            given_name: "Student",
            family_name: "One",
            email: "student1@example.edu"
          },
          %{
            id: 2,
            display_name: "Student 2",
            given_name: "Student",
            family_name: "Two",
            email: "student2@example.edu"
          }
        ],
        section_id: 1,
        section_title: "Demo Section",
        instructor_email: "instructor@example.edu",
        instructor_name: "Instructor Example",
        scope_label: "All students",
        situation_key: :struggling_students,
        show_modal: false,
        email_handler_id: "draft_email_tile"
      },
      overrides
    )
  end
end

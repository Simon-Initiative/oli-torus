defmodule OliWeb.Components.Delivery.InstructorDashboard.DraftEmailModalTest do
  use OliWeb.ConnCase, async: false
  use Oban.Testing, repo: Oli.Repo

  import LiveComponentTests
  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Repo
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.DraftEmailModal
  alias Oli.InstructorDashboard.Email.SendWorker

  setup do
    Repo.delete_all(Oban.Job)
    :ok
  end

  describe "linkable_pages/1" do
    setup [:create_section_with_pages]

    test "projects non-hidden section lessons into the link-picker DTO", ctx do
      %{
        section: %{id: section_id},
        page_1_revision: page_1,
        page_2_revision: page_2,
        removed_page_revision: removed_page,
        hidden_page_revision: hidden_page
      } = ctx

      pages = DraftEmailModal.linkable_pages(section_id)

      slugs = Enum.map(pages, & &1.slug)

      # Hidden excluded; removed-from-schedule included (still valid content).
      assert page_1.slug in slugs
      assert page_2.slug in slugs
      assert removed_page.slug in slugs
      refute hidden_page.slug in slugs

      # DTO shape: revision_slug as slug, resource_id as id, title present, sortable index.
      page_1_dto = Enum.find(pages, &(&1.slug == page_1.slug))
      assert page_1_dto.id == page_1.resource_id
      assert page_1_dto.title == "Page 1"
      assert Map.has_key?(page_1_dto, :numbering_index)
      assert Map.keys(page_1_dto) |> Enum.sort() == [:id, :numbering_index, :slug, :title]
    end

    test "returns an empty list for a section with no resolvable pages" do
      assert DraftEmailModal.linkable_pages(-1) == []
    end
  end

  describe "recipients/3" do
    test "keeps selected students (incl. those without email) and sets display_name" do
      students = [
        %{
          id: 1,
          email: "a@example.edu",
          given_name: "A",
          family_name: "One",
          full_name: "One, A"
        },
        %{id: 2, email: nil, given_name: "B", family_name: "Two", full_name: "Two, B"},
        %{id: 3, email: "c@example.edu", full_name: "Three, C"}
      ]

      result = DraftEmailModal.recipients(students, [1, 2], & &1.full_name)

      assert [
               %{id: 1, email: "a@example.edu", display_name: "One, A"},
               %{id: 2, email: nil, display_name: "Two, B"}
             ] = result

      # Not-selected student is excluded; no-email student (2) is kept.
      assert Enum.map(result, & &1.id) == [1, 2]
      assert Enum.find(result, &(&1.id == 2)).given_name == "B"
    end
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

    test "excluded recipients note exposes names via aria-label", %{conn: conn} do
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

      assert has_element?(view, ~s{span[aria-label="Student 2"]}, "1 selected student")
    end

    test "caps the excluded names list with an overflow count", %{conn: conn} do
      excluded = for n <- 1..5, do: %{id: 100 + n, display_name: "No Email #{n}", email: nil}
      students = [%{id: 1, display_name: "Has Email", email: "has@example.edu"} | excluded]

      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{show_modal: true, students: students})
        )

      html = render(view)
      assert html =~ "No Email 1"
      assert html =~ "and 2 others"
      refute html =~ "No Email 5"
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

    test "an unknown tone value is ignored and does not crash the component", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, DraftEmailModal, base_attrs(%{show_modal: true}))

      # Simulate a crafted/stale client event carrying a tone that is not a known atom.
      view
      |> element(~s{button[phx-value-tone="neutral"]})
      |> render_click(%{"tone" => "not_a_real_tone_xyz"})

      # Component is still alive and the default tone is unchanged.
      neutral_button =
        view
        |> element(~s{button[phx-value-tone="neutral"]})
        |> render()

      assert neutral_button =~ ~s(aria-pressed="true")
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

    test "AI-suggested markdown links survive as real links in the sent email", %{conn: conn} do
      section = insert(:section)

      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{
            show_modal: true,
            id: "e4_links",
            section_id: section.id,
            students: [
              %{
                id: 1,
                display_name: "S1",
                given_name: "S",
                family_name: "One",
                email: "s1@example.edu"
              }
            ]
          })
        )

      deliver_draft(view, "e4_links", "Subject", "Visit [Lesson 1](/course/link/lesson-1) today.")

      live_component_intercept(view, fn
        {:flash_message, _}, socket -> {:halt, socket}
        {:hide_email_modal, _}, socket -> {:halt, socket}
        _other, socket -> {:cont, socket}
      end)

      view |> element(~s{[id$="_send_button"]}) |> render_click()

      [job] = all_enqueued(worker: SendWorker)
      email = Oli.Mailer.SendEmailWorker.deserialize_email(job.args["email"])

      assert email.html_body =~ "<a "
      assert email.html_body =~ "Lesson 1"
      # Must not be flattened to literal markdown text.
      refute email.html_body =~ "[Lesson 1]("
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
    test "subject input is marked required for assistive tech", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, DraftEmailModal, base_attrs(%{show_modal: true}))

      assert has_element?(view, ~s{input[id$="_subject"][aria-required="true"]})
    end

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
        {:generate_draft, _component_id, _previous_rid, _rid, _context}, socket ->
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
        {:generate_draft, _, _, _, _}, socket -> {:halt, socket}
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

      rid = generate_and_capture_rid(view)

      LiveComponentTests.Driver.run(view, fn socket ->
        DraftEmailModal.deliver_draft_result("draft_fail_test", rid, {:error, :timeout})
        {:reply, :ok, socket}
      end)

      _ = render(view)
      html = render(view)
      assert html =~ "Draft generation timed out"
    end

    test "applies only the result of the current request; drops stale and duplicate results", %{
      conn: conn
    } do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{show_modal: true, id: "rid_scope_test"})
        )

      rid = generate_and_capture_rid(view)

      deliver = fn request_id, subject ->
        LiveComponentTests.Driver.run(view, fn socket ->
          DraftEmailModal.deliver_draft_result(
            "rid_scope_test",
            request_id,
            {:ok, %{subject_template: subject, body_template: "Body", metadata: %{}}}
          )

          {:reply, :ok, socket}
        end)

        _ = render(view)
      end

      # Matching request id is applied.
      deliver.(rid, "Matched Subject")
      assert render(view) =~ "Matched Subject"

      # Duplicate delivery of the same (now consumed) id is ignored.
      deliver.(rid, "Duplicate Subject")
      refute render(view) =~ "Duplicate Subject"
      assert render(view) =~ "Matched Subject"

      # A stale id (different request) is ignored.
      deliver.(rid + 1, "Stale Subject")
      refute render(view) =~ "Stale Subject"
      assert render(view) =~ "Matched Subject"
    end

    test "closing then regenerating scopes results to the current request id", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{show_modal: true, id: "lifecycle_test"})
        )

      test_pid = self()

      live_component_intercept(view, fn
        {:generate_draft, _id, _prev, rid, _ctx}, socket ->
          send(test_pid, {:rid, rid})
          {:halt, socket}

        {:cancel_draft, _, _} = msg, socket ->
          send(test_pid, msg)
          {:halt, socket}

        _other, socket ->
          {:cont, socket}
      end)

      deliver = fn request_id, subject ->
        LiveComponentTests.Driver.run(view, fn socket ->
          DraftEmailModal.deliver_draft_result(
            "lifecycle_test",
            request_id,
            {:ok, %{subject_template: subject, body_template: "Body", metadata: %{}}}
          )

          {:reply, :ok, socket}
        end)

        _ = render(view)
      end

      # First generation, then close. Close must carry the real request id and invalidate it.
      view |> element("button[phx-click='generate_draft']") |> render_click()
      assert_receive {:rid, rid1}

      view |> element("button", "Cancel") |> render_click()
      assert_received {:cancel_draft, "lifecycle_test", ^rid1}

      # A result for the closed generation is dropped (token cleared on close).
      deliver.(rid1, "After Close Subject")
      refute render(view) =~ "After Close Subject"

      # Reopen (show_modal false -> true) resets the generation state, as in production.
      toggle_show_modal = fn show ->
        LiveComponentTests.Driver.run(view, fn socket ->
          {:reply, :ok,
           Phoenix.Component.assign(
             socket,
             :lc_attrs,
             Map.put(socket.assigns.lc_attrs, :show_modal, show)
           )}
        end)

        _ = render(view)
      end

      toggle_show_modal.(false)
      toggle_show_modal.(true)

      # Even after reopen, a result from the previous generation stays rejected.
      deliver.(rid1, "Reopen Stale Subject")
      refute render(view) =~ "Reopen Stale Subject"

      # A fresh generation supersedes: the old id stays rejected, the new one applies.
      view |> element("button[phx-click='generate_draft']") |> render_click()
      assert_receive {:rid, rid2}
      refute rid2 == rid1

      deliver.(rid1, "Stale Generation Subject")
      refute render(view) =~ "Stale Generation Subject"

      deliver.(rid2, "Current Generation Subject")
      assert render(view) =~ "Current Generation Subject"
    end

    test "reopening (without closing) resets the request id so a prior result is dropped", %{
      conn: conn
    } do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{show_modal: true, id: "reopen_reset_test"})
        )

      test_pid = self()

      live_component_intercept(view, fn
        {:generate_draft, _id, _prev, rid, _ctx}, socket ->
          send(test_pid, {:rid, rid})
          {:halt, socket}

        _other, socket ->
          {:cont, socket}
      end)

      # Start a generation (sets the request id), then reopen WITHOUT closing first, so the only
      # thing that can clear the id is the open-branch reset.
      view |> element("button[phx-click='generate_draft']") |> render_click()
      assert_receive {:rid, rid}

      toggle_show_modal = fn show ->
        LiveComponentTests.Driver.run(view, fn socket ->
          {:reply, :ok,
           Phoenix.Component.assign(
             socket,
             :lc_attrs,
             Map.put(socket.assigns.lc_attrs, :show_modal, show)
           )}
        end)

        _ = render(view)
      end

      toggle_show_modal.(false)
      toggle_show_modal.(true)

      LiveComponentTests.Driver.run(view, fn socket ->
        DraftEmailModal.deliver_draft_result(
          "reopen_reset_test",
          rid,
          {:ok, %{subject_template: "Pre-Reopen Subject", body_template: "Body", metadata: %{}}}
        )

        {:reply, :ok, socket}
      end)

      _ = render(view)
      refute render(view) =~ "Pre-Reopen Subject"
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

    test "send stays disabled when the delivered body is only an empty link", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{show_modal: true, id: "send_empty_link"})
        )

      # An empty-anchor markdown link yields a link node whose only child is blank text — no
      # visible content, so Send must stay disabled even though the body has a (link) node.
      deliver_draft(view, "send_empty_link", "Subject here", "[](/course/link/intro)")
      assert view |> element(~s{[id$="_send_button"]}) |> render() =~ "disabled"

      # A link carrying visible text is real content → Send enables.
      deliver_draft(view, "send_empty_link", "Subject here", "[Intro](/course/link/intro)")
      refute view |> element(~s{[id$="_send_button"]}) |> render() =~ "disabled"
    end

    test "Send is disabled while a draft is regenerating", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{show_modal: true, id: "regen_send"})
        )

      # Deliver a draft → Send becomes enabled.
      deliver_draft(view, "regen_send", "Subject", "Body content")
      enabled = view |> element(~s{[id$="_send_button"]}) |> render()
      refute enabled =~ ~s(aria-disabled="true")

      # Clicking Regenerate clears the draft + starts generating → Send must disable.
      live_component_intercept(view, fn
        {:generate_draft, _, _, _, _}, socket -> {:halt, socket}
        _other, socket -> {:cont, socket}
      end)

      view |> element(~s{button}, "Regenerate Draft") |> render_click()

      regenerating = view |> element(~s{[id$="_send_button"]}) |> render()
      assert regenerating =~ ~s(aria-disabled="true")
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

    test "Send button is aria-disabled (not hard-disabled) while the draft is incomplete", %{
      conn: conn
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, DraftEmailModal, base_attrs(%{show_modal: true}))

      send_button = view |> element(~s{[id$="_send_button"]}) |> render()
      assert send_button =~ ~s(aria-disabled="true")
    end

    test "clicking Send while incomplete explains what is missing instead of doing nothing", %{
      conn: conn
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, DraftEmailModal, base_attrs(%{show_modal: true}))

      # Default state: recipients present, but subject + body are empty → not ready.
      view |> element(~s{[id$="_send_button"]}) |> render_click()

      html = render(view)
      assert html =~ "subject"
      assert html =~ "body"
    end

    test "editing a field clears a stale Send-validation message", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, DraftEmailModal, base_attrs(%{show_modal: true}))

      # Click Send while incomplete → inline validation message appears.
      view |> element(~s{[id$="_send_button"]}) |> render_click()
      assert render(view) =~ "before sending."

      # The user now fills in the subject. The stale message (which named the
      # subject as missing) must not linger — it is cleared on edit.
      view
      |> element(~s{input[id$="_subject"]})
      |> render_blur(%{"value" => "Now has a subject"})

      refute render(view) =~ "before sending."
    end

    test "send surfaces a specific, actionable message for a backend validation reason", %{
      conn: conn
    } do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{
            show_modal: true,
            id: "e6_invalid_instructor",
            instructor_email: "not-an-email"
          })
        )

      deliver_draft(view, "e6_invalid_instructor", "Subject", "Body content")

      live_component_intercept(view, fn
        {:flash_message, _}, socket -> {:halt, socket}
        {:hide_email_modal, _}, socket -> {:halt, socket}
        _other, socket -> {:cont, socket}
      end)

      view |> element(~s{[id$="_send_button"]}) |> render_click()

      html = render(view)
      assert html =~ "reply-to email address is invalid"
      refute html =~ "Validation failed"
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
        {:generate_draft, _, _, _, _}, socket -> {:halt, socket}
        _other, socket -> {:cont, socket}
      end)

      view
      |> element(~s{button}, "Generate New Draft")
      |> render_click()

      html = render(view)
      assert html =~ "Generating email draft"
    end
  end

  # Builds a published section with: two visible pages (one graded), one hidden page,
  # and one removed-from-schedule page — to exercise linkable_pages/1 filtering.
  defp create_section_with_pages(_) do
    page_1_revision =
      insert(:revision, resource_type_id: ResourceType.id_for_page(), title: "Page 1")

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        title: "Page 2",
        graded: true
      )

    hidden_page_revision =
      insert(:revision, resource_type_id: ResourceType.id_for_page(), title: "Hidden Page")

    removed_page_revision =
      insert(:revision, resource_type_id: ResourceType.id_for_page(), title: "Removed Page")

    module_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        children: [
          page_1_revision.resource_id,
          page_2_revision.resource_id,
          hidden_page_revision.resource_id,
          removed_page_revision.resource_id
        ],
        title: "Module 1"
      )

    container_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        title: "Root Container",
        children: [module_1_revision.resource_id]
      )

    instructor = insert(:user)
    project = insert(:project, authors: [instructor.author])

    all_revisions = [
      container_revision,
      module_1_revision,
      page_1_revision,
      page_2_revision,
      hidden_page_revision,
      removed_page_revision
    ]

    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{project_id: project.id, resource_id: revision.resource_id})
    end)

    publication =
      insert(:publication, %{project: project, root_resource_id: container_revision.resource_id})

    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: instructor.author
      })
    end)

    section = insert(:section, base_project: project, title: "The Project")
    {:ok, section} = Sections.create_section_resources(section, publication)

    hidden_sr = Sections.get_section_resource(section.id, hidden_page_revision.resource_id)
    Sections.update_section_resource(hidden_sr, %{hidden: true})

    removed_sr = Sections.get_section_resource(section.id, removed_page_revision.resource_id)
    Sections.update_section_resource(removed_sr, %{removed_from_schedule: true})

    %{
      section: section,
      page_1_revision: page_1_revision,
      page_2_revision: page_2_revision,
      hidden_page_revision: hidden_page_revision,
      removed_page_revision: removed_page_revision
    }
  end

  describe "draft cancellation on close" do
    test "closing the modal emits both the cancel-draft and hide messages", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(
          conn,
          DraftEmailModal,
          base_attrs(%{show_modal: true, id: "close_wiring"})
        )

      test_pid = self()

      live_component_intercept(view, fn
        {:cancel_draft, _, _} = msg, socket ->
          send(test_pid, msg)
          {:halt, socket}

        {:hide_email_modal, _} = msg, socket ->
          send(test_pid, msg)
          {:halt, socket}

        _other, socket ->
          {:cont, socket}
      end)

      view |> element("button", "Cancel") |> render_click()

      # Cancels the in-flight draft (component id + current request id) and hides the modal.
      assert_received {:cancel_draft, "close_wiring", _request_id}
      assert_received {:hide_email_modal, _}
    end
  end

  defp deliver_draft(view, component_id, subject, body_markdown) do
    rid = generate_and_capture_rid(view)

    LiveComponentTests.Driver.run(view, fn socket ->
      DraftEmailModal.deliver_draft_result(
        component_id,
        rid,
        {:ok, %{subject_template: subject, body_template: body_markdown, metadata: %{}}}
      )

      {:reply, :ok, socket}
    end)

    # Allow send_update to be processed
    _ = render(view)
  end

  # Triggers the component's generate event (which mints + stores a draft_request_id) and returns
  # that id, so a subsequent deliver_draft_result/3 with it is applied rather than dropped as stale.
  # The {:generate_draft, ...} message is intercepted (and halted) so no real async runs.
  defp generate_and_capture_rid(view) do
    test_pid = self()

    live_component_intercept(view, fn
      {:generate_draft, _id, _previous_rid, rid, _ctx}, socket ->
        send(test_pid, {:captured_rid, rid})
        {:halt, socket}

      _other, socket ->
        {:cont, socket}
    end)

    view |> element("button[phx-click='generate_draft']") |> render_click()
    assert_receive {:captured_rid, rid}
    rid
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

defmodule OliWeb.Progress.PageAttemptSummaryTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Common.SessionContext
  alias OliWeb.Delivery.Student.Utils
  alias OliWeb.Progress.PageAttemptSummary

  describe "PageAttemptSummary component" do
    setup do
      attempt = %{
        attempt_guid: "guid",
        attempt_number: 1,
        inserted_at: ~U[2024-07-01 10:20:00.0Z],
        date_evaluated: ~U[2024-07-02 11:30:00.0Z],
        date_submitted: ~U[2024-07-03 12:40:00.0Z],
        lifecycle_state: :active,
        was_late: false,
        score: 10,
        out_of: 20
      }

      section = %{slug: "section_slug"}
      ctx = SessionContext.init()
      revision = %{slug: "revision_slug", graded: true}

      {:ok, attempt: attempt, section: section, ctx: ctx, revision: revision}
    end

    test "renders active attempt", %{
      attempt: attempt,
      section: section,
      ctx: ctx,
      revision: revision
    } do
      attempt = %{attempt | lifecycle_state: :active}
      assigns = %{attempt: attempt, section: section, ctx: ctx, revision: revision}

      html = render_component(PageAttemptSummary, assigns)

      assert html =~ "Attempt #{attempt.attempt_number}"
      assert html =~ "Not Submitted Yet"
      assert html =~ "Started: July 1, 2024 10:20 AM UTC"
      assert html =~ "Submit Attempt on Behalf of Student"

      href = Utils.review_live_path(section.slug, revision.slug, attempt.attempt_guid)
      assert html =~ ~r/href="#{href}\?.*"/
    end

    test "renders evaluated attempt", %{
      attempt: attempt,
      section: section,
      ctx: ctx,
      revision: revision
    } do
      attempt = %{attempt | lifecycle_state: :evaluated}
      assigns = %{attempt: attempt, section: section, ctx: ctx, revision: revision}

      html = render_component(PageAttemptSummary, assigns)

      assert html =~ "Attempt #{attempt.attempt_number}"
      assert html =~ "#{attempt.score} / #{attempt.out_of}"
      assert html =~ "Submitted: July 2, 2024 11:30 AM UTC"

      href = Utils.review_live_path(section.slug, revision.slug, attempt.attempt_guid)
      assert html =~ ~r/href="#{href}\?.*"/
    end

    test "renders submitted attempt", %{
      attempt: attempt,
      section: section,
      ctx: ctx,
      revision: revision
    } do
      attempt = %{attempt | lifecycle_state: :submitted}
      assigns = %{attempt: attempt, section: section, ctx: ctx, revision: revision}

      html = render_component(PageAttemptSummary, assigns)

      assert html =~ "Attempt #{attempt.attempt_number}"
      assert html =~ "Submitted"
      assert html =~ "Submitted: July 3, 2024 12:40 PM UTC"

      href = Utils.review_live_path(section.slug, revision.slug, attempt.attempt_guid)
      assert html =~ ~r/href="#{href}\?.*"/
    end
  end
end

defmodule OliWeb.Progress.PageAttemptSummaryTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias OliWeb.Common.{SessionContext, Utils}
  alias OliWeb.Delivery.Student.Utils, as: StudentUtils
  alias OliWeb.Progress.PageAttemptSummary

  defp get_or_insert_resource_access(student, section, revision) do
    Oli.Repo.get_by(
      ResourceAccess,
      resource_id: revision.resource_id,
      section_id: section.id,
      user_id: student.id
    )
    |> case do
      nil ->
        insert(:resource_access, %{
          user: student,
          section: section,
          resource: revision.resource
        })

      resource_access ->
        resource_access
    end
  end

  describe "PageAttemptSummary component" do
    setup do
      student = insert(:user)
      section = insert(:section)
      ctx = SessionContext.init()
      revision = insert(:revision, graded: true)

      resource_access = get_or_insert_resource_access(student, section, revision)

      attempt =
        insert(:resource_attempt, %{
          resource_access: resource_access,
          revision: revision,
          date_submitted: ~U[2024-07-02 11:30:00Z],
          date_evaluated: ~U[2024-07-02 11:30:00Z],
          score: 5,
          out_of: 10,
          lifecycle_state: :active,
          content: %{model: []}
        })

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
      assert html =~ "Started: #{attempt.inserted_at |> Utils.render_date(:inserted_at, ctx)}"
      assert html =~ "Submit Attempt on Behalf of Student"

      href = StudentUtils.review_live_path(section.slug, revision.slug, attempt.attempt_guid)
      assert html =~ ~r/href="#{href}\?.*"/
    end

    test "renders evaluated attempt", %{
      attempt: attempt,
      section: section,
      ctx: ctx,
      revision: revision
    } do
      attempt = %{attempt | lifecycle_state: :evaluated}

      attempt =
        Oli.Repo.preload(attempt, activity_attempts: [:part_attempts])

      assigns = %{attempt: attempt, section: section, ctx: ctx, revision: revision}

      html = render_component(PageAttemptSummary, assigns)

      assert html =~ "Attempt #{attempt.attempt_number}"
      assert html =~ "#{attempt.score} / #{attempt.out_of}"

      assert html =~
               "Submitted: #{attempt.date_evaluated |> Utils.render_date(:date_evaluated, ctx)}"

      href = StudentUtils.review_live_path(section.slug, revision.slug, attempt.attempt_guid)
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

      assert html =~
               "Submitted: #{attempt.date_evaluated |> Utils.render_date(:date_evaluated, ctx)}"

      href = StudentUtils.review_live_path(section.slug, revision.slug, attempt.attempt_guid)
      assert html =~ ~r/href="#{href}\?.*"/
    end
  end
end

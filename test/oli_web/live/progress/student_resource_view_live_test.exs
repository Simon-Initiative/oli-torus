defmodule OliWeb.Progress.StudentResourceViewLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ResourceAccess}
  alias Oli.Delivery.Sections
  alias Oli.Repo

  defp live_view_student_resource_view_route(section_slug, user_id, resource_id) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Progress.StudentResourceView,
      section_slug,
      user_id,
      resource_id
    )
  end

  defp setup_section_resource_access(%{:instructor => instructor}) do
    {:ok,
     section: section,
     unit_one_revision: _unit_one_revision,
     page_revision: page_revision,
     page_2_revision: _page_2_revision} =
      section_with_assessment(%{})

    student = insert(:user)

    enroll_user_to_section(student, section, :context_learner)
    enroll_user_to_section(instructor, section, :context_instructor)

    resource_access =
      insert(:resource_access,
        user: student,
        resource: page_revision.resource,
        section: section,
        score: 1,
        out_of: 2
      )

    [section_slug: section.slug, student_id: student.id, resource_id: resource_access.resource_id]
  end

  defp create_attempt(student, section, revision, resource_attempt_data \\ %{}) do
    resource_access = get_or_insert_resource_access(student, section, revision)

    resource_attempt =
      insert(:resource_attempt, %{
        resource_access: resource_access,
        revision: revision,
        date_submitted: resource_attempt_data[:date_submitted] || ~U[2023-11-14 20:00:00Z],
        date_evaluated: resource_attempt_data[:date_evaluated] || ~U[2023-11-14 20:30:00Z],
        score: resource_attempt_data[:score] || 5,
        out_of: resource_attempt_data[:out_of] || 10,
        lifecycle_state: resource_attempt_data[:lifecycle_state] || :evaluated,
        content: resource_attempt_data[:content] || %{model: []}
      })

    activity_attempt =
      insert(:activity_attempt,
        resource_attempt: resource_attempt,
        resource: revision.resource,
        revision: revision,
        lifecycle_state: :submitted,
        score: 5,
        out_of: 10
      )

    insert(:part_attempt, %{
      activity_attempt_id: activity_attempt.id,
      activity_attempt: activity_attempt,
      attempt_guid: UUID.uuid4(),
      part_id: "1",
      grading_approach: :manual,
      datashop_session_id: "1234abcd",
      score: 5,
      out_of: 10,
      lifecycle_state: :submitted
    })

    resource_attempt
  end

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

  defp wrap_in_paragraphs(text) do
    String.split(text, "\n")
    |> Enum.map(fn text ->
      %{type: "p", children: [%{text: text}]}
    end)
  end

  describe "student resource view" do
    setup [:instructor_conn, :setup_section_resource_access]

    test "score must be less or equal to out_of value", %{
      conn: conn,
      section_slug: section_slug,
      student_id: student_id,
      resource_id: resource_id
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_student_resource_view_route(
            section_slug,
            student_id,
            resource_id
          )
        )

      view
      |> element("form[phx-change='validate']")
      |> render_submit(%{resource_access: %{score: 3, out_of: 1}})

      assert view
             |> element("p[phx-feedback-for='resource_access[score]']")
             |> render() =~
               "must be less than out of value"

      assert view
             |> element("p[phx-feedback-for='resource_access[out_of]']")
             |> render() =~
               "must be greater than score"

      %{out_of: out_of, score: score} =
        Core.get_resource_access(resource_id, section_slug, student_id)

      refute score == 3
      refute out_of == 1
    end

    test "score is saved if score and out_of values are correct", %{
      conn: conn,
      section_slug: section_slug,
      student_id: student_id,
      resource_id: resource_id
    } do
      {:ok, view, _html} =
        live(
          conn,
          live_view_student_resource_view_route(
            section_slug,
            student_id,
            resource_id
          )
        )

      view
      |> element("form[phx-change='validate']")
      |> render_submit(%{resource_access: %{score: 2.5, out_of: 2.5}})

      assert view
             |> element("input[id='resource_access_score']")
             |> render() =~ "2.5"

      assert view
             |> element("input[id='resource_access_out_of']")
             |> render() =~ "2.5"

      assert view
             |> element("button[phx-click='enable_score_edit']")
             |> render() =~ "Change Score"

      %{out_of: out_of, score: score} =
        Core.get_resource_access(resource_id, section_slug, student_id)

      assert score == 2.5
      assert out_of == 2.5
    end

    test "instructors can see instructor feedback in the attempt history", %{
      conn: conn,
      instructor: instructor
    } do
      {:ok,
       section: section,
       unit_one_revision: _unit_one_revision,
       page_revision: page_revision,
       page_2_revision: _page_2_revision} =
        section_with_assessment(%{})

      user = insert(:user)

      enroll_user_to_section(instructor, section, :context_instructor)
      enroll_user_to_section(user, section, :context_learner)
      Sections.mark_section_visited_for_student(section, user)
      feedback = "This is the feedback for the student"

      attempt = create_attempt(user, section, page_revision)

      activity_attempt =
        Repo.preload(attempt, activity_attempts: [:part_attempts]).activity_attempts |> hd()

      activity_attempt = %ActivityAttempt{
        activity_attempt
        | graded: true,
          resource_attempt_guid: attempt.attempt_guid,
          lifecycle_state: :evaluated
      }

      part_attempt =
        Core.get_part_attempts_by_activity_attempts([activity_attempt.id]) |> hd()

      Core.update_part_attempt(part_attempt, %{
        lifecycle_state: :evaluated,
        date_evaluated: DateTime.utc_now(),
        score: 1.0,
        out_of: 1.0,
        feedback: %{content: wrap_in_paragraphs(feedback)}
      })

      {:ok, view, _html} =
        live(
          conn,
          live_view_student_resource_view_route(section.slug, user.id, page_revision.resource_id)
        )

      assert has_element?(view, "div", "Instructor Feedback:")
      assert has_element?(view, "textarea", "This is the feedback for the student")
    end
  end
end

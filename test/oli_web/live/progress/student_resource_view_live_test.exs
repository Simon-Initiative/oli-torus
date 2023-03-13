defmodule OliWeb.Progress.StudentResourceViewLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Attempts.Core

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
    {:ok, section: section, unit_one_revision: _unit_one_revision, page_revision: page_revision} =
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
             |> element("span[phx-feedback-for='resource_access[score]']")
             |> render() =~
               "must be less than out of value"

      assert view
             |> element("span[phx-feedback-for='resource_access[out_of]']")
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
  end
end

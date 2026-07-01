defmodule Oli.Scenarios.Features.InstructorPreviewHooks do
  import Ecto.Query, only: [from: 2]
  import ExUnit.Assertions
  import Phoenix.ConnTest, only: [html_response: 2]
  @endpoint OliWeb.Endpoint
  alias Oli.Analytics.Summary.ResourcePartResponse
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, PartAttempt, ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.Metrics
  alias Oli.Repo
  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  alias Oli.TestHelpers
  alias OliWeb.Delivery.Instructor.PreviewRoutes

  @instructor_name "preview_instructor"
  @student_name "preview_student"
  @project_name "preview_project"
  @section_name "preview_section"
  @page_title "Preview Page"

  def assert_mixed_preview_side_effect_free(%ExecutionState{} = state) do
    with {:ok, instructor} <- fetch_instructor(state),
         {:ok, student} <- fetch_student(state),
         {:ok, section} <- fetch_section(state),
         {:ok, built_project} <- fetch_project(state),
         {:ok, page_revision} <- fetch_page_revision(built_project) do
      counts_before = attempt_counts(section.id, state)

      progress_before =
        Metrics.progress_for_page(section.id, student.id, page_revision.resource_id)

      path = PreviewRoutes.lesson_path(section.slug, page_revision.slug)

      conn =
        Phoenix.ConnTest.build_conn()
        |> TestHelpers.log_in_user(instructor)
        |> Phoenix.ConnTest.get(path)

      html = html_response(conn, 200)

      assert html =~ "/js/oli_multiple_choice_preview.js"
      assert html =~ "/js/oli_short_answer_authoring.js"
      refute html =~ "/js/oli_multiple_choice_authoring.js"
      refute html =~ "/js/oli_short_answer_preview.js"
      assert length(Regex.scan(~r/instructor-preview-activity-wrapper/, html)) == 2
      assert counts_before == attempt_counts(section.id, state)

      assert progress_before ==
               Metrics.progress_for_page(section.id, student.id, page_revision.resource_id)

      state
    else
      {:error, message} -> raise message
    end
  end

  defp fetch_instructor(%ExecutionState{} = state) do
    case Map.get(state.users, @instructor_name) do
      nil -> {:error, "Instructor #{@instructor_name} not found in scenario state"}
      instructor -> {:ok, instructor}
    end
  end

  defp fetch_student(%ExecutionState{} = state) do
    case Map.get(state.users, @student_name) do
      nil -> {:error, "Student #{@student_name} not found in scenario state"}
      student -> {:ok, student}
    end
  end

  defp fetch_section(%ExecutionState{} = state) do
    case Map.get(state.sections, @section_name) do
      nil -> {:error, "Section #{@section_name} not found in scenario state"}
      section -> {:ok, section}
    end
  end

  defp fetch_project(%ExecutionState{} = state) do
    case Map.get(state.projects, @project_name) do
      nil -> {:error, "Project #{@project_name} not found in scenario state"}
      built_project -> {:ok, built_project}
    end
  end

  defp fetch_page_revision(built_project) do
    case Map.get(built_project.rev_by_title, @page_title) do
      nil -> {:error, "Page #{@page_title} not found in built project"}
      revision -> {:ok, revision}
    end
  end

  defp attempt_counts(section_id, state) do
    activity_resource_ids =
      state.activity_virtual_ids
      |> Map.values()
      |> Enum.map(& &1.resource_id)

    %{
      resource_accesses:
        Repo.aggregate(
          from(ra in ResourceAccess, where: ra.section_id == ^section_id),
          :count
        ),
      resource_attempts:
        Repo.aggregate(
          from(rt in ResourceAttempt,
            join: ra in ResourceAccess,
            on: rt.resource_access_id == ra.id,
            where: ra.section_id == ^section_id
          ),
          :count
        ),
      activity_attempts:
        Repo.aggregate(
          from(aa in ActivityAttempt,
            join: rt in ResourceAttempt,
            on: aa.resource_attempt_id == rt.id,
            join: ra in ResourceAccess,
            on: rt.resource_access_id == ra.id,
            where: ra.section_id == ^section_id
          ),
          :count
        ),
      part_attempts:
        Repo.aggregate(
          from(pa in PartAttempt,
            join: aa in ActivityAttempt,
            on: pa.activity_attempt_id == aa.id,
            join: rt in ResourceAttempt,
            on: aa.resource_attempt_id == rt.id,
            join: ra in ResourceAccess,
            on: rt.resource_access_id == ra.id,
            where: ra.section_id == ^section_id
          ),
          :count
        ),
      resource_part_responses:
        Repo.aggregate(
          from(rpr in ResourcePartResponse, where: rpr.resource_id in ^activity_resource_ids),
          :count
        )
    }
  end
end

defmodule Oli.InstructorDashboard.Prototype.Oracles.Progress do
  @moduledoc """
  Prototype progress oracle returning per-student and per-container progress.
  """

  @behaviour Oli.InstructorDashboard.Prototype.Oracle

  alias Oli.InstructorDashboard.Prototype.MockData
  alias Oli.InstructorDashboard.Prototype.Scope

  @impl true
  def key, do: :progress

  @impl true
  def load(%Scope{} = scope, _opts) do
    student_ids = MockData.student_ids()

    by_container = %{
      unit: build_container_progress(MockData.unit_ids(), student_ids),
      module: build_container_progress(MockData.module_ids(), student_ids)
    }

    {:ok,
     %{
       by_container: by_container,
       by_student: build_scoped_student_progress(scope, student_ids),
       student_ids: student_ids
     }}
  end

  defp build_container_progress(container_ids, student_ids) do
    Map.new(container_ids, fn container_id ->
      {container_id, MockData.progress_for_container(container_id, student_ids)}
    end)
  end

  defp build_scoped_student_progress(%Scope{container_type: :course}, student_ids) do
    Map.new(student_ids, fn student_id ->
      {student_id, MockData.course_progress_percent(student_id)}
    end)
  end

  defp build_scoped_student_progress(%Scope{container_type: :unit} = scope, student_ids) do
    unit_id = scope.container_id || List.first(MockData.unit_ids())

    Map.new(student_ids, fn student_id ->
      {student_id, MockData.progress_percent(student_id, unit_id)}
    end)
  end

  defp build_scoped_student_progress(%Scope{container_type: :module} = scope, student_ids) do
    module_id = scope.container_id || List.first(MockData.module_ids())

    Map.new(student_ids, fn student_id ->
      {student_id, MockData.progress_percent(student_id, module_id)}
    end)
  end
end

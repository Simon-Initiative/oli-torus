defmodule Oli.InstructorDashboard.Prototype.Tiles.StudentSupport.Data do
  @moduledoc """
  Non-UI projection logic for the Student Support tile.
  """

  alias Oli.InstructorDashboard.Prototype.Oracles
  alias Oli.InstructorDashboard.Prototype.Snapshot

  def build(%Snapshot{} = snapshot) do
    with {:ok, progress_payload} <- Snapshot.fetch_oracle(snapshot, Oracles.Progress),
         {:ok, proficiency_payload} <- Snapshot.fetch_oracle(snapshot, Oracles.Proficiency),
         {:ok, enrollments_payload} <- Snapshot.fetch_oracle(snapshot, Oracles.Enrollments) do
      rules = rules_from_scope(snapshot.scope.filters)

      {buckets, totals} =
        build_buckets(
          enrollments_payload.students,
          progress_payload.by_student,
          proficiency_payload.by_student,
          rules
        )

      {:ok,
       %{
         rules: rules,
         totals: totals,
         buckets: finalize_buckets(buckets)
       }}
    end
  end

  defp rules_from_scope(filters) do
    Map.get(filters, :student_support_rules, default_rules())
  end

  defp default_rules do
    %{
      struggling: %{any: [{:progress, :lt, 40}, {:proficiency, :lt, 40}], all: []},
      excelling: %{any: [], all: [{:progress, :gte, 80}, {:proficiency, :gte, 80}]},
      on_track: %{any: [], all: [{:progress, :gte, 40}, {:proficiency, :gte, 40}]}
    }
  end

  defp build_buckets(students, progress_by_student, proficiency_by_student, rules) do
    totals = %{total: 0, active: 0, inactive: 0}

    buckets = %{
      struggling: empty_bucket(),
      on_track: empty_bucket(),
      excelling: empty_bucket(),
      na: empty_bucket()
    }

    Enum.reduce(students, {buckets, totals}, fn student, {bucket_acc, totals_acc} ->
      progress = Map.get(progress_by_student, student.id)
      proficiency = Map.get(proficiency_by_student, student.id)
      status = if student.active, do: :active, else: :inactive

      category = categorize(%{progress: progress, proficiency: proficiency}, rules)

      bucket_acc =
        Map.update!(bucket_acc, category, fn bucket ->
          %{
            bucket
            | count: bucket.count + 1,
              students: [student_row(student, status, progress, proficiency) | bucket.students]
          }
        end)

      totals_acc =
        totals_acc
        |> Map.update!(:total, &(&1 + 1))
        |> Map.update!(status, &(&1 + 1))

      {bucket_acc, totals_acc}
    end)
  end

  defp empty_bucket do
    %{count: 0, students: []}
  end

  defp student_row(student, status, progress, proficiency) do
    %{
      id: student.id,
      name: student.name,
      status: status,
      progress: progress,
      proficiency: proficiency
    }
  end

  defp categorize(%{progress: nil}, _rules), do: :na
  defp categorize(%{proficiency: nil}, _rules), do: :na

  defp categorize(metrics, rules) do
    cond do
      matches_rule?(rules.excelling, metrics) -> :excelling
      matches_rule?(rules.struggling, metrics) -> :struggling
      matches_rule?(rules.on_track, metrics) -> :on_track
      true -> :on_track
    end
  end

  defp matches_rule?(%{any: any_rules, all: all_rules}, metrics) do
    any_ok? = any_rules == [] or Enum.any?(any_rules, &matches_predicate?(&1, metrics))
    all_ok? = Enum.all?(all_rules, &matches_predicate?(&1, metrics))
    any_ok? and all_ok?
  end

  defp matches_predicate?({field, op, value}, metrics) when field in [:progress, :proficiency] do
    actual = Map.get(metrics, field)
    compare(actual, op, value)
  end

  defp compare(nil, _op, _value), do: false
  defp compare(actual, :lt, value), do: actual < value
  defp compare(actual, :lte, value), do: actual <= value
  defp compare(actual, :gt, value), do: actual > value
  defp compare(actual, :gte, value), do: actual >= value

  defp finalize_buckets(buckets) do
    Map.new(buckets, fn {category, bucket} ->
      {category, %{bucket | students: Enum.reverse(bucket.students)}}
    end)
  end
end

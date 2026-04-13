defmodule Oli.InstructorDashboard.Recommendations.Builder do
  @moduledoc """
  Builds the sanitized recommendation input contract from a dashboard snapshot.
  """

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.DataSnapshot.Projections.{Assessments, Progress, StudentSupport}
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Progress.Projector, as: ProgressProjector
  alias Oli.InstructorDashboard.Recommendations.Prompt

  @max_progress_rows 10
  @max_assessment_rows 10
  @max_scope_item_titles 8

  @spec build_input_contract(Contract.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def build_input_contract(%Contract{} = snapshot, opts \\ []) do
    with {:ok, progress_projection} <- Progress.derive(snapshot, []),
         {:ok, student_support_projection} <- StudentSupport.derive(snapshot, opts),
         {:ok, assessments_projection} <- Assessments.derive(snapshot, opts) do
      progress_tile =
        progress_projection.progress_tile
        |> ProgressProjector.reproject(%{
          completion_threshold: Keyword.get(opts, :completion_threshold, 100),
          y_axis_mode: :count
        })

      scope_resources = Map.get(snapshot.oracles, :oracle_instructor_scope_resources, %{})
      support = student_support_projection.support
      assessments = assessments_projection.assessments

      signal_summary = signal_summary(support, assessments)
      datasets = build_datasets(scope_resources, progress_tile, support, assessments)

      prompt_snapshot = %{
        scope: build_scope_summary(scope_resources, snapshot),
        signal_summary: signal_summary,
        progress_summary: progress_summary(progress_tile),
        student_support_summary: student_support_summary(support),
        assessments_summary: assessments_summary(assessments)
      }

      {:ok,
       %{
         request_token: snapshot.request_token,
         snapshot_version: snapshot.snapshot_version,
         projection_version: snapshot.projection_version,
         prompt_version: Prompt.version(),
         section_id: snapshot.metadata.dashboard_context_id,
         scope: build_scope_summary(scope_resources, snapshot),
         signal_summary: signal_summary,
         datasets: datasets,
         prompt_snapshot: prompt_snapshot
       }}
    end
  end

  defp build_datasets(scope_resources, progress_tile, support, assessments) do
    [
      build_scope_dataset(scope_resources),
      build_progress_dataset(progress_tile),
      build_student_support_dataset(support),
      build_assessments_dataset(assessments)
    ]
  end

  defp build_scope_dataset(scope_resources) do
    descriptor =
      "Scope overview for the selected instructor dashboard context, including the course title, current scope label, and the first curriculum items inside scope."

    titles_preview =
      scope_resources
      |> Map.get(:items, [])
      |> Enum.take(@max_scope_item_titles)
      |> Enum.map(&Map.get(&1, :title))
      |> Enum.reject(&is_nil_or_blank/1)
      |> Enum.join(" | ")

    %{
      key: :scope_overview,
      descriptor: descriptor,
      columns: ["course_title", "scope_label", "scope_type", "items_in_scope", "titles_preview"],
      rows: [
        [
          Map.get(scope_resources, :course_title, "Unknown Course"),
          Map.get(scope_resources, :scope_label, "Selected Scope"),
          scope_type(scope_resources),
          scope_resources |> Map.get(:items, []) |> length(),
          titles_preview
        ]
      ]
    }
  end

  defp build_progress_dataset(progress_tile) do
    descriptor =
      "Progress coverage across the scoped curriculum, expressed as how many students have reached the completion threshold for each visible item."

    rows =
      progress_tile
      |> Map.get(:series_all, [])
      |> Enum.take(@max_progress_rows)
      |> Enum.map(fn item ->
        [
          Map.get(item, :label, "Untitled"),
          Map.get(item, :resource_type, :unknown),
          Map.get(item, :count, 0),
          Map.get(item, :percent, 0.0)
        ]
      end)

    %{
      key: :progress_coverage,
      descriptor: descriptor,
      columns: ["label", "resource_type", "completed_students", "completed_pct"],
      rows: rows
    }
  end

  defp build_student_support_dataset(support) do
    descriptor =
      "Aggregated student-support buckets summarizing how many learners are struggling, on track, excelling, or lacking enough information, without including individual identities."

    rows =
      support
      |> Map.get(:buckets, [])
      |> Enum.map(fn bucket ->
        [
          Map.get(bucket, :label, "Unknown"),
          Map.get(bucket, :count, 0),
          Map.get(bucket, :pct, 0.0),
          Map.get(bucket, :active_count, 0),
          Map.get(bucket, :inactive_count, 0)
        ]
      end)

    %{
      key: :student_support,
      descriptor: descriptor,
      columns: ["bucket", "student_count", "student_pct", "active_count", "inactive_count"],
      rows: rows
    }
  end

  defp build_assessments_dataset(assessments) do
    descriptor =
      "Assessment completion and score signals for the current scope, using aggregated counts and summary metrics only."

    rows =
      assessments
      |> Map.get(:rows, [])
      |> Enum.take(@max_assessment_rows)
      |> Enum.map(fn row ->
        [
          Map.get(row, :title, "Untitled Assessment"),
          Map.get(row, :context_label, ""),
          row |> get_in([:completion, :completed_count]) || 0,
          row |> get_in([:completion, :total_students]) || 0,
          row |> get_in([:completion, :ratio]) |> ratio_to_pct(),
          row |> get_in([:metrics, :mean])
        ]
      end)

    %{
      key: :assessments,
      descriptor: descriptor,
      columns: [
        "assessment",
        "context_label",
        "completed_count",
        "total_students",
        "completion_pct",
        "mean_score"
      ],
      rows: rows
    }
  end

  defp build_scope_summary(scope_resources, snapshot) do
    %{
      course_title: Map.get(scope_resources, :course_title, "Unknown Course"),
      scope_label: Map.get(scope_resources, :scope_label, "Selected Scope"),
      container_type: snapshot.scope.container_type,
      container_id: snapshot.scope.container_id,
      items_in_scope: scope_resources |> Map.get(:items, []) |> length()
    }
  end

  defp signal_summary(support, assessments) do
    total_students = get_in(support, [:totals, :total_students]) || 0
    has_activity_data? = Map.get(support, :has_activity_data?, false)

    has_assessment_signal? =
      assessments
      |> Map.get(:rows, [])
      |> Enum.any?(fn row ->
        (row |> get_in([:completion, :completed_count]) || 0) > 0 or
          not is_nil(row |> get_in([:metrics, :mean]))
      end)

    reasons =
      []
      |> maybe_add_reason(total_students == 0, :no_students)
      |> maybe_add_reason(not has_activity_data?, :no_activity_data)
      |> maybe_add_reason(not has_assessment_signal?, :no_assessment_signal)

    %{
      state:
        if(total_students == 0 or (not has_activity_data? and not has_assessment_signal?),
          do: :no_signal,
          else: :ready
        ),
      total_students: total_students,
      has_activity_data?: has_activity_data?,
      has_assessment_signal?: has_assessment_signal?,
      reasons: reasons
    }
  end

  defp progress_summary(progress_tile) do
    top_items =
      progress_tile
      |> Map.get(:series_all, [])
      |> Enum.take(@max_progress_rows)
      |> Enum.map(fn item ->
        %{
          label: Map.get(item, :label, "Untitled"),
          resource_type: Map.get(item, :resource_type, :unknown),
          completed_students: Map.get(item, :count, 0),
          completed_pct: Map.get(item, :percent, 0.0)
        }
      end)

    %{
      axis_label: Map.get(progress_tile, :axis_label, "Course Content"),
      class_size: Map.get(progress_tile, :class_size, 0),
      completion_threshold: Map.get(progress_tile, :completion_threshold, 100),
      top_items: top_items
    }
  end

  defp student_support_summary(support) do
    %{
      totals: Map.get(support, :totals, %{}),
      has_activity_data?: Map.get(support, :has_activity_data?, false),
      buckets:
        support
        |> Map.get(:buckets, [])
        |> Enum.map(fn bucket ->
          %{
            label: Map.get(bucket, :label, "Unknown"),
            count: Map.get(bucket, :count, 0),
            pct: Map.get(bucket, :pct, 0.0),
            active_count: Map.get(bucket, :active_count, 0),
            inactive_count: Map.get(bucket, :inactive_count, 0)
          }
        end)
    }
  end

  defp assessments_summary(assessments) do
    %{
      total_rows: Map.get(assessments, :total_rows, 0),
      has_assessments?: Map.get(assessments, :has_assessments?, false),
      rows:
        assessments
        |> Map.get(:rows, [])
        |> Enum.take(@max_assessment_rows)
        |> Enum.map(fn row ->
          %{
            title: Map.get(row, :title, "Untitled Assessment"),
            context_label: Map.get(row, :context_label),
            completed_count: row |> get_in([:completion, :completed_count]) || 0,
            total_students: row |> get_in([:completion, :total_students]) || 0,
            completion_pct: row |> get_in([:completion, :ratio]) |> ratio_to_pct(),
            mean_score: row |> get_in([:metrics, :mean])
          }
        end)
    }
  end

  defp scope_type(%{scope_label: "Entire Course"}), do: :course
  defp scope_type(_scope_resources), do: :container

  defp ratio_to_pct(nil), do: 0.0
  defp ratio_to_pct(value) when is_float(value), do: Float.round(value * 100.0, 1)
  defp ratio_to_pct(value) when is_integer(value), do: value * 1.0

  defp maybe_add_reason(reasons, true, reason), do: reasons ++ [reason]
  defp maybe_add_reason(reasons, false, _reason), do: reasons

  defp is_nil_or_blank(nil), do: true
  defp is_nil_or_blank(value) when is_binary(value), do: String.trim(value) == ""
  defp is_nil_or_blank(_), do: false
end

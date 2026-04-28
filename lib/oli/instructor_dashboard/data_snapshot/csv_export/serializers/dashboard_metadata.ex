defmodule Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.DashboardMetadata do
  @moduledoc false

  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.Helpers

  @spec serialize(map(), map()) :: {:ok, binary()} | {:error, term()}
  def serialize(snapshot_bundle, dataset_spec) do
    export_request = Helpers.export_request(dataset_spec)
    summary_scope = Helpers.projection(snapshot_bundle, :summary, [:scope]) || %{}
    support_parameters = Helpers.student_support_parameters(snapshot_bundle)

    course_name =
      Map.get(export_request, :course_name) ||
        Map.get(export_request, "course_name") ||
        Map.get(summary_scope, :course_title) ||
        "Course"

    dashboard_scope =
      Map.get(export_request, :dashboard_scope_label) ||
        Map.get(export_request, :scope_label) ||
        Map.get(export_request, "dashboard_scope_label") ||
        Map.get(export_request, "scope_label") ||
        Map.get(summary_scope, :label) ||
        Helpers.scope_label(dataset_spec)

    rows = [
      ["course_name", course_name],
      ["course_section", Helpers.course_section(dataset_spec)],
      ["dashboard_scope", dashboard_scope],
      [
        "generated_at",
        Helpers.format_timestamp(
          Helpers.generated_at(dataset_spec),
          Helpers.timezone(dataset_spec)
        )
      ],
      ["time_zone", Helpers.timezone(dataset_spec)],
      ["completion_threshold", "#{Helpers.progress_threshold(dataset_spec)}%"],
      ["inactive_threshold", inactive_threshold(support_parameters)],
      ["struggling_proficiency", struggling_proficiency(support_parameters)],
      ["struggling_progress", struggling_progress(support_parameters)],
      ["excelling_proficiency", excelling_proficiency(support_parameters)],
      ["excelling_progress", excelling_progress(support_parameters)],
      ["proficiency_definition", Helpers.proficiency_definition(dataset_spec)],
      ["total_students", Integer.to_string(Helpers.total_students(snapshot_bundle))]
    ]

    Helpers.encode_csv(["field", "value"], rows)
  end

  defp inactive_threshold(parameters) do
    ">#{Map.get(parameters, :inactivity_days, 7)} days"
  end

  defp struggling_proficiency(parameters) do
    "≤ #{Map.get(parameters, :struggling_proficiency_lte, 40)}%"
  end

  defp struggling_progress(parameters) do
    low = Map.get(parameters, :struggling_progress_low_lt, 40)
    high = Map.get(parameters, :struggling_progress_high_gt, 80)

    "< #{low}% OR > #{high}%"
  end

  defp excelling_proficiency(parameters) do
    "≥ #{Map.get(parameters, :excelling_proficiency_gte, 80)}%"
  end

  defp excelling_progress(parameters) do
    "≥ #{Map.get(parameters, :excelling_progress_gte, 80)}%"
  end
end

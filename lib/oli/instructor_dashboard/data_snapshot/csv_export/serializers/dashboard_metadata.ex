defmodule Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.DashboardMetadata do
  @moduledoc false

  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.Helpers

  @spec serialize(map(), map()) :: {:ok, binary()} | {:error, term()}
  def serialize(snapshot_bundle, dataset_spec) do
    export_request = Helpers.export_request(dataset_spec)
    summary_scope = Helpers.projection(snapshot_bundle, :summary, [:scope])

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
          Map.get(export_request, :timezone) || Map.get(export_request, "timezone")
        )
      ],
      ["completion_threshold", "#{Helpers.progress_threshold(dataset_spec)}%"],
      ["proficiency_definition", Helpers.proficiency_definition(dataset_spec)],
      ["total_students", Integer.to_string(Helpers.total_students(snapshot_bundle))]
    ]

    Helpers.encode_csv(["field", "value"], rows)
  end
end

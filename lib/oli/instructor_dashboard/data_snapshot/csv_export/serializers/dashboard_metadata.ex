defmodule Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.DashboardMetadata do
  @moduledoc false

  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.Helpers

  @spec serialize(map(), map()) :: {:ok, binary()} | {:error, term()}
  def serialize(snapshot_bundle, dataset_spec) do
    rows = [
      ["course_name", Helpers.course_name(dataset_spec)],
      ["course_section", Helpers.course_section(dataset_spec)],
      ["dashboard_scope", Helpers.scope_label(dataset_spec)],
      ["generated_at", Helpers.format_timestamp(Helpers.generated_at(dataset_spec))],
      ["time_zone", Helpers.timezone(dataset_spec)],
      ["completion_threshold", "#{Helpers.progress_threshold(dataset_spec)}%"],
      ["proficiency_definition", Helpers.proficiency_definition(dataset_spec)],
      ["total_students", Integer.to_string(Helpers.total_students(snapshot_bundle))]
    ]

    Helpers.encode_csv(["field", "value"], rows)
  end
end

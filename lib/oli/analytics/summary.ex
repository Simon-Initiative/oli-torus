defmodule Oli.Analytics.Summary do

  alias Oli.Analytics.Summary.EvaluatedAttempt.AttemptGroup
  alias Oli.Analytics.Summary.XAPI.StatementFactory
  alias Oli.Analytics.XAPI.Uploader

  def process_summary_analytics(snapshot_attempt_summary, project_id, host_name) do

    AttemptGroup.from_attempt_summary(snapshot_attempt_summary, project_id, host_name)
    |> emit_xapi_events()
    |> update_project_resource_summaries()
    |> update_section_resource_summaries()
    |> update_section_response_summaries()

  end

  defp emit_xapi_events(attempt_group) do
    StatementFactory.to_statements(attempt_group)
    |> Enum.map(fn statement -> Uploader.upload(statement) end)

    attempt_group
  end

  defp update_project_resource_summaries(attempt_group) do
    attempt_group
  end

  defp update_section_resource_summaries(attempt_group) do
    attempt_group
  end

  defp update_section_response_summaries(attempt_group) do
    attempt_group
  end

end

defmodule Oli.Experiments.ClickHouseAnalytics do
  @moduledoc """
  ClickHouse-backed experiment analytics read contracts.
  """

  alias Oli.Analytics.ClickhouseAnalytics
  alias Oli.Experiments.Scope

  def experiment_event_counts(%Scope{} = scope, filters \\ %{}) do
    query =
      """
      SELECT
        experiment_id,
        experiment_uuid,
        decision_point_id,
        condition_id,
        condition_code,
        experiment_role,
        countDistinct(attribution_hash) AS count
      FROM #{experiment_attributions_table()}
      WHERE #{where_clause(scope, filters)}
      GROUP BY experiment_id, experiment_uuid, decision_point_id, condition_id, condition_code, experiment_role
      ORDER BY experiment_id, experiment_uuid, decision_point_id, condition_id, experiment_role
      """

    execute(query, "experiment event counts", scope, filters)
  end

  def experiment_assignment_share(%Scope{} = scope, filters \\ %{}) do
    query =
      """
      SELECT
        experiment_id,
        experiment_uuid,
        decision_point_id,
        condition_id,
        condition_code,
        countDistinct(attribution_hash) AS assignments
      FROM #{experiment_attributions_table()}
      WHERE #{where_clause(scope, Map.put(filters, :experiment_role, "assignment"))}
      GROUP BY experiment_id, experiment_uuid, decision_point_id, condition_id, condition_code
      ORDER BY experiment_id, experiment_uuid, decision_point_id, condition_id
      """

    execute(query, "experiment assignment share", scope, filters)
  end

  def experiment_reward_summary(%Scope{} = scope, filters \\ %{}) do
    query =
      """
      SELECT
        experiment_id,
        experiment_uuid,
        decision_point_id,
        condition_id,
        condition_code,
        countDistinct(attribution_hash) AS rewards,
        avg(reward_value) AS average_reward
      FROM #{experiment_attributions_table()}
      WHERE #{where_clause(scope, Map.put(filters, :experiment_role, "reward"))}
      GROUP BY experiment_id, experiment_uuid, decision_point_id, condition_id, condition_code
      ORDER BY experiment_id, experiment_uuid, decision_point_id, condition_id
      """

    execute(query, "experiment reward summary", scope, filters)
  end

  def experiment_data_quality(%Scope{} = scope, filters \\ %{}) do
    query =
      """
      SELECT
        experiment_id,
        experiment_uuid,
        decision_point_id,
        assignment_id,
        countIf(experiment_role = 'exposure') AS exposures,
        countIf(experiment_role = 'outcome') AS outcomes,
        countIf(experiment_role = 'reward') AS rewards
      FROM #{experiment_attributions_table()}
      WHERE #{where_clause(scope, filters)}
      GROUP BY experiment_id, experiment_uuid, decision_point_id, assignment_id
      HAVING exposures = 0 OR (outcomes > 0 AND rewards = 0)
      ORDER BY experiment_id, experiment_uuid, decision_point_id, assignment_id
      """

    execute(query, "experiment data quality", scope, filters)
  end

  defp execute(query, description, scope, filters) do
    metadata = %{
      project_id: scope.project_id,
      section_id: scope.section_id,
      publication_id: scope.publication_id,
      experiment_id: Map.get(filters, :experiment_id)
    }

    start_time = System.monotonic_time()

    case ClickhouseAnalytics.execute_query(query, description) do
      {:ok, _result} = ok ->
        emit_query_telemetry(:stop, start_time, metadata)
        ok

      {:error, reason} = error ->
        emit_query_telemetry(:exception, start_time, Map.put(metadata, :reason, reason))
        error
    end
  end

  defp emit_query_telemetry(event, start_time, metadata) do
    :telemetry.execute(
      [:oli, :experiments, :clickhouse, :query, event],
      %{count: 1, duration: System.monotonic_time() - start_time},
      reject_nil_values(metadata)
    )
  end

  defp where_clause(scope, filters) do
    [
      equals_clause("project_id", scope.project_id),
      equals_clause("section_id", scope.section_id),
      equals_clause("publication_id", scope.publication_id),
      equals_clause("experiment_id", Map.get(filters, :experiment_id)),
      string_clause("experiment_uuid", Map.get(filters, :experiment_uuid)),
      equals_clause("decision_point_id", Map.get(filters, :decision_point_id)),
      equals_clause("condition_id", Map.get(filters, :condition_id)),
      string_clause(
        "experiment_role",
        Map.get(filters, :experiment_role) || Map.get(filters, :role)
      ),
      string_clause("host_event_type", Map.get(filters, :host_event_type))
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" AND ")
  end

  defp equals_clause(_column, nil), do: nil
  defp equals_clause(column, value) when is_integer(value), do: "#{column} = #{value}"

  defp string_clause(_column, nil), do: nil

  defp string_clause(column, value) do
    "#{column} = '#{escape(value)}'"
  end

  defp escape(value) do
    value
    |> to_string()
    |> String.replace("'", "\\'")
  end

  defp reject_nil_values(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp experiment_attributions_table do
    ClickhouseAnalytics.raw_events_table()
    |> String.replace_suffix(".raw_events", ".experiment_attributions")
  end
end

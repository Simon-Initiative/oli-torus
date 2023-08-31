defmodule Oli.Analytics.Summary do

  alias Oli.Analytics.Summary.EvaluatedAttempt.{AttemptGroup}
  alias Oli.Analytics.Summary.XAPI.StatementFactory
  alias Oli.Analytics.XAPI.Uploader

  @fields "project_id, publication_id, section_id, user_id, resource_id, part_id, resource_type_id, num_correct, num_attempts, num_hints, num_first_attempts, num_first_attempts_correct"

  defp activity(pa) do
    [
      pa.activity_revision.resource_id,
      pa.part_id,
      Oli.Resources.ResourceType.get_id_by_type("activity")
    ]
  end

  defp objective(objective_id) do
    [
      objective_id,
      nil,
      Oli.Resources.ResourceType.get_id_by_type("objective")
    ]
  end

  defp page(page_id) do
    [
      page_id,
      nil,
      Oli.Resources.ResourceType.get_id_by_type("page")
    ]
  end

  defp counts(pa) do
    correct =  if pa.score == pa.out_of do 1 else 0 end

    [
      correct,
      1,
      length(pa.hints),
      if pa.attempt_number == 1 and pa.activity_attempt.attempt_number == 1 do 1 else 0 end,
      if pa.attempt_number == 1 and pa.activity_attempt.attempt_number == 1 do correct else 0 end
    ]
  end

  def process_summary_analytics(snapshot_attempt_summary, project_id, host_name) do

    AttemptGroup.from_attempt_summary(snapshot_attempt_summary, project_id, host_name)
    |> emit_xapi_events()
    |> upsert_resource_summaries()

  end

  defp emit_xapi_events(attempt_group) do
    StatementFactory.to_statements(attempt_group)
    |> Enum.map(fn statement -> Uploader.upload(statement) end)

    attempt_group
  end

  def upsert_resource_summaries(attempt_group) do

    assemble_proto_records(attempt_group)
    |> insert_as_temp_table()

    upsert_counts()
  end

  defp scope_builder_fns() do
    [
      # [project_id, publication_id, section_id, user_id]

      # Project-wide, agnostic of publications and sections
      fn ctx -> [ctx.project_id, nil, nil, nil] end,

      # Project-wide, but specific to a particular publication
      fn ctx -> [ctx.project_id, ctx.publication_id, nil, nil] end,

      # Course section speficic, agnostic of publication
      fn ctx -> [nil, nil, ctx.section_id, nil] end,

      # Course section specific, publication specific
      fn ctx -> [nil, ctx.publication_id, ctx.section_id, nil] end,

      # Student specific, publication agnostic
      fn ctx -> [nil, nil, ctx.section_id, ctx.user_id] end,

      # Student specific, publication specific
      fn ctx -> [nil, ctx.publication_id, ctx.section_id, ctx.user_id] end
    ]
  end

  defp insert_as_temp_table(proto_records) do

    data = Enum.map(proto_records, fn record ->
      "(#{Enum.join(record, ", ")})"
    end)

    sql = """
      CREATE TEMP TABLE batch_data AS
      SELECT * FROM (VALUES
        #{data}
      ) AS t(#{@fields});
    """

    Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

  end

  defp upsert_counts() do

    sql = """
      INSERT INTO resource_summary (#{@fields})
      SELECT #{@fields}
      FROM batch_data
      ON CONFLICT (project_id, publication_id, section_id, user_id, resource_id, resource_type_id, part_id)
      DO UPDATE SET
        num_correct = resource_summary.num_correct + EXCLUDED.num_correct,
        num_attempts = resource_summary.num_attempts + EXCLUDED.num_attempts,
        num_hints = resource_summary.num_hints + EXCLUDED.num_hints,
        num_first_attempts = resource_summary.num_first_attempts + EXCLUDED.num_first_attempts,
        num_first_attempts_correct = resource_summary.num_first_attempts_correct + EXCLUDED.num_first_attempts_correct;
    """

    Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

  end

  defp assemble_proto_records(attempt_group) do
    context = attempt_group.context

    # Create all activity focused proto-records.
    activity_proto_records = Enum.reduce(attempt_group.part_attempts, [], fn part_attempt, proto_records ->
      Enum.map(scope_builder_fns(), fn scope_builder_fn ->
        scope_builder_fn.(context) ++ activity(part_attempt) ++ counts(part_attempt)
      end)
      ++ proto_records
    end)

    # Objective proto-records
    objective_proto_records = Enum.reduce(attempt_group.part_attempts, %{}, fn part_attempt, map ->

      get_objectives(part_attempt)
      |> Enum.reduce(map, fn objective_id, map ->

          case Map.get(map, objective_id) do
            nil ->
              Map.put(map, objective_id, counts(part_attempt))

            existing ->
              updated = counts(part_attempt)
              |> Enum.zip(existing)
              |> Enum.map(fn {a, b} -> a + b end)

              Map.put(map, objective_id, updated)
          end
      end)
    end)
    |> Enum.map(fn {objective_id, counts} ->
      Enum.map(scope_builder_fns(), fn scope_builder_fn ->
        scope_builder_fn.(context) ++ objective(objective_id) ++ counts
      end)
    end)

    page_proto_records = Enum.reduce(attempt_group.part_attempts, [], fn part_attempt, totals ->
      counts(part_attempt)
      |> Enum.zip(totals)
      |> Enum.map(fn {a, b} -> a + b end)
    end)
    |> Enum.map(fn totals ->
      Enum.map(scope_builder_fns(), fn scope_builder_fn ->
        scope_builder_fn.(context) ++ page(attempt_group.resource_attempt.resource_id) ++ totals
      end)
    end)

    activity_proto_records ++ objective_proto_records ++ page_proto_records

  end

  defp get_objectives(part_attempt) do
    case part_attempt.activity_revision.objectives do
      nil -> []
      list when is_list(list) -> list
      map when is_map(map) -> Map.get(map, part_attempt.part_id, [])
    end
  end



end

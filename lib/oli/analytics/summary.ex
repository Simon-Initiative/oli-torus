defmodule Oli.Analytics.Summary do

  alias Oli.Analytics.Summary.{AttemptGroup, ResponseLabel}
  alias Oli.Analytics.Common.Pipeline
  alias Oli.Analytics.Summary.XAPI.StatementFactory
  alias Oli.Analytics.XAPI.{Uploader, StatementBundle}
  require Logger

  @resource_fields "project_id, publication_id, section_id, user_id, resource_id, part_id, resource_type_id, num_correct, num_attempts, num_hints, num_first_attempts, num_first_attempts_correct"
  @response_fields "project_id, publication_id, section_id, page_id, activity_id, resource_part_response_id, part_id, count"

  @doc """
  Executes the analytics pipeline for a given snapshot attempt summary. This will emit
  xAPI statements and upsert resource and response summary tables.

  Eventually, once snapshots are excised from the system, we will need a different entry
  point for this pipeline. In fact, we will likely relocate the xAPI statement generation
  at the point where individual parts, activities, and pages are evaluated, and then
  change this pipeline to use a more optimized query for powering the summary upserts.
  """
  def execute_analytics_pipeline(snapshot_attempt_summary, project_id, host_name) do

    try do

      Pipeline.init("SummaryAnalyticsPipeline")
      |> AttemptGroup.from_attempt_summary(snapshot_attempt_summary, project_id, host_name)
      |> emit_xapi_events()
      |> upsert_resource_summaries()
      |> upsert_response_summaries()
      |> Pipeline.all_done()

    rescue
      e -> Logger.error("Error executing SummaryAnalyticsPipeline: #{inspect(e)}")
    end

  end

  # From all of the part attempts, activity attempts, and resource attempt, construct and
  # emit a single xAPI statement bundle to S3.
  defp emit_xapi_events(%Pipeline{data: attempt_group} = pipeline) do

    pipeline = case StatementFactory.to_statements(attempt_group)
    |> Oli.Analytics.Common.to_jsonlines()
    |> produce_statement_bundle(attempt_group)
    |> Uploader.upload() do

      {:ok, _} ->
        pipeline

      {:error, error} ->
        Pipeline.add_error(pipeline, error)

    end

    Pipeline.step_done(pipeline, :xapi)

  end

  defp upsert_resource_summaries(%Pipeline{data: attempt_group} = pipeline) do

    proto_records = assemble_proto_records(attempt_group)

    pipeline = case Oli.Repo.transaction(fn ->
      insert_as_temp_table(proto_records, @resource_fields)
      |> upsert_counts()
      |> drop_temp_table()
    end) do

      {:ok, _} ->
        pipeline

      {:error, error} ->
        Pipeline.add_error(pipeline, error)

    end

    Pipeline.step_done(pipeline, :resource_summary)

  end

  defp upsert_response_summaries(%Pipeline{data: attempt_group} = pipeline) do

    # Read all activity registrations
    registered_activities = Oli.Activities.list_activity_registrations()
    |> Enum.reduce(%{}, fn activity_registration, map ->
      Map.put(map, activity_registration.id, activity_registration)
    end)

    pipeline = case Oli.Repo.transaction(fn ->
      part_attempt_tuples = upsert_responses(attempt_group.part_attempts, registered_activities)

      create_response_proto_records(attempt_group, part_attempt_tuples)
      |> insert_as_temp_table(@response_fields)
      |> upsert_response_counts()
      |> drop_temp_table()

      upsert_student_responses(attempt_group, part_attempt_tuples)

    end) do

      {:ok, _} ->
        pipeline

      {:error, error} ->
        Pipeline.add_error(pipeline, error)

    end

    Pipeline.step_done(pipeline, :resp)
  end

  defp upsert_student_responses(attempt_group, part_attempt_tuples) do

    values = Enum.map(part_attempt_tuples, fn {id, _} ->
      """
      (
        #{attempt_group.context.section_id},
        #{id},
        #{attempt_group.resource_attempt.resource_id},
        #{attempt_group.context.user_id}
      )
      """
    end)
    |> Enum.join(", ")

    sql = """
    INSERT INTO student_responses (section_id, resource_part_response_id, page_id, user_id)
    VALUES
      #{values}
    ON CONFLICT (section_id, resource_part_response_id, page_id, user_id)
    DO NOTHING;
    """

    Ecto.Adapters.SQL.query(Oli.Repo, sql, [])
  end

  defp create_response_proto_records(attempt_group, part_attempt_tuples) do
    Enum.reduce(part_attempt_tuples, [], fn {id, part_attempt}, proto_records ->
      Enum.map(response_scope_builder_fns(), fn scope_builder_fn ->
        scope_builder_fn.(attempt_group.context) ++ [
          attempt_group.resource_attempt.resource_id, part_attempt.activity_revision.resource_id, id, part_attempt.part_id, 1
        ]
      end)
      ++ proto_records
    end)
  end

  defp upsert_responses(part_attempts, registered_activities) do

    {values, params} =
      Enum.with_index(part_attempts)
      |> Enum.reduce({[], []}, fn {part_attempt, index}, {values, params} ->

        activity_type = Map.get(registered_activities, part_attempt.activity_revision.activity_type_id)
        %ResponseLabel{response: response, label: label} = ResponseLabel.build(part_attempt, activity_type.slug)

        values = ["(#{part_attempt.activity_revision.resource_id}, #{part_attempt.part_id}, $#{(index * 2) + 1}, $#{(index * 2) + 2})" | values]
        params = [response, label | params]

        {values, params}
    end)

    values = Enum.join(values, ", ")

    sql = """
    INSERT INTO resource_part_responses (resource_id, part_id, response, label)
    VALUES
      #{values}
    ON CONFLICT (resource_id, part_id, response)
    DO UPDATE SET label = EXCLUDED.label
    RETURNING id, resource_id, part_id;
    """

    {:ok, %{rows: rows}} = Ecto.Adapters.SQL.query(Oli.Repo, sql, params)

    part_attempt_by_resource_part = Enum.reduce(part_attempts, %{}, fn part_attempt, map ->
      Map.put(map, {part_attempt.activity_revision.resource_id, part_attempt.part_id}, part_attempt)
    end)

    Enum.map(rows, fn [id, resource_id, part_id] ->
      {id, Map.get(part_attempt_by_resource_part, {resource_id, part_id})}
    end)

  end

  defp resource_scope_builder_fns() do
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

  defp response_scope_builder_fns() do
    [
      # [project_id, publication_id, section_id]

      # Project-wide, agnostic of publications and sections
      fn ctx -> [ctx.project_id, nil, nil] end,

      # Project-wide, but specific to a particular publication
      fn ctx -> [ctx.project_id, ctx.publication_id, nil] end,

      # Course section speficic, agnostic of publication
      fn ctx -> [nil, nil, ctx.section_id] end,

      # Course section specific, publication specific
      fn ctx -> [nil, ctx.publication_id, ctx.section_id] end
    ]
  end

  defp produce_statement_bundle(json_lines_body, attempt_group) do
    %StatementBundle{
      partition: :section,
      partition_id: attempt_group.context.section_id,
      category: :attempt_evaluated,
      bundle_id: create_bundle_id(attempt_group),
      body: json_lines_body
    }
  end

  defp create_bundle_id(attempt_group) do
    guids = Enum.map(attempt_group.part_attempts, fn part_attempt ->
      part_attempt.attempt_guid
    end)
    |> Enum.join(",")

    :crypto.hash(:md5, guids)
    |> Base.encode16()
  end

  defp insert_as_temp_table(proto_records, table_fields) do

    unique_table_suffix = :crypto.strong_rand_bytes(8) |> Base.encode16()
    table_name = "batch_data_#{unique_table_suffix}"

    data = Enum.map(proto_records, fn record ->
      record = Enum.map(record, fn value ->
        case value do
          nil -> -1
          _ -> value
        end
      end)

      "(#{Enum.join(record, ", ")})"
    end)
    |> Enum.join(", ")

    sql = """
      CREATE TEMP TABLE #{table_name} AS
      SELECT * FROM (VALUES
        #{data}
      ) AS t(#{table_fields});
    """

    Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

    table_name

  end

  defp upsert_counts(table_name) do

    sql = """
      INSERT INTO resource_summary (#{@resource_fields})
      SELECT #{@resource_fields}
      FROM #{table_name}
      ON CONFLICT (project_id, publication_id, section_id, user_id, resource_id, resource_type_id, part_id)
      DO UPDATE SET
        num_correct = resource_summary.num_correct + EXCLUDED.num_correct,
        num_attempts = resource_summary.num_attempts + EXCLUDED.num_attempts,
        num_hints = resource_summary.num_hints + EXCLUDED.num_hints,
        num_first_attempts = resource_summary.num_first_attempts + EXCLUDED.num_first_attempts,
        num_first_attempts_correct = resource_summary.num_first_attempts_correct + EXCLUDED.num_first_attempts_correct;
    """

    Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

    table_name

  end

  defp upsert_response_counts(table_name) do

    sql = """
      INSERT INTO response_summary (#{@response_fields})
      SELECT #{@response_fields}
      FROM #{table_name}
      ON CONFLICT (project_id, publication_id, section_id, page_id, activity_id, resource_part_response_id, part_id)
      DO UPDATE SET
        count = response_summary.count + EXCLUDED.count;
    """

    Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

    table_name

  end

  defp drop_temp_table(table_name) do

    sql = """
      DROP TABLE #{table_name};
    """

    Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

  end



  defp assemble_proto_records(attempt_group) do
    context = attempt_group.context

    # Create all activity focused proto-records.
    activity_proto_records = Enum.reduce(attempt_group.part_attempts, [], fn part_attempt, proto_records ->
      Enum.map(resource_scope_builder_fns(), fn scope_builder_fn ->
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
    |> Enum.reduce([], fn {objective_id, counts}, all ->
      Enum.map(resource_scope_builder_fns(), fn scope_builder_fn ->
        scope_builder_fn.(context) ++ objective(objective_id) ++ counts
      end)
      ++ all
    end)

    aggregate_counts = Enum.reduce(attempt_group.part_attempts, [0, 0, 0, 0, 0], fn part_attempt, totals ->
      counts(part_attempt)
      |> Enum.zip(totals)
      |> Enum.map(fn {a, b} -> a + b end)
    end)

    page_proto_records = Enum.map(resource_scope_builder_fns(), fn scope_builder_fn ->
      scope_builder_fn.(context) ++ page(attempt_group.resource_attempt.resource_id) ++ aggregate_counts
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

end

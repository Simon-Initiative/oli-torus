defmodule Oli.Analytics.Summary do
  import Ecto.Query

  alias Oli.Analytics.Summary.{
    AttemptGroup,
    ResponseLabel,
    ResourceSummary,
    ResponseSummary,
    ResourcePartResponse,
    StudentResponse
  }

  alias Oli.Analytics.Common.Pipeline
  alias Oli
  alias Oli.Repo
  alias Oli.Resources.ResourceType

  require Logger

  @resource_fields "project_id, publication_id, section_id, user_id, resource_id, part_id, resource_type_id, num_correct, num_attempts, num_hints, num_first_attempts, num_first_attempts_correct"
  @response_fields "project_id, publication_id, section_id, page_id, activity_id, resource_part_response_id, part_id, count"

  @doc """
  Executes the analytics pipeline for a given snapshot attempt summary. This will produce
  the base AttemptGroup struct to upsert resource and response summary tables.
  After upserts are done, a new job is scheduled with S3 uploader worker (Oli.Delivery.Snapshots.S3UploaderWorker)
  that will contain the required data to emit an xAPI statement bundle.

  Eventually, once snapshots are excised from the system, we will need a different entry
  point for this pipeline. In fact, we will likely relocate the xAPI bundle generation
  at the point where individual parts, activities, and pages are evaluated, and then
  change this pipeline to use a more optimized query for powering the summary upserts.
  """
  def execute_analytics_pipeline(snapshot_attempt_summary, project_id, host_name) do
    Pipeline.init("SummaryAnalyticsPipeline")
    |> AttemptGroup.from_attempt_summary(snapshot_attempt_summary, project_id, host_name)
    |> upsert_resource_summaries()
    |> upsert_response_summaries()
    |> Pipeline.all_done()
  end

  # From all of the part attempts that were evaluated, upsert the appropriate records
  # into the resource summary table.
  def upsert_resource_summaries(%Pipeline{data: nil} = pipeline),
    do: Pipeline.step_done(pipeline, :resource_summary)

  def upsert_resource_summaries(%Pipeline{data: attempt_group, errors: []} = pipeline) do
    pipeline =
      case assemble_proto_records(attempt_group) |> upsert_counts() do
        {:ok, _} ->
          pipeline

        {:error, error} ->
          Pipeline.add_error(pipeline, error)
      end

    Pipeline.step_done(pipeline, :resource_summary)
  end

  def upsert_resource_summaries(pipeline), do: Pipeline.step_done(pipeline, :resource_summary)

  # From all of the part attempts that were evaluated, upsert the appropriate records
  # into the response summary table.
  def upsert_response_summaries(%Pipeline{data: nil} = pipeline),
    do: Pipeline.step_done(pipeline, :response_summary)

  def upsert_response_summaries(%Pipeline{data: attempt_group, errors: []} = pipeline) do
    # Read all activity registrations
    registered_activities =
      Oli.Activities.list_activity_registrations()
      |> Enum.reduce(%{}, fn activity_registration, map ->
        Map.put(map, activity_registration.id, activity_registration)
      end)

    pipeline =
      case Oli.Repo.transaction(fn ->
             part_attempt_tuples =
               upsert_responses(attempt_group.part_attempts, registered_activities)

             create_response_proto_records(attempt_group, part_attempt_tuples)
             |> upsert_response_counts()

             upsert_student_responses(attempt_group, part_attempt_tuples)
           end) do
        {:ok, _} ->
          pipeline

        {:error, error} ->
          Pipeline.add_error(pipeline, error)
      end

    Pipeline.step_done(pipeline, :response_summary)
  end

  def upsert_response_summaries(pipeline), do: Pipeline.step_done(pipeline, :response_summary)

  defp upsert_student_responses(attempt_group, part_attempt_tuples) do
    values =
      Enum.map(part_attempt_tuples, fn {id, _} ->
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
        scope_builder_fn.(attempt_group.context) ++
          [
            attempt_group.resource_attempt.resource_id,
            part_attempt.activity_revision.resource_id,
            id,
            "\'#{part_attempt.part_id}\'",
            1
          ]
      end) ++
        proto_records
    end)
  end

  defp upsert_responses(part_attempts, registered_activities) do
    {values, params} =
      Enum.with_index(part_attempts)
      |> Enum.reduce({[], []}, fn {part_attempt, index}, {values, params} ->
        activity_type =
          Map.get(registered_activities, part_attempt.activity_revision.activity_type_id)

        %ResponseLabel{response: response, label: label} =
          ResponseLabel.build(part_attempt, activity_type.slug)

        values = [
          "(#{part_attempt.activity_revision.resource_id}, \'#{part_attempt.part_id}\', $#{index * 2 + 1}, $#{index * 2 + 2})"
          | values
        ]

        params = params ++ [response, label]

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

    part_attempt_by_resource_part =
      Enum.reduce(part_attempts, %{}, fn part_attempt, map ->
        Map.put(
          map,
          {part_attempt.activity_revision.resource_id, part_attempt.part_id},
          part_attempt
        )
      end)

    Enum.map(rows, fn [id, resource_id, part_id] ->
      result = Map.get(part_attempt_by_resource_part, {resource_id, part_id})
      {id, result}
    end)
  end

  # For each part attempt that is being updated in the resource summary table, we need to
  # track data counts in serveral different "scopes".  This function returns a list of
  # functions that can be used to build the scope portion of the resource summary table
  # record upserts.
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

  # Similar to response summary scope builder, this function returns a list of functions
  # that build the scope portion of the response summary table record upserts.
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

  defp to_values(proto_records) do
    Enum.map(proto_records, fn record ->
      record =
        Enum.map(record, fn value ->
          case value do
            nil -> -1
            _ -> value
          end
        end)

      "(#{Enum.join(record, ", ")})"
    end)
    |> Enum.join(", ")
  end

  defp upsert_counts(proto_records) do
    data = to_values(proto_records)

    sql = """
      INSERT INTO resource_summary (#{@resource_fields})
      VALUES
      #{data}
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

  defp upsert_response_counts(proto_records) do
    data = to_values(proto_records)

    sql = """
      INSERT INTO response_summary (#{@response_fields})
      VALUES
      #{data}
      ON CONFLICT (project_id, publication_id, section_id, page_id, activity_id, resource_part_response_id, part_id)
      DO UPDATE SET
        count = response_summary.count + EXCLUDED.count;
    """

    Ecto.Adapters.SQL.query(Oli.Repo, sql, [])
  end

  defp assemble_proto_records(attempt_group) do
    context = attempt_group.context

    # Create all activity focused proto-records.
    activity_proto_records =
      Enum.reduce(attempt_group.part_attempts, [], fn part_attempt, proto_records ->
        Enum.map(resource_scope_builder_fns(), fn scope_builder_fn ->
          scope_builder_fn.(context) ++ activity(part_attempt) ++ counts(part_attempt)
        end) ++
          proto_records
      end)

    # Objective proto-records
    objective_proto_records =
      Enum.reduce(attempt_group.part_attempts, %{}, fn part_attempt, map ->
        get_objectives(part_attempt)
        |> Enum.reduce(map, fn objective_id, map ->
          case Map.get(map, objective_id) do
            nil ->
              Map.put(map, objective_id, counts(part_attempt))

            existing ->
              updated =
                counts(part_attempt)
                |> Enum.zip(existing)
                |> Enum.map(fn {a, b} -> a + b end)

              Map.put(map, objective_id, updated)
          end
        end)
      end)
      |> Enum.reduce([], fn {objective_id, counts}, all ->
        Enum.map(resource_scope_builder_fns(), fn scope_builder_fn ->
          scope_builder_fn.(context) ++ objective(objective_id) ++ counts
        end) ++
          all
      end)

    aggregate_counts =
      Enum.reduce(attempt_group.part_attempts, [0, 0, 0, 0, 0], fn part_attempt, totals ->
        counts(part_attempt)
        |> Enum.zip(totals)
        |> Enum.map(fn {a, b} -> a + b end)
      end)

    page_proto_records =
      Enum.map(resource_scope_builder_fns(), fn scope_builder_fn ->
        scope_builder_fn.(context) ++
          page(attempt_group.resource_attempt.resource_id) ++ aggregate_counts
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
      "\'#{pa.part_id}\'",
      Oli.Resources.ResourceType.id_for_activity()
    ]
  end

  defp objective(objective_id) do
    [
      objective_id,
      "\'unknown\'",
      Oli.Resources.ResourceType.id_for_objective()
    ]
  end

  defp page(page_id) do
    [
      page_id,
      "\'unknown\'",
      Oli.Resources.ResourceType.id_for_page()
    ]
  end

  defp counts(pa) do
    correct =
      if pa.score == pa.out_of do
        1
      else
        0
      end

    [
      correct,
      1,
      length(pa.hints),
      if pa.attempt_number == 1 and pa.activity_attempt.attempt_number == 1 do
        1
      else
        0
      end,
      if pa.attempt_number == 1 and pa.activity_attempt.attempt_number == 1 do
        correct
      else
        0
      end
    ]
  end

  def create_resource_summary(attrs \\ %{}) do
    %ResourceSummary{}
    |> ResourceSummary.changeset(attrs)
    |> Oli.Repo.insert()
  end

  def create_response_summary(attrs \\ %{}) do
    %ResponseSummary{}
    |> ResponseSummary.changeset(attrs)
    |> Oli.Repo.insert()
  end

  def create_resource_part_response(attrs \\ %{}) do
    %ResourcePartResponse{}
    |> ResourcePartResponse.changeset(attrs)
    |> Oli.Repo.insert()
  end

  def create_student_response(attrs \\ %{}) do
    %StudentResponse{}
    |> StudentResponse.changeset(attrs)
    |> Oli.Repo.insert()
  end

  def summarize_activities_for_page(section_id, page_id, only_for_activity_ids) do

    activity_constraint =
      case only_for_activity_ids do
        nil -> true
        _ -> dynamic([rs, _], rs.activity_id in ^only_for_activity_ids)
      end

    from(rs in ResponseSummary,
      join: s in ResourceSummary, on: rs.activity_id == s.resource_id and rs.section_id == s.section_id,
      where: rs.project_id == -1 and rs.publication_id == -1 and rs.section_id == ^section_id and rs.page_id == ^page_id,
      where: s.user_id != -1 and s.project_id == -1 and s.publication_id == -1,
      where: ^activity_constraint,
      select: s
    )
    |> Repo.all()
  end


  @doc """
  Counts the number of attempts made by a list of students for a given activity in a given section.
  """
  @spec count_student_attempts(
          activity_resource_id :: integer(),
          section_id :: integer(),
          student_ids :: [integer()]
        ) :: integer() | nil
  def count_student_attempts(activity_resource_id, section_id, student_ids) do
    page_type_id = ResourceType.get_id_by_type("activity")

    from(rs in ResourceSummary,
      where:
        rs.section_id == ^section_id and rs.resource_id == ^activity_resource_id and
          rs.user_id in ^student_ids and rs.project_id == -1 and rs.publication_id == -1 and
          rs.resource_type_id == ^page_type_id,
      select: sum(rs.num_attempts)
    )
    |> Repo.one()
  end

  @doc """
  Returns a list of response summaries for a given page resource id, section id, and activity resource ids.
  """
  @spec get_response_summary_for(
          page_resource_id :: integer(),
          section_id :: integer(),
          activity_resource_ids :: [integer()]
        ) :: [map()]
  def get_response_summary_for(page_resource_id, section_id, only_for_activity_ids \\ nil) do

    activity_constraint =
      case only_for_activity_ids do
        nil -> true
        _ -> dynamic([s, _], s.activity_id in ^only_for_activity_ids)
      end

    from(rs in ResponseSummary,
      join: rpp in ResourcePartResponse,
      on: rs.resource_part_response_id == rpp.id,
      left_join: sr in StudentResponse,
      on:
        rs.section_id == sr.section_id and rs.page_id == sr.page_id and
          rs.resource_part_response_id == sr.resource_part_response_id,
      left_join: u in Oli.Accounts.User,
      on: sr.user_id == u.id,
      where:
        rs.section_id == ^section_id and rs.page_id == ^page_resource_id and
          rs.publication_id == -1 and rs.project_id == -1,
      where: ^activity_constraint,
      select: %{
        part_id: rpp.part_id,
        response: rpp.response,
        count: rs.count,
        user: u,
        activity_id: rs.activity_id
      }
    )
    |> Repo.all()
  end

end

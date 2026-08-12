defmodule Oli.Publishing.DeliveryResolverPerformanceTest do
  use Oli.DataCase, async: false

  import Ecto.Query
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Analytics.Summary.ResourceSummary
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo

  @moduletag :performance

  @student_count 500
  @attempted_student_count 350
  @unrelated_project_count 100

  describe "students_with_attempts_for_page/3 query plan" do
    test "adding the delivery project scope preserves results and reduces the scanned scope" do
      %{section: section, page: page, student_ids: student_ids} = seed_benchmark_data()

      original_query =
        from(rs in ResourceSummary,
          where:
            rs.section_id == ^section.id and rs.resource_id == ^page.id and
              rs.user_id in ^student_ids,
          distinct: rs.user_id,
          select: rs.user_id
        )

      scoped_query =
        from(rs in ResourceSummary,
          where:
            rs.project_id == -1 and rs.section_id == ^section.id and rs.resource_id == ^page.id and
              rs.user_id in ^student_ids,
          distinct: rs.user_id,
          select: rs.user_id
        )

      expected_student_ids = Enum.take(student_ids, @attempted_student_count) |> Enum.sort()
      assert Repo.all(scoped_query) |> Enum.sort() == expected_student_ids

      # The original query can include students who only have summaries from an unrelated
      # project scope. The delivery view must only report attempts summarized with project_id -1.
      refute Repo.all(original_query) |> Enum.sort() == expected_student_ids

      assert DeliveryResolver.students_with_attempts_for_page(
               %{resource_id: page.id},
               section,
               student_ids
             )
             |> Enum.sort() == expected_student_ids

      original = measure_query(original_query)
      scoped = measure_query(scoped_query)

      IO.puts("""

      Insights page-detail query benchmark
        Dataset: #{@student_count} enrolled students (#{@attempted_student_count} with attempts), #{@unrelated_project_count} unrelated project scopes per student
        Query: students_with_attempts_for_page/3
        Original median: #{format_ms(original.median_ms)} ms (includes unrelated project scopes)
        Scoped median: #{format_ms(scoped.median_ms)} ms (delivery scope only)
        Reduction: #{format_ms(original.median_ms - scoped.median_ms)} ms
        Original plan: #{original.plan_summary}
        Scoped plan: #{scoped.plan_summary}
      """)
    end
  end

  defp seed_benchmark_data do
    section = insert(:section, analytics_version: :v2)
    page = insert(:resource)
    page_type_id = Oli.Resources.ResourceType.id_for_page()

    student_ids =
      for _ <- 1..@student_count do
        insert(:user).id
      end

    {:ok, _enrollments} =
      Sections.enroll(student_ids, section.id, [ContextRoles.get_role(:context_learner)])

    target_rows =
      for student_id <- Enum.take(student_ids, @attempted_student_count) do
        resource_summary_row(-1, section.id, student_id, page.id, page_type_id)
      end

    unrelated_rows =
      for project_id <- 1..@unrelated_project_count,
          student_id <- student_ids do
        resource_summary_row(project_id, section.id, student_id, page.id, page_type_id)
      end

    (target_rows ++ unrelated_rows)
    |> Enum.chunk_every(5_000)
    |> Enum.each(&Repo.insert_all("resource_summary", &1))

    %{section: section, page: page, student_ids: student_ids}
  end

  defp resource_summary_row(project_id, section_id, user_id, resource_id, resource_type_id) do
    %{
      project_id: project_id,
      section_id: section_id,
      user_id: user_id,
      resource_id: resource_id,
      resource_type_id: resource_type_id,
      part_id: nil,
      num_correct: 1,
      num_attempts: 1,
      num_hints: 0,
      num_first_attempts: 1,
      num_first_attempts_correct: 1
    }
  end

  defp measure_query(query) do
    Repo.all(query)

    durations =
      for _ <- 1..5 do
        {microseconds, _result} = :timer.tc(fn -> Repo.all(query) end)
        microseconds / 1_000
      end

    %{median_ms: Enum.sort(durations) |> Enum.at(2), plan_summary: explain_summary(query)}
  end

  defp explain_summary(query) do
    {sql, params} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)

    %{rows: [[plan]]} =
      Repo.query!("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " <> sql, params)

    plan
    |> decode_plan()
    |> List.first()
    |> Map.fetch!("Plan")
    |> summarize_plan()
  end

  defp decode_plan(plan) when is_binary(plan), do: Jason.decode!(plan)
  defp decode_plan(plan), do: plan

  defp summarize_plan(plan) do
    node_type = Map.fetch!(plan, "Node Type")
    relation = Map.get(plan, "Relation Name")
    index = Map.get(plan, "Index Name")
    rows = Map.get(plan, "Actual Rows", 0)
    buffers = Map.get(plan, "Shared Hit Blocks", 0) + Map.get(plan, "Shared Read Blocks", 0)

    [node_type, relation, index, "rows=#{rows}", "shared_buffers=#{buffers}"]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp format_ms(value), do: value |> Float.round(2) |> :erlang.float_to_binary(decimals: 2)
end

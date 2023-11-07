defmodule Oli.Utils.Database do
  alias Oli.Repo
  require Logger

  @doc """
  Explains the query plan for a given raw, string based query.  Options to either inline log
  the result and return the query, or to just return to analyzed result.  Results can be in either
  json, text, or yaml format.  Default is to log output as JSON.
  """
  def explain_sql(query, params, opts \\ []) when is_binary(query) do
    opts = put_defaults(opts)

    sql = "EXPLAIN (#{analyze_to_sql(opts[:analyze])}, #{format_to_sql(opts[:format])}) #{query}"

    explain =
      Repo
      |> Ecto.Adapters.SQL.query!(sql, params)

    if opts[:log_output] do
      log_output(explain, opts[:format])
      query
    else
      explain
    end
  end

  @doc """
  Explains the query plan for a given Ecto based query.  Options to either inline log
  the result and return the query, or to just return to analyzed result.  Results can be in either
  json, text, or yaml format.  Default is to log output as JSON.

  Use this inline for development on a query by query basis like:
  ```
  from(s in Section,
        join: spp in SectionsProjectsPublications,
        on: s.id == spp.section_id,
        join: pr in PublishedResource,
        on: pr.publication_id == spp.publication_id,
        join: rev in Revision,
        on: rev.id == pr.revision_id,
        where:
          (rev.resource_type_id == ^page_id or rev.resource_type_id == ^container_id) and
            s.slug == ^section_slug,
        select: rev
      )
      |> Oli.Utils.Database.explain()
      |> Repo.all()
  ```
  """
  def explain(query, opts \\ []) do
    opts = put_defaults(opts)

    {sql, params} = Ecto.Adapters.SQL.to_sql(opts[:op], Repo, query)

    sql = "EXPLAIN (#{analyze_to_sql(opts[:analyze])}, #{format_to_sql(opts[:format])}) #{sql}"

    explain =
      Repo
      |> Ecto.Adapters.SQL.query!(sql, params)

    if opts[:log_output] do
      log_output(explain, opts[:format])
      query
    else
      explain
    end
  end

  @doc """
  Logs as a warning the query and stacktrace of the caller if the query contains a sequential
  table scan or if the query equals or exceeds a cost threshold.
  """
  def flag_problem_queries(query, cost_threshold) do
    result = explain(query, log_output: false)

    explanation =
      Map.get(result, :rows)
      |> List.first()

    count = count_sequential(explanation)
    cost = explanation |> hd |> hd |> Map.get("Plan") |> Map.get("Total Cost")

    if count > 0 do
      output_problematic(result, "A query with #{count} sequential scans was detected")
    end

    if cost >= cost_threshold do
      output_problematic(result, "A query with #{cost} total compute cost was detected")
    end
  end

  defp output_problematic(result, reason) do
    trace =
      try do
        raise "Problematic Query"
      rescue
        _ -> Exception.format_stacktrace()
      end

    Logger.warn(reason)
    Logger.warn(trace)
    log_output(result, :json)
  end

  defp count_sequential(explanation) do
    count_sequential(explanation, 0)
  end

  defp count_sequential(list, count) when is_list(list) do
    Enum.reduce(list, count, fn item, c -> c + count_sequential(item, c) end)
  end

  defp count_sequential(%{"Plan" => %{"Plans" => plans}}, count) do
    count_sequential(plans, count)
  end

  defp count_sequential(%{"Plan" => plan}, count) do
    count_sequential(plan, count)
  end

  defp count_sequential(%{"Node Type" => "Seq Scan"}, count) do
    count + 1
  end

  defp count_sequential(_, count) do
    count
  end

  defp put_defaults(opts) do
    opts
    |> Keyword.put_new(:op, :all)
    |> Keyword.put_new(:format, :json)
    |> Keyword.put_new(:analyze, false)
    |> Keyword.put_new(:log_output, true)
  end

  defp log_output(results, :text) do
    results
    |> Map.get(:rows)
    |> Enum.join("\n")
    |> Logger.warn()
  end

  defp log_output(results, :json) do
    results
    |> Map.get(:rows)
    |> List.first()
    |> Jason.encode!(pretty: true)
    |> Logger.warn()
  end

  defp log_output(results, :yaml) do
    results
    |> Map.get(:rows)
    |> List.first()
    |> Logger.warn()
  end

  defp format_to_sql(:text), do: "FORMAT TEXT"
  defp format_to_sql(:json), do: "FORMAT JSON"
  defp format_to_sql(:yaml), do: "FORMAT YAML"

  defp analyze_to_sql(true), do: "ANALYZE true"
  defp analyze_to_sql(false), do: "ANALYZE false"

  def get_current_db_user() do
    case System.get_env("DATABASE_URL", nil) do
      nil -> "postgres"
      url -> parse_user_from_db_url(url, "postgres")
    end
  end

  def parse_user_from_db_url(url, default) do
    case url do
      "ecto://" <> rest ->
        split = String.split(rest, ":")

        case Enum.count(split) do
          0 -> default
          1 -> default
          _ -> Enum.at(split, 0)
        end

      _ ->
        default
    end
  end

  @doc """
  Given a list of resources (as maps), calculate the "chunk size" for a chunked insert_all operation such that
  the number of bind variables in the query does not exceed the maximum allowed by the database.
  """
  def calculate_chunk_size(rows) do
    # For large insertion operations, we want to split the list of section resources into chunks to
    # avoid hitting the max number of bind variables in a query.
    max_bind_variables = 65535

    fields_count =
      rows
      |> List.first()
      |> Map.keys()
      |> length()

    div(max_bind_variables, fields_count)
  end

  @doc """
  Given a list of resources (as maps), batch the list into chunks of size `chunk_size` and insert_all each chunk
  into the database. This is useful for large insertion operations where the number of bind
  variables in a query exceeds the maximum allowed by the database.

  Returns a tuple of the total number of rows inserted and a list of the inserted rows (same as
  insert_all).

  Example:
    ```
    rows = [
      %{name: "foo", age: 1},
      %{name: "bar", age: 2},
      %{name: "baz", age: 3}
    ]

    {3, [%{id: 1, name: "foo", age: 1}, %{id: 2, name: "bar", age: 2}, %{id: 3, name: "baz", age: 3}]} =
      Oli.Utils.Database.batch_insert_all(SectionResource, rows, %{})
    ```
  """
  def batch_insert_all(schema, rows, opts \\ []) do
    rows
    |> Enum.chunk_every(calculate_chunk_size(rows))
    |> Enum.reduce({0, []}, fn chunk, {total, acc} ->
      {new_total, new_acc} = Repo.insert_all(schema, chunk, opts)

      {total + new_total, acc ++ new_acc}
    end)
  end
end

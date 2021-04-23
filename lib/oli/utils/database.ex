defmodule Oli.Utils.Database do
  alias Oli.Repo
  require Logger

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
end

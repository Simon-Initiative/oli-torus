defmodule Oli.Analytics.Backfill.Worker do
  @moduledoc """
  Oban worker responsible for executing ClickHouse backfill jobs.
  """

  use Oban.Worker,
    queue: :clickhouse_backfill,
    max_attempts: 3,
    unique: [fields: [:args, :worker], keys: [:run_id], period: 600]

  require Logger

  alias Oli.Analytics.Backfill
  alias Oli.Analytics.Backfill.BackfillRun
  alias Oli.Analytics.Backfill.QueryBuilder

  defp analytics_module do
    Application.get_env(:oli, :clickhouse_analytics_module, Oli.Analytics.ClickhouseAnalytics)
  end

  @impl true
  def timeout(_job), do: :timer.hours(12)

  @status_poll_attempts 24
  @status_poll_interval_ms 5_000

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"run_id" => run_id}}) do
    run = Backfill.get_run!(run_id)

    case ensure_runnable(run) do
      :ok ->
        execute_run(run)

      {:discard, reason} ->
        Logger.info("Discarding backfill run #{run.id}: #{reason}")
        {:discard, reason}
    end
  end

  defp execute_run(run) do
    case run.status do
      :optimizing ->
        resume_optimization(run)

      _ ->
        with {:ok, run} <- Backfill.ensure_query_id(run),
             {:ok, run} <- Backfill.transition_to(run, :running, %{error: nil}),
             {:ok, creds} <- Backfill.aws_credentials(),
             {:ok, outcome} <- dispatch(run, creds),
             :ok <- finalize_success(run, outcome) do
          :ok
        else
          {:error, reason} -> handle_failure(run, reason)
          other -> handle_failure(run, other)
        end
    end
  end

  defp ensure_runnable(%BackfillRun{status: status}) when status in [:pending, :failed], do: :ok

  defp ensure_runnable(%BackfillRun{status: status}) when status in [:completed, :cancelled] do
    {:discard, "run already #{status}"}
  end

  defp ensure_runnable(%BackfillRun{}), do: :ok

  defp dispatch(%BackfillRun{dry_run: true} = run, creds) do
    with {:ok, query} <- safe_query(fn -> QueryBuilder.dry_run_sql(run, creds) end) do
      desc = "clickhouse backfill dry run #{run.id}"

      case analytics_module().execute_query(
             query,
             desc,
             Keyword.merge(query_options(run), credential: :admin)
           ) do
        {:ok, response} -> {:ok, %{mode: :dry_run, response: response}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp dispatch(%BackfillRun{} = run, creds) do
    with {:ok, query} <- safe_query(fn -> QueryBuilder.insert_sql(run, creds) end) do
      desc = "clickhouse backfill #{run.id}"

      case analytics_module().execute_query(
             query,
             desc,
             Keyword.merge(query_options(run), credential: :admin)
           ) do
        {:ok, response} -> {:ok, %{mode: :insert, response: response}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp finalize_success(%BackfillRun{} = run, %{mode: :dry_run, response: response}) do
    metrics = extract_dry_run_metrics(response)

    metadata =
      run.metadata
      |> merge_metadata(%{
        "dry_run" => true,
        "dry_run_execution_time_ms" => Map.get(response, :execution_time_ms),
        "dry_run_raw_response" => Map.get(response, :body)
      })

    Backfill.transition_to(run, :completed, Map.merge(metrics, %{metadata: metadata}))
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp finalize_success(%BackfillRun{} = run, %{mode: :insert, response: response}) do
    case fetch_query_status(run.query_id) do
      {:ok, info} ->
        metrics = extract_metrics_from_status(info, response)

        metadata =
          run.metadata
          |> merge_metadata(%{
            "query_id" => run.query_id,
            "query_status" => Map.new(info, fn {k, v} -> {to_string(k), v} end)
          })

        attrs = Map.merge(metrics, %{metadata: metadata})

        maybe_finalize_insert_with_optimization(run, attrs)

      {:error, reason} ->
        Logger.warning(
          "Unable to fetch ClickHouse query status for #{run.query_id}: #{inspect(reason)}"
        )

        metadata =
          run.metadata
          |> merge_metadata(%{
            "query_id" => run.query_id,
            "query_status_error" => format_error(reason)
          })

        attrs = %{
          metadata: metadata,
          duration_ms: Map.get(response, :execution_time_ms)
        }

        maybe_finalize_insert_with_optimization(run, attrs)
    end
  end

  defp maybe_finalize_insert_with_optimization(%BackfillRun{} = run, attrs) do
    if Backfill.optimization_required?(run) do
      run
      |> start_and_run_optimization(attrs)
      |> case do
        {:ok, optimized_run} ->
          finalize_optimization(optimized_run, attrs)

        {:error, reason} ->
          {:error, reason}
      end
    else
      Backfill.transition_to(run, :completed, attrs)
      |> case do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp start_and_run_optimization(%BackfillRun{} = run, attrs) do
    query_id = Backfill.generate_optimization_query_id(run)

    with {:ok, run} <- Backfill.start_optimization(run, query_id, attrs),
         {:ok, _response} <- dispatch_optimization(run, query_id) do
      {:ok, run}
    end
  end

  defp finalize_optimization(%BackfillRun{} = run, attrs) do
    query_id = optimization_query_id(run)

    case fetch_query_status(query_id) do
      {:ok, %{status: :completed} = info} ->
        optimization =
          %{
            "query_id" => query_id,
            "query_status" => Map.new(info, fn {key, value} -> {to_string(key), value} end),
            "duration_ms" => info[:query_duration_ms]
          }

        Backfill.complete_optimization(run, optimization, attrs)
        |> case do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end

      {:ok, %{status: :failed} = info} ->
        error_message =
          info[:error] ||
            info[:exception] ||
            "Backfill optimization failed"

        optimization =
          %{
            "query_id" => query_id,
            "query_status" => Map.new(info, fn {key, value} -> {to_string(key), value} end),
            "duration_ms" => info[:query_duration_ms]
          }

        case Backfill.fail_optimization(run, error_message, optimization) do
          {:ok, _} -> {:error, error_message}
          {:error, changeset} -> {:error, {error_message, changeset}}
        end

      {:error, reason} ->
        error_message = format_error(reason)
        optimization = %{"query_id" => query_id, "query_status_error" => error_message}

        case Backfill.fail_optimization(run, error_message, optimization) do
          {:ok, _} -> {:error, error_message}
          {:error, changeset} -> {:error, {error_message, changeset}}
        end
    end
  end

  defp resume_optimization(%BackfillRun{} = run) do
    case optimization_query_id(run) do
      nil ->
        {:error, "Backfill optimization is missing a query identifier"}

      _query_id ->
        finalize_optimization(run, %{})
    end
  end

  defp dispatch_optimization(%BackfillRun{} = run, query_id) do
    with target_table <- QueryBuilder.sanitize_target_table!(run.target_table) do
      query = "OPTIMIZE TABLE #{target_table} FINAL"
      desc = "clickhouse backfill optimize #{run.id}"

      analytics_module().execute_query(
        query,
        desc,
        credential: :admin,
        headers: [{"X-ClickHouse-Query-Id", query_id}],
        query_params: %{"wait_end_of_query" => "1", "query_id" => query_id}
      )
    end
  rescue
    error in ArgumentError -> {:error, Exception.message(error)}
  end

  defp handle_failure(%BackfillRun{} = run, reason) do
    error_message = format_error(reason)

    Backfill.transition_to(run, :failed, %{error: error_message})
    |> case do
      {:ok, _} -> {:error, error_message}
      {:error, changeset} -> {:error, {error_message, changeset}}
    end
  end

  defp safe_query(builder) when is_function(builder, 0) do
    {:ok, builder.()}
  rescue
    error in ArgumentError -> {:error, Exception.message(error)}
  end

  defp fetch_query_status(query_id) do
    poll_query_status(query_id, 0)
  end

  defp poll_query_status(_query_id, attempt) when attempt >= @status_poll_attempts do
    {:error, :query_status_timeout}
  end

  defp poll_query_status(query_id, attempt) do
    case analytics_module().query_status(query_id, credential: :admin) do
      {:ok, %{status: status} = info} when status in [:completed, :failed] ->
        {:ok, info}

      {:ok, %{status: :running}} ->
        Process.sleep(@status_poll_interval_ms)
        poll_query_status(query_id, attempt + 1)

      {:error, reason} ->
        {:error, reason}

      other ->
        other
    end
  end

  defp extract_dry_run_metrics(%{parsed_body: %{"data" => [row | _]}}) do
    %{
      rows_read: parse_int(row["total_rows"]),
      bytes_read: parse_int(Map.get(row, "total_bytes")),
      rows_written: 0,
      bytes_written: 0
    }
  end

  defp extract_dry_run_metrics(_),
    do: %{rows_read: nil, bytes_read: nil, rows_written: 0, bytes_written: 0}

  defp extract_metrics_from_status(info, response) do
    %{
      rows_read: Map.get(info, :rows_read),
      rows_written: Map.get(info, :rows_written),
      bytes_read: Map.get(info, :bytes_read),
      bytes_written: Map.get(info, :bytes_written),
      duration_ms: Map.get(info, :query_duration_ms) || Map.get(response, :execution_time_ms)
    }
  end

  defp parse_int(nil), do: nil
  defp parse_int(value) when is_integer(value), do: value
  defp parse_int(value) when is_float(value), do: trunc(value)

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, _} -> parsed
      :error -> nil
    end
  end

  defp merge_metadata(existing, additions) do
    existing = existing || %{}

    additions
    |> Enum.reduce(existing, fn {key, value}, acc ->
      if is_nil(value) do
        acc
      else
        Map.put(acc, key, value)
      end
    end)
  end

  defp query_options(%BackfillRun{query_id: query_id, options: opts}) do
    headers = [{"X-ClickHouse-Query-Id", query_id}]

    params =
      opts
      |> normalize_value_map()
      |> Map.put("wait_end_of_query", "1")
      |> Map.put("query_id", query_id)

    [headers: headers, query_params: params]
  end

  defp normalize_value_map(opts) when is_map(opts) do
    Enum.reduce(opts, %{}, fn {key, value}, acc ->
      Map.put(acc, to_string(key), normalize_param_value(value))
    end)
  end

  defp normalize_value_map(_), do: %{}

  defp normalize_param_value(value) when is_binary(value), do: value
  defp normalize_param_value(value) when is_boolean(value), do: if(value, do: "1", else: "0")
  defp normalize_param_value(value) when is_integer(value), do: Integer.to_string(value)

  defp normalize_param_value(value) when is_float(value),
    do: :erlang.float_to_binary(value, [:compact])

  defp normalize_param_value(value), do: to_string(value)

  defp optimization_query_id(%BackfillRun{metadata: metadata}) when is_map(metadata) do
    case Map.get(metadata, "optimization") do
      optimization when is_map(optimization) -> Map.get(optimization, "query_id")
      _ -> nil
    end
  end

  defp optimization_query_id(_), do: nil

  defp format_error({:error, reason}), do: format_error(reason)
  defp format_error(%Ecto.Changeset{} = changeset), do: inspect(changeset)
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end

defmodule Oli.Release.PreviewQATools do
  @moduledoc "Synchronous preview QA release command dispatcher."

  alias Oli.PreviewQATools.Config
  alias Oli.Release.PreviewQATools.BundledScenarios
  alias Oli.Release.PreviewQATools.ProjectIngest
  alias Oli.Scenarios
  alias Oli.Scenarios.ReleaseExecution

  require Logger

  @usage "usage: seed scenarios list | seed scenarios run (--name ID | --file PATH) | seed projects ingest --url URL --author SELECTOR"
  @max_message 500
  @max_scenario_bytes 5_000_000
  @project_ingest_options [url: :string, author: :string]

  def main(args) do
    args
    |> normalize_release_args()
    |> dispatch()
    |> print_result()
    |> System.halt()
  end

  defp normalize_release_args(["--" | args]), do: args
  defp normalize_release_args(args), do: args

  def dispatch(args, opts \\ []) when is_list(args) do
    enabled? = Keyword.get(opts, :enabled?, Config.enabled?())
    started_at = System.monotonic_time(:millisecond)

    result =
      if enabled? do
        execute(args, opts)
      else
        {:error, :disabled, "preview QA tools are disabled", false}
      end

    format_result(result, started_at)
  end

  defp execute(["scenarios", "list"], _opts) do
    {:ok, :list, BundledScenarios.list(), false}
  end

  defp execute(["scenarios", "run" | args], opts) do
    with {:ok, source} <- parse_run_args(args),
         {:ok, metadata, path} <- resolve_source(source, opts) do
      run_scenario(path, metadata)
    end
  end

  defp execute(["projects", "ingest" | args], opts) do
    with {:ok, url, author} <- parse_project_ingest_args(args) do
      ProjectIngest.run(url, author, opts)
    end
  end

  defp execute(_, _opts), do: {:error, :usage, @usage, false}

  defp parse_run_args(["--name", id]) when id != "", do: {:ok, {:name, id}}
  defp parse_run_args(["--file", path]) when path != "", do: {:ok, {:file, path}}
  defp parse_run_args(_), do: {:error, :usage, @usage, false}

  defp parse_project_ingest_args(args) do
    with {options, [], []} <- OptionParser.parse(args, strict: @project_ingest_options),
         option_count when option_count == length(@project_ingest_options) <-
           recognized_option_count(args),
         {:ok, url} when url != "" <- Keyword.fetch(options, :url),
         {:ok, author} when author != "" <- Keyword.fetch(options, :author) do
      {:ok, url, author}
    else
      _ -> {:error, :usage, @usage, false}
    end
  end

  defp recognized_option_count(args) do
    switches = Enum.map(@project_ingest_options, fn {name, _type} -> "--#{name}" end)

    Enum.count(args, fn argument ->
      Enum.any?(switches, &(argument == &1 or String.starts_with?(argument, &1 <> "=")))
    end)
  end

  defp resolve_source({:name, id}, opts) do
    registry = Keyword.get(opts, :registry, BundledScenarios)

    case registry.fetch(id) do
      {:ok, metadata, path} ->
        {:ok, metadata, path}

      {:error, :unknown_scenario} ->
        {:error, :not_found, "unknown bundled scenario", false}

      {:error, :invalid_asset} ->
        {:error, :invalid_asset, "bundled scenario integrity check failed", false}
    end
  end

  defp resolve_source({:file, path}, _opts) do
    expanded = Path.expand(path)

    case File.stat(expanded) do
      {:ok, %{type: :regular, size: size}} when size <= @max_scenario_bytes ->
        digest = :crypto.hash(:sha256, File.read!(expanded)) |> Base.encode16(case: :lower)
        {:ok, %{"source" => "file", "digest" => digest}, expanded}

      {:ok, %{type: :regular}} ->
        {:error, :input_too_large, "scenario file exceeds the 5000000 byte limit", false}

      _ ->
        {:error, :not_found, "scenario file was not found", false}
    end
  end

  defp run_scenario(path, metadata) do
    with {:ok, directives} <- parse_scenario(path),
         {:ok, result} <- execute_scenario(directives, path) do
      summary = Scenarios.summarize(result)

      if Scenarios.has_errors?(result) or not Scenarios.all_verifications_passed?(result) do
        {:error, :scenario_failed, summary, true, metadata}
      else
        {:ok, :run, summary, true, metadata}
      end
    else
      {:error, :parse_failed} ->
        {:error, :parse_failed, "scenario parsing failed", false, metadata}

      {:error, :execution_failed} ->
        {:error, :execution_failed, "scenario execution failed", true, metadata}
    end
  end

  defp parse_scenario(path) do
    {:ok, ReleaseExecution.parse_file(path)}
  rescue
    error ->
      Logger.error("Release scenario parsing failed: #{inspect(error.__struct__)}")
      {:error, :parse_failed}
  end

  defp execute_scenario(directives, path) do
    {:ok, ReleaseExecution.execute(directives, path)}
  rescue
    error ->
      Logger.error("Release scenario execution failed: #{inspect(error.__struct__)}")
      {:error, :execution_failed}
  catch
    kind, _reason ->
      Logger.error("Release scenario execution terminated: #{kind}")
      {:error, :execution_failed}
  end

  defp format_result(result, started_at) do
    duration_ms = max(System.monotonic_time(:millisecond) - started_at, 0)

    case result do
      {:ok, :list, scenarios, _} ->
        %{status: 0, output: format_list(scenarios), result_code: "ok", duration_ms: duration_ms}

      {:ok, :run, summary, partial, metadata} ->
        success("run", summary, partial, metadata, duration_ms)

      {:ok, :project_ingest, summary, partial, metadata} ->
        success("project_ingest", summary, partial, metadata, duration_ms)

      {:error, code, detail, partial} ->
        failure(code, detail, partial, %{}, duration_ms)

      {:error, code, detail, partial, metadata} ->
        failure(code, detail, partial, metadata, duration_ms)
    end
  end

  defp success(operation, summary, partial, metadata, duration_ms) do
    fields = fields(operation, "ok", summary, partial, metadata, duration_ms)
    %{status: 0, output: encode(fields), result_code: "ok", duration_ms: duration_ms}
  end

  defp failure(code, detail, partial, metadata, duration_ms) do
    fields =
      fields("command", Atom.to_string(code), bounded(detail), partial, metadata, duration_ms)

    %{
      status: exit_code(code),
      output: encode(fields),
      result_code: Atom.to_string(code),
      duration_ms: duration_ms
    }
  end

  defp fields(operation, code, detail, partial, metadata, duration_ms) do
    %{
      operation: operation,
      result_code: code,
      duration_ms: duration_ms,
      partial_mutations_possible: partial,
      source: metadata["source"] || if(metadata["id"], do: "bundled", else: nil),
      identifier: metadata["id"],
      digest: metadata["digest"],
      result: detail
    }
  end

  defp format_list(scenarios) do
    scenarios
    |> Enum.map(fn item ->
      Enum.join([item["id"], item["version"] || item["digest"], item["description"]], "\t")
    end)
    |> Enum.join("\n")
  end

  defp bounded(value) when is_binary(value), do: String.slice(value, 0, @max_message)
  defp bounded(value) when is_map(value), do: value
  defp bounded(_), do: "command failed"

  defp encode(fields), do: Jason.encode!(fields)

  defp exit_code(:usage), do: 64
  defp exit_code(:disabled), do: 77
  defp exit_code(:not_found), do: 66
  defp exit_code(_), do: 1

  defp print_result(%{status: status, output: output}) do
    device = if status == 0, do: :stdio, else: :stderr
    IO.puts(device, output)
    status
  end
end

defmodule Oli.Authoring.ProjectRepair.Instrumentation do
  @moduledoc """
  Emits bounded operational telemetry and logs for project repair operations.

  This module deliberately receives only public return values and compact options.
  It never receives page content, page titles, activity bodies, raw exceptions, or
  full reports, so observability cannot accidentally expose authored course data.
  All emitters are best-effort: telemetry handlers or logger failures must not
  change the result returned by the repair context.
  """

  require Logger

  alias Oli.Accounts.Author
  alias Oli.Authoring.Course.Project

  alias Oli.Authoring.ProjectRepair.{
    RepairFailure,
    RepairResult,
    Report,
    Summary
  }

  @telemetry_prefix [:oli, :authoring, :project_repair]

  @typedoc "Public operation names emitted as part of the telemetry event path."
  @type operation :: :analysis | :repair

  @doc """
  Captures the monotonic start time used by `record/5`.

  Keeping the start time outside the operation avoids a wrapper that could alter
  control flow. The public context computes the result normally, then calls
  `record/5` with this value.
  """
  @spec start_time() :: integer()
  def start_time, do: System.monotonic_time()

  @doc """
  Emits a stop event and one bounded completion log.

  Metadata is intentionally scalar and count-oriented so AppSignal and log
  consumers can group outcomes without seeing authored content. The returned value
  is always the original `result`, even if an attached telemetry handler raises.
  """
  @spec record(
          operation(),
          integer(),
          term(),
          Project.t() | String.t(),
          Author.t() | term(),
          map()
        ) ::
          term()
  def record(operation, started_at, result, project_ref, actor, options)
      when operation in [:analysis, :repair] do
    base_metadata = base_metadata(operation, project_ref, actor, options)

    final_metadata =
      result
      |> result_metadata()
      |> Map.merge(base_metadata)

    duration_ms =
      System.monotonic_time()
      |> Kernel.-(started_at)
      |> System.convert_time_unit(:native, :millisecond)

    safe_telemetry_execute(
      operation,
      :stop,
      %{count: 1, duration_ms: duration_ms},
      final_metadata
    )

    safe_log(operation, final_metadata, duration_ms)

    result
  end

  defp base_metadata(operation, project_ref, actor, options) do
    %{
      operation: operation,
      project_id: project_id(project_ref),
      project_slug: project_slug(project_ref),
      actor_id: actor_id(actor),
      stream_max_rows: Map.get(options, :stream_max_rows),
      resolution_batch_size: Map.get(options, :resolution_batch_size)
    }
  end

  defp result_metadata({:ok, %Report{} = report}) do
    report
    |> summary_metadata()
    |> Map.merge(%{
      status: :completed,
      failure_stage: nil,
      failure_reason: nil,
      cloned_activity_count: 0,
      updated_page_count: 0,
      failure_count: 0,
      warning_count: 0
    })
  end

  defp result_metadata({:ok, %RepairResult{} = result}) do
    failure = List.first(result.failures)

    result.report_after_repair
    |> summary_metadata()
    |> Map.merge(%{
      status: result.status,
      failure_stage: failure_stage(failure),
      failure_reason: failure_reason(failure),
      cloned_activity_count: result.cloned_activity_count,
      updated_page_count: result.updated_page_count,
      failure_count: length(result.failures),
      warning_count: length(result.warnings)
    })
  end

  defp result_metadata({:error, reason}) do
    empty_summary_metadata()
    |> Map.merge(%{
      status: :failed,
      failure_stage: :context,
      failure_reason: normalize_reason(reason),
      cloned_activity_count: 0,
      updated_page_count: 0,
      failure_count: 1,
      warning_count: 0
    })
  end

  defp result_metadata(_other) do
    empty_summary_metadata()
    |> Map.merge(%{
      status: :failed,
      failure_stage: :context,
      failure_reason: :unexpected_result,
      cloned_activity_count: 0,
      updated_page_count: 0,
      failure_count: 1,
      warning_count: 0
    })
  end

  defp summary_metadata(%Report{summary: %Summary{} = summary}) do
    %{
      scanned_pages_count: summary.scanned_pages_count,
      skipped_adaptive_pages_count: summary.skipped_adaptive_pages_count,
      missing_activity_reference_count: summary.missing_activity_reference_count,
      missing_activity_affected_page_count: summary.missing_activity_affected_page_count,
      repairable_shared_activity_resource_count:
        summary.repairable_shared_activity_resource_count,
      repairable_shared_activity_affected_page_count:
        summary.repairable_shared_activity_affected_page_count,
      non_repairable_shared_missing_activity_resource_count:
        summary.non_repairable_shared_missing_activity_resource_count
    }
  end

  defp summary_metadata(_report), do: empty_summary_metadata()

  defp empty_summary_metadata do
    %{
      scanned_pages_count: 0,
      skipped_adaptive_pages_count: 0,
      missing_activity_reference_count: 0,
      missing_activity_affected_page_count: 0,
      repairable_shared_activity_resource_count: 0,
      repairable_shared_activity_affected_page_count: 0,
      non_repairable_shared_missing_activity_resource_count: 0
    }
  end

  defp safe_telemetry_execute(operation, phase, measurements, metadata) do
    try do
      :telemetry.execute(@telemetry_prefix ++ [operation, phase], measurements, metadata)
    rescue
      _exception -> :ok
    catch
      _kind, _reason -> :ok
    end
  end

  defp safe_log(operation, metadata, duration_ms) do
    log_metadata = Map.put(metadata, :duration_ms, duration_ms)

    try do
      Logger.log(
        log_level(metadata),
        "project_repair #{operation} completed #{inspect(log_metadata)}"
      )
    rescue
      _exception -> :ok
    catch
      _kind, _reason -> :ok
    end
  end

  defp log_level(%{status: :completed, warning_count: 0}), do: :info
  defp log_level(%{failure_stage: :lock}), do: :warning
  defp log_level(%{failure_stage: :stale_plan}), do: :warning
  defp log_level(%{status: :partial}), do: :warning
  defp log_level(%{failure_count: count}) when count > 0, do: :error
  defp log_level(_metadata), do: :info

  defp project_id(%Project{id: id}), do: id
  defp project_id(_project_ref), do: nil

  defp project_slug(%Project{slug: slug}), do: slug
  defp project_slug(_project_ref), do: nil

  defp actor_id(%Author{id: id}), do: id
  defp actor_id(_actor), do: nil

  defp failure_stage(%RepairFailure{stage: stage}), do: stage
  defp failure_stage(_failure), do: nil

  defp failure_reason(%RepairFailure{reason: reason}), do: reason
  defp failure_reason(_failure), do: nil

  defp normalize_reason(reason) when is_atom(reason), do: reason
  defp normalize_reason({reason, _detail}) when is_atom(reason), do: reason
  defp normalize_reason(_reason), do: :unknown
end

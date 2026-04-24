defmodule Oli.GenAI.AdaptiveContextTelemetry do
  @moduledoc """
  Telemetry helpers and AppSignal metric wiring for adaptive DOT context.
  """

  use Supervisor

  @tool_exposed_event [:oli, :genai, :adaptive_context, :tool_exposed]
  @tool_called_event [:oli, :genai, :adaptive_context, :tool_called]
  @build_succeeded_event [:oli, :genai, :adaptive_context, :build_succeeded]
  @build_failed_event [:oli, :genai, :adaptive_context, :build_failed]

  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    :ok = attach_appsignal_handler()
    Supervisor.init([], strategy: :one_for_one)
  end

  @spec events() :: [list(atom())]
  def events do
    [
      @tool_exposed_event,
      @tool_called_event,
      @build_succeeded_event,
      @build_failed_event
    ]
  end

  def tool_exposed(metadata \\ %{}) do
    emit_count(@tool_exposed_event, metadata)
  end

  def tool_called(metadata \\ %{}) do
    emit_count(@tool_called_event, metadata)
  end

  def build_succeeded(duration_ms, metadata \\ %{}) do
    measurements = %{
      count: 1,
      duration_ms: normalize_duration(duration_ms),
      visited_screen_count: normalize_count(metadata[:visited_screen_count]),
      unvisited_screen_count: normalize_count(metadata[:unvisited_screen_count])
    }

    :telemetry.execute(@build_succeeded_event, measurements, sanitize_metadata(metadata))
  end

  def build_failed(duration_ms, metadata \\ %{}) do
    measurements = %{count: 1, duration_ms: normalize_duration(duration_ms)}
    :telemetry.execute(@build_failed_event, measurements, sanitize_metadata(metadata))
  end

  def handle_event(@tool_exposed_event, measurements, metadata, _config) do
    increment_counter("oli.genai.adaptive_context.tool_exposed", measurements, metadata)
  end

  def handle_event(@tool_called_event, measurements, metadata, _config) do
    increment_counter("oli.genai.adaptive_context.tool_called", measurements, metadata)
  end

  def handle_event(@build_succeeded_event, measurements, metadata, _config) do
    tags = metric_tags(metadata)
    duration_ms = Map.get(measurements, :duration_ms, 0)

    Appsignal.add_distribution_value(
      "oli.genai.adaptive_context.build.duration_ms",
      duration_ms,
      tags
    )

    Appsignal.add_distribution_value(
      "oli.genai.adaptive_context.visited_screen_count",
      Map.get(measurements, :visited_screen_count, 0),
      tags
    )

    Appsignal.add_distribution_value(
      "oli.genai.adaptive_context.unvisited_screen_count",
      Map.get(measurements, :unvisited_screen_count, 0),
      tags
    )

    Appsignal.increment_counter("oli.genai.adaptive_context.build_succeeded", 1, tags)
  end

  def handle_event(@build_failed_event, measurements, metadata, _config) do
    tags = metric_tags(metadata)
    duration_ms = Map.get(measurements, :duration_ms, 0)

    Appsignal.add_distribution_value(
      "oli.genai.adaptive_context.build.duration_ms",
      duration_ms,
      tags
    )

    Appsignal.increment_counter("oli.genai.adaptive_context.build_failed", 1, tags)
  end

  def handle_event(_, _, _, _), do: :ok

  defp emit_count(event, metadata) do
    :telemetry.execute(event, %{count: 1}, sanitize_metadata(metadata))
  end

  defp increment_counter(metric, measurements, metadata) do
    Appsignal.increment_counter(metric, Map.get(measurements, :count, 1), metric_tags(metadata))
  end

  defp metric_tags(metadata) do
    %{
      reason: normalize(metadata[:reason])
    }
  end

  defp sanitize_metadata(metadata) when is_list(metadata),
    do: metadata |> Map.new() |> sanitize_metadata()

  defp sanitize_metadata(metadata) when is_map(metadata) do
    %{
      section_id: metadata |> metadata_value(:section_id) |> normalize_integer(),
      resource_attempt_id:
        metadata |> metadata_value(:resource_attempt_id) |> normalize_integer(),
      page_revision_id: metadata |> metadata_value(:page_revision_id) |> normalize_integer(),
      reason: metadata |> metadata_value(:reason) |> normalize_reason()
    }
  end

  defp sanitize_metadata(_),
    do: %{
      section_id: nil,
      resource_attempt_id: nil,
      page_revision_id: nil,
      reason: nil
    }

  defp normalize_duration(duration_ms) when is_integer(duration_ms) and duration_ms >= 0,
    do: duration_ms

  defp normalize_duration(_), do: 0

  defp metadata_value(metadata, key) do
    Map.get(metadata, key, Map.get(metadata, Atom.to_string(key)))
  end

  defp normalize_count(count) when is_integer(count) and count >= 0, do: count
  defp normalize_count(_), do: 0

  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> parsed
      _ -> nil
    end
  end

  defp normalize_integer(_), do: nil

  defp normalize_reason(value) when is_atom(value), do: value
  defp normalize_reason(value) when is_binary(value), do: value
  defp normalize_reason(_), do: nil
  defp normalize(nil), do: "unknown"
  defp normalize(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize(value) when is_binary(value), do: value
  defp normalize(value), do: to_string(value)

  defp attach_appsignal_handler do
    handler_id = "genai-adaptive-context-appsignal-handler"

    case :telemetry.attach_many(handler_id, events(), &__MODULE__.handle_event/4, %{}) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end
end

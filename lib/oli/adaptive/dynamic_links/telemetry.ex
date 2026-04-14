defmodule Oli.Adaptive.DynamicLinks.Telemetry do
  @moduledoc """
  Telemetry helpers and AppSignal metric wiring for adaptive dynamic links.
  """

  use Supervisor

  @created_event [:oli, :adaptive, :dynamic_link, :created]
  @updated_event [:oli, :adaptive, :dynamic_link, :updated]
  @removed_event [:oli, :adaptive, :dynamic_link, :removed]
  @resolved_event [:oli, :adaptive, :dynamic_link, :resolved]
  @resolution_failed_event [:oli, :adaptive, :dynamic_link, :resolution_failed]
  @broken_clicked_event [:oli, :adaptive, :dynamic_link, :broken_clicked]
  @delete_blocked_event [:oli, :adaptive, :dynamic_link, :delete_blocked]

  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    :ok = attach_appsignal_handler()
    Supervisor.init([], strategy: :one_for_one)
  end

  @spec events() :: [list(atom())]
  def events do
    [
      @created_event,
      @updated_event,
      @removed_event,
      @resolved_event,
      @resolution_failed_event,
      @broken_clicked_event,
      @delete_blocked_event
    ]
  end

  def authoring_created(count, metadata \\ %{}), do: emit_count(@created_event, count, metadata)
  def authoring_updated(count, metadata \\ %{}), do: emit_count(@updated_event, count, metadata)
  def authoring_removed(count, metadata \\ %{}), do: emit_count(@removed_event, count, metadata)

  def delivery_resolved(duration_ms, metadata \\ %{}) do
    measurements = %{duration_ms: normalize_duration(duration_ms), count: 1}
    :telemetry.execute(@resolved_event, measurements, sanitize_metadata(metadata))
  end

  def delivery_resolution_failed(metadata \\ %{}),
    do: emit_count(@resolution_failed_event, 1, metadata)

  def delivery_broken_clicked(metadata \\ %{}),
    do: emit_count(@broken_clicked_event, 1, metadata)

  def delete_blocked(metadata \\ %{}),
    do: emit_count(@delete_blocked_event, 1, metadata)

  def handle_event(@resolved_event, measurements, metadata, _config) do
    tags = metric_tags(metadata)
    duration_ms = Map.get(measurements, :duration_ms, 0)

    Appsignal.add_distribution_value(
      "oli.adaptive.dynamic_link.resolve.duration_ms",
      duration_ms,
      tags
    )

    Appsignal.increment_counter("oli.adaptive.dynamic_link.resolved", 1, tags)
  end

  def handle_event(@created_event, measurements, metadata, _config),
    do: increment_counter("oli.adaptive.dynamic_link.created", measurements, metadata)

  def handle_event(@updated_event, measurements, metadata, _config),
    do: increment_counter("oli.adaptive.dynamic_link.updated", measurements, metadata)

  def handle_event(@removed_event, measurements, metadata, _config),
    do: increment_counter("oli.adaptive.dynamic_link.removed", measurements, metadata)

  def handle_event(@resolution_failed_event, measurements, metadata, _config),
    do: increment_counter("oli.adaptive.dynamic_link.resolution_failed", measurements, metadata)

  def handle_event(@broken_clicked_event, measurements, metadata, _config),
    do: increment_counter("oli.adaptive.dynamic_link.broken_clicked", measurements, metadata)

  def handle_event(@delete_blocked_event, measurements, metadata, _config),
    do: increment_counter("oli.adaptive.dynamic_link.delete_blocked", measurements, metadata)

  def handle_event(_, _, _, _), do: :ok

  defp emit_count(_event, count, _metadata) when not is_integer(count) or count <= 0, do: :ok

  defp emit_count(event, count, metadata) do
    :telemetry.execute(event, %{count: count}, sanitize_metadata(metadata))
  end

  defp increment_counter(metric, measurements, metadata) do
    tags = metric_tags(metadata)
    Appsignal.increment_counter(metric, Map.get(measurements, :count, 1), tags)
  end

  defp metric_tags(metadata) do
    %{
      project_id: normalize(metadata[:project_id]),
      project_slug: normalize(metadata[:project_slug]),
      section_slug: normalize(metadata[:section_slug]),
      activity_resource_id: normalize(metadata[:activity_resource_id]),
      target_resource_id: normalize(metadata[:target_resource_id]),
      reason: normalize(metadata[:reason]),
      source: normalize(metadata[:source])
    }
  end

  defp sanitize_metadata(metadata) when is_list(metadata),
    do: metadata |> Map.new() |> sanitize_metadata()

  defp sanitize_metadata(metadata) when is_map(metadata) do
    %{
      project_id: normalize_integer(metadata[:project_id]),
      project_slug: normalize_string(metadata[:project_slug]),
      section_slug: normalize_string(metadata[:section_slug]),
      activity_resource_id: normalize_integer(metadata[:activity_resource_id]),
      target_resource_id: normalize_integer(metadata[:target_resource_id]),
      reason: normalize_string(metadata[:reason]),
      source: normalize_string(metadata[:source])
    }
  end

  defp sanitize_metadata(_),
    do: %{
      project_id: nil,
      project_slug: nil,
      section_slug: nil,
      activity_resource_id: nil,
      target_resource_id: nil,
      reason: "unknown",
      source: "unknown"
    }

  defp normalize_duration(duration_ms) when is_integer(duration_ms) and duration_ms >= 0,
    do: duration_ms

  defp normalize_duration(_), do: 0

  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> parsed
      _ -> nil
    end
  end

  defp normalize_integer(_), do: nil

  defp normalize_string(value) when is_binary(value), do: value
  defp normalize_string(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_string(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_string(_), do: nil

  defp normalize(nil), do: "unknown"
  defp normalize(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize(value) when is_binary(value), do: value
  defp normalize(value), do: to_string(value)

  defp attach_appsignal_handler do
    handler_id = "adaptive-dynamic-link-appsignal-handler"

    case :telemetry.attach_many(handler_id, events(), &__MODULE__.handle_event/4, %{}) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end
end

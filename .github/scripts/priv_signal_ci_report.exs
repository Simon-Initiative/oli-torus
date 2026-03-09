defmodule PrivSignalCIReport do
  @moduledoc false

  def run(args) do
    args = normalize_args(args)

    case args do
      [score_path, diff_path, markdown_path, json_path] ->
        report = build_report(score_path, diff_path, 25)
        File.write!(json_path, Jason.encode!(report, pretty: true))
        File.write!(markdown_path, to_markdown(report))
        :ok

      [score_path, diff_path, markdown_path, json_path, max_events_s | _rest] ->
        max_events = parse_int(max_events_s, 25)
        report = build_report(score_path, diff_path, max_events)
        File.write!(json_path, Jason.encode!(report, pretty: true))
        File.write!(markdown_path, to_markdown(report))
        :ok

      _ ->
        IO.puts(
          :stderr,
          "usage: mix run .github/scripts/priv_signal_ci_report.exs -- <score.json> <diff.json> <report.md> <report.json> <max_events>"
        )

        System.halt(2)
    end
  end

  defp normalize_args([first | rest]) when is_binary(first) do
    cond do
      first == "--" -> normalize_args(rest)
      String.ends_with?(first, ".exs") -> normalize_args(rest)
      true -> [first | rest]
    end
  end

  defp normalize_args(args), do: args

  defp build_report(score_path, diff_path, max_events) do
    score = read_json(score_path)
    diff = read_json(diff_path)

    score_value = get(score, "score") || "ERROR"
    summary = get(score, "summary") || %{}
    reasons = get(score, "reasons") || []
    events = get(diff, "events") || []

    events_by_id =
      Map.new(events, fn event ->
        {get(event, "event_id"), event}
      end)

    reason_details =
      reasons
      |> Enum.map(fn reason ->
        event_id = get(reason, "event_id")
        event = Map.get(events_by_id, event_id, %{})
        %{
          event_id: event_id,
          rule_id: get(reason, "rule_id"),
          event_type: get(event, "event_type"),
          event_class: get(event, "event_class"),
          source: source_for(event),
          sink: sink_for(event),
          location: location_for(event)
        }
      end)

    capped_events =
      events
      |> Enum.sort_by(fn event ->
        {severity_rank(get(event, "event_class")), get(event, "event_id") || ""}
      end)
      |> Enum.take(max_events)
      |> Enum.map(fn event ->
        %{
          event_id: get(event, "event_id"),
          rule_id: get(event, "rule_id"),
          event_type: get(event, "event_type"),
          event_class: get(event, "event_class"),
          source: source_for(event),
          sink: sink_for(event),
          location: location_for(event)
        }
      end)

    %{
      score: score_value,
      summary: summary,
      reasons_count: length(reasons),
      reason_details: reason_details,
      events_sample_count: length(capped_events),
      events_sample: capped_events,
      informational: true
    }
  end

  defp to_markdown(report) do
    summary = report.summary || %{}

    [
      "## PrivSignal (Informational)",
      "",
      "Top-level result: `#{report.score}`",
      "",
      "| Score | High | Medium | Low | Total |",
      "|---|---:|---:|---:|---:|",
      "| `#{report.score}` | #{get(summary, "events_high") || 0} | #{get(summary, "events_medium") || 0} | #{get(summary, "events_low") || 0} | #{get(summary, "events_total") || 0} |",
      "",
      "<details>",
      "<summary>Reason Events (Used For Final Score)</summary>",
      "",
      render_reason_table(report.reason_details || []),
      "",
      "</details>",
      "",
      "<details>",
      "<summary>Sample Of All Events (Capped)</summary>",
      "",
      render_event_sample_table(report.events_sample || []),
      "",
      "</details>"
    ]
    |> Enum.join("\n")
  end

  defp render_reason_table([]), do: "No reason events were available."

  defp render_reason_table(rows) do
    header = [
      "| Rule | Type | Class | Source | Sink | Location |",
      "|---|---|---|---|---|---|"
    ]

    body =
      Enum.map(rows, fn row ->
        "| #{md(row.rule_id)} | #{md(row.event_type)} | #{md(row.event_class)} | #{md(row.source)} | #{md(row.sink)} | #{md(row.location)} |"
      end)

    Enum.join(header ++ body, "\n")
  end

  defp render_event_sample_table([]), do: "No events were available."

  defp render_event_sample_table(rows) do
    header = [
      "| Rule | Type | Class | Source | Sink | Location |",
      "|---|---|---|---|---|---|"
    ]

    body =
      Enum.map(rows, fn row ->
        "| #{md(row.rule_id)} | #{md(row.event_type)} | #{md(row.event_class)} | #{md(row.source)} | #{md(row.sink)} | #{md(row.location)} |"
      end)

    Enum.join(header ++ body, "\n")
  end

  defp location_for(event) when is_map(event) do
    location = get(event, "location") || %{}
    file_path = get(location, "file_path")
    line = get(location, "line")

    cond do
      is_binary(file_path) and is_integer(line) -> "#{file_path}:#{line}"
      is_binary(file_path) -> file_path
      true -> "n/a"
    end
  end

  defp location_for(_event), do: "n/a"

  defp source_for(event) when is_map(event) do
    details = get(event, "details") || %{}
    get(details, "source_key") || get(details, "source") || "n/a"
  end

  defp source_for(_event), do: "n/a"

  defp sink_for(event) when is_map(event) do
    details = get(event, "details") || %{}
    sink = get(details, "sink") || %{}
    get(sink, "subtype") || get(sink, "kind") || "n/a"
  end

  defp sink_for(_event), do: "n/a"

  defp read_json(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, decoded} -> decoded
          {:error, _} -> %{}
        end

      _ ->
        %{}
    end
  end

  defp severity_rank("high"), do: 0
  defp severity_rank("medium"), do: 1
  defp severity_rank("low"), do: 2
  defp severity_rank(_), do: 3

  defp parse_int(value, fallback) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> fallback
    end
  end

  defp parse_int(_, fallback), do: fallback

  defp md(nil), do: "n/a"

  defp md(value) when is_binary(value) do
    value
    |> String.replace("|", "\\|")
    |> String.replace("\n", " ")
  end

  defp md(value), do: value |> to_string() |> md()

  defp get(map, key) when is_map(map) do
    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, to_existing_atom(key)) -> Map.get(map, to_existing_atom(key))
      true -> nil
    end
  end

  defp to_existing_atom(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    _ -> value
  end
end

PrivSignalCIReport.run(System.argv())

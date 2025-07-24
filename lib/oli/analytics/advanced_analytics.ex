defmodule Oli.Analytics.AdvancedAnalytics do
  alias Oli.Analytics.XAPI.ClickHouseSchema

  @doc """
  Provides useful analytics queries for video events.
  """
  def video_engagement_by_section(section_id) when is_integer(section_id) do
    """
      SELECT
        section_id,
        count(*) as total_events,
        countIf(verb LIKE '%played%') as play_events,
        countIf(verb LIKE '%paused%') as pause_events,
        countIf(verb LIKE '%completed%') as completion_events,
        avg(video_progress) as avg_progress,
        uniq(user_id) as unique_users,
        uniq(content_element_id) as unique_videos
      FROM video_events
      WHERE section_id = '#{section_id}'
        AND section_id IS NOT NULL
      GROUP BY section_id
      ORDER BY total_events DESC
    """
    |> execute_clickhouse_query()
  end

  defp execute_clickhouse_query(query) when is_binary(query) and byte_size(query) > 0 do
    config = get_clickhouse_config()
    url = "#{config.host}:#{config.port}"

    headers = [
      {"Content-Type", "text/plain"},
      {"X-ClickHouse-User", config.user},
      {"X-ClickHouse-Key", config.password}
    ]

    # Add FORMAT clause to include headers in the output
    formatted_query =
      if String.contains?(String.downcase(query), "format") do
        query
      else
        query <> " FORMAT TSVWithNames"
      end

    case Oli.HTTP.http().post(url, formatted_query, headers) do
      {:ok, %{status_code: 200} = response} ->
        formatted_response = %{response | body: format_query_results(response.body)}
        {:ok, formatted_response}

      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "Query failed with status #{status_code}: #{body}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp execute_clickhouse_query(_), do: {:error, "Empty query"}

  defp format_query_results(body) when is_binary(body) do
    case String.trim(body) do
      "" ->
        ""

      result ->
        lines = String.split(result, "\n", trim: true)
        format_tsv_with_alignment(lines)
    end
  end

  defp format_tsv_with_alignment([]), do: ""
  defp format_tsv_with_alignment([single_line]), do: single_line

  defp format_tsv_with_alignment([header | data_lines]) do
    # Parse all lines into columns
    all_rows = [header | data_lines] |> Enum.map(&String.split(&1, "\t"))

    # Calculate max width for each column
    column_widths = calculate_column_widths(all_rows)

    # Format header
    formatted_header = format_row(String.split(header, "\t"), column_widths)

    # Create separator line
    separator = create_separator_line(column_widths)

    # Format data rows
    formatted_data =
      data_lines
      |> Enum.map(&String.split(&1, "\t"))
      |> Enum.map(&format_row(&1, column_widths))

    # Combine all parts
    [formatted_header, separator | formatted_data]
    |> Enum.join("\n")
  end

  defp calculate_column_widths(rows) do
    rows
    |> Enum.reduce([], fn row, acc ->
      row
      |> Enum.with_index()
      |> Enum.reduce(acc, fn {cell, index}, widths ->
        cell_length = String.length(to_string(cell))
        current_width = Enum.at(widths, index, 0)

        List.replace_at(
          widths ++ List.duplicate(0, max(0, index + 1 - length(widths))),
          index,
          max(current_width, cell_length)
        )
      end)
    end)
  end

  defp format_row(columns, widths) do
    columns
    |> Enum.with_index()
    |> Enum.map(fn {cell, index} ->
      width = Enum.at(widths, index, 0)
      String.pad_trailing(to_string(cell), width)
    end)
    |> Enum.join(" | ")
  end

  defp create_separator_line(widths) do
    widths
    |> Enum.map(&String.duplicate("-", &1))
    |> Enum.join("-|-")
  end

  defp humanize_query_name(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp get_clickhouse_config() do
    %{
      host: Application.get_env(:oli, :clickhouse_host, "http://localhost"),
      port: Application.get_env(:oli, :clickhouse_port, 8123),
      user: Application.get_env(:oli, :clickhouse_user, "default"),
      password: Application.get_env(:oli, :clickhouse_password, "")
    }
  end
end

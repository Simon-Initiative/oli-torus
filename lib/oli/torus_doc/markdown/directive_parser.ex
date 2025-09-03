defmodule Oli.TorusDoc.Markdown.DirectiveParser do
  @moduledoc """
  Parses custom TMD directives like YouTube, audio, video, and iframe.
  """

  @directive_regex ~r/^:::([\w]+)\s*(\{[^}]*\})?\s*$/m
  @end_directive_regex ~r/^:::$/m

  @doc """
  Extracts directives from markdown and replaces them with placeholders.
  Returns a tuple of {processed_markdown, directive_map}.
  """
  def extract_and_replace(markdown) do
    {processed, directives, _} = process_directives(markdown, %{}, 0)
    {processed, directives}
  end

  defp process_directives(markdown, directives, counter) do
    case Regex.run(@directive_regex, markdown, return: :index) do
      nil ->
        {markdown, directives, counter}

      [{start_pos, length} | _] ->
        # Extract directive details
        directive_line = String.slice(markdown, start_pos, length)
        [_, name | attrs_match] = Regex.run(@directive_regex, directive_line)

        attrs = parse_attributes(List.first(attrs_match, ""))

        # Find the end of the directive
        rest_of_markdown = String.slice(markdown, start_pos + length..-1//1)

        case find_directive_end(rest_of_markdown) do
          nil ->
            # No closing ::: found, treat as normal text
            {markdown, directives, counter}

          {body_end, total_length} ->
            # Extract body content between directive markers
            body = String.slice(rest_of_markdown, 0, body_end) |> String.trim()

            # Generate placeholder and directive data
            directive_id = "directive_#{counter}"
            # Use a placeholder that won't be interpreted as markdown
            placeholder = "TORUS_DIRECTIVE[#{directive_id}]"
            directive_data = build_directive(name, attrs, body)

            # Replace directive with placeholder
            before = String.slice(markdown, 0, start_pos)
            after_pos = start_pos + length + total_length
            after_text = String.slice(markdown, after_pos..-1//1)

            new_markdown = before <> placeholder <> after_text
            new_directives = Map.put(directives, directive_id, directive_data)

            # Continue processing for more directives
            process_directives(new_markdown, new_directives, counter + 1)
        end
    end
  end

  defp find_directive_end(markdown) do
    lines = String.split(markdown, "\n")

    case find_end_line(lines, 0) do
      nil -> nil
      line_num ->
        # Calculate position up to and including the ::: line
        lines_before = Enum.take(lines, line_num + 1)
        total_length = lines_before |> Enum.join("\n") |> String.length()
        body_length = lines |> Enum.take(line_num) |> Enum.join("\n") |> String.length()
        {body_length, total_length}
    end
  end

  defp find_end_line([], _), do: nil
  defp find_end_line([line | rest], index) do
    if Regex.match?(@end_directive_regex, line) do
      index
    else
      find_end_line(rest, index + 1)
    end
  end

  defp parse_attributes(nil), do: %{}
  defp parse_attributes(""), do: %{}

  defp parse_attributes(attr_string) do
    attr_string
    |> String.trim()
    |> String.trim_leading("{")
    |> String.trim_trailing("}")
    |> parse_key_value_pairs()
  end

  defp parse_key_value_pairs(str) do
    # Simple regex-based parser for key=value pairs
    ~r/(\w+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s,}]+))/
    |> Regex.scan(str)
    |> Enum.map(fn
      # Match with double quotes
      [_, key, quoted_double] when quoted_double != "" -> {key, quoted_double}
      # Match with single quotes
      [_, key, "", quoted_single] when quoted_single != "" -> {key, quoted_single}
      # Match with no quotes
      [_, key, "", "", unquoted] -> {key, parse_value(unquoted)}
      # Default case for double quotes (3-element list)
      [_, key, quoted] -> {key, quoted}
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  defp parse_value("true"), do: true
  defp parse_value("false"), do: false
  defp parse_value(str) do
    case Integer.parse(str) do
      {num, ""} -> num
      _ ->
        case Float.parse(str) do
          {num, ""} -> num
          _ -> str
        end
    end
  end

  defp build_directive("youtube", attrs, _body) do
    case validate_youtube_id(attrs["id"]) do
      {:ok, id} ->
        base = %{
          "type" => "youtube",
          "src" => build_youtube_url(id)
        }

        base
        |> maybe_add("startTime", attrs["start"])
        |> maybe_add("endTime", attrs["end"])
        |> maybe_add("alt", attrs["title"])

      :error ->
        # Invalid YouTube ID, return error paragraph
        %{
          "type" => "p",
          "children" => [%{"text" => "[Invalid YouTube ID]"}]
        }
    end
  end

  defp build_directive("audio", attrs, body) do
    case validate_media_src(attrs["src"]) do
      {:ok, src} ->
        base = %{
          "type" => "audio",
          "src" => src
        }

        base
        |> maybe_add("alt", attrs["caption"])
        |> maybe_add_transcript(body)

      :error ->
        %{
          "type" => "p",
          "children" => [%{"text" => "[Invalid audio source]"}]
        }
    end
  end

  defp build_directive("video", attrs, body) do
    case validate_media_src(attrs["src"]) do
      {:ok, src} ->
        base = %{
          "type" => "video",
          "src" => build_video_sources(src, attrs["type"])
        }

        base
        |> maybe_add("poster", attrs["poster"])
        |> maybe_add("alt", body)

      :error ->
        %{
          "type" => "p",
          "children" => [%{"text" => "[Invalid video source]"}]
        }
    end
  end

  defp build_directive("iframe", attrs, _body) do
    case validate_iframe_src(attrs["src"]) do
      {:ok, src} ->
        base = %{
          "type" => "iframe",
          "src" => src
        }

        base
        |> maybe_add("width", attrs["width"])
        |> maybe_add("height", attrs["height"])
        |> maybe_add("alt", attrs["title"])

      :error ->
        %{
          "type" => "p",
          "children" => [%{"text" => "[Invalid or disallowed iframe source]"}]
        }
    end
  end

  defp build_directive(_unknown, _attrs, _body) do
    # Unknown directive, return empty paragraph
    %{"type" => "p", "children" => []}
  end

  defp build_youtube_url(nil), do: ""
  defp build_youtube_url(id) when is_binary(id) do
    "https://www.youtube.com/embed/#{id}"
  end

  defp build_video_sources(src, type) when is_binary(src) do
    content_type = type || guess_content_type(src)
    [%{"url" => src, "contenttype" => content_type}]
  end
  defp build_video_sources(_, _), do: []

  defp guess_content_type(src) do
    cond do
      String.ends_with?(src, ".mp4") -> "video/mp4"
      String.ends_with?(src, ".webm") -> "video/webm"
      String.ends_with?(src, ".ogg") -> "video/ogg"
      true -> "video/mp4"
    end
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)

  defp maybe_add_transcript(map, ""), do: map
  defp maybe_add_transcript(map, nil), do: map
  defp maybe_add_transcript(map, body) do
    # Parse the body as markdown and add as caption
    # For now, just add as text
    Map.put(map, "caption", body)
  end

  # Validation functions

  @youtube_id_regex ~r/^[A-Za-z0-9_-]{11}$/

  defp validate_youtube_id(nil), do: :error
  defp validate_youtube_id(id) when is_binary(id) do
    if Regex.match?(@youtube_id_regex, id) do
      {:ok, id}
    else
      :error
    end
  end
  defp validate_youtube_id(_), do: :error

  defp validate_media_src(nil), do: :error
  defp validate_media_src(src) when is_binary(src) do
    # Allow relative paths and https URLs
    cond do
      String.starts_with?(src, "/") -> {:ok, src}
      String.starts_with?(src, "./") -> {:ok, src}
      String.starts_with?(src, "../") -> {:ok, src}
      String.starts_with?(src, "https://") -> {:ok, src}
      String.starts_with?(src, "http://") -> {:ok, src}  # Will be upgraded to https
      true -> :error
    end
  end
  defp validate_media_src(_), do: :error

  # List of allowed iframe domains for security
  @allowed_iframe_domains [
    "youtube.com",
    "www.youtube.com",
    "player.vimeo.com",
    "codepen.io",
    "codesandbox.io",
    "jsfiddle.net",
    "embed.music.apple.com",
    "open.spotify.com"
  ]

  defp validate_iframe_src(nil), do: :error
  defp validate_iframe_src(src) when is_binary(src) do
    case URI.parse(src) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
        if Enum.any?(@allowed_iframe_domains, &String.ends_with?(host, &1)) do
          {:ok, src}
        else
          :error
        end
      _ ->
        :error
    end
  end
  defp validate_iframe_src(_), do: :error
end

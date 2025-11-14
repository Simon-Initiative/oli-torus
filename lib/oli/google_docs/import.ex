defmodule Oli.GoogleDocs.Import do
  @moduledoc """
  Orchestrates the Google Docs import pipeline by composing download, parsing,
  media ingestion, custom element conversion, activity creation, and page
  persistence steps. Also enforces single-flight guarantees per FILE_ID, emits
  telemetry, and captures audit events.
  """

  require Logger

  alias Oli.Auditing
  alias Oli.Authoring.Course
  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Authoring.Editing.Utils
  alias Oli.GoogleDocs.CustomElements
  alias Oli.GoogleDocs.MarkdownParser
  alias Oli.GoogleDocs.MarkdownParser.CustomElement
  alias Oli.GoogleDocs.MarkdownParser.MediaReference
  alias Oli.GoogleDocs.McqBuilder

  alias Oli.GoogleDocs.{
    MediaIngestor,
    Warnings,
    CheckAllThatApplyBuilder,
    ShortAnswerBuilder,
    DropdownBuilder
  }

  alias Oli.GoogleDocs.Client
  alias Oli.GoogleDocs.CustomElements.YouTube
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.{ResourceType, ScoringStrategy}

  @guard_table :google_docs_import_guard
  @telemetry_event [:oli, :google_docs_import]

  @doc """
  Imports a Google Doc identified by `file_id` into the project/container context.

  On success returns `{:ok, revision, warnings}` where `revision` is the newly
  created page revision and `warnings` is a list of warning maps collected during
  the pipeline. On failure returns `{:error, reason, warnings}`.
  """
  @spec import(String.t(), String.t() | nil, String.t(), Oli.Accounts.Author.t()) ::
          {:ok, Oli.Resources.Revision.t(), list(map())}
          | {:error, term(), list(map())}
  def import(project_slug, container_slug, file_id, author) do
    import(project_slug, container_slug, file_id, author, [])
  end

  @spec import(String.t(), String.t() | nil, String.t(), Oli.Accounts.Author.t(), keyword()) ::
          {:ok, Oli.Resources.Revision.t(), list(map())}
          | {:error, term(), list(map())}
  def import(project_slug, container_slug, file_id, author, opts) do
    config = build_config(opts)

    with {:ok, project} <- fetch_project(project_slug),
         {:ok} <- Utils.authorize_user(author, project),
         {:ok, container} <- fetch_container(project_slug, container_slug),
         :ok <- ensure_container(container),
         guard_key = guard_key(project.slug, file_id),
         :ok <- acquire_guard(guard_key) do
      try do
        context = %{
          project: project,
          container: container,
          author: author,
          file_id: file_id,
          config: config,
          file_id_hash: hash_file_id(file_id)
        }

        do_import(context)
      after
        release_guard(guard_key)
      end
    else
      {:error, {:not_found, entity}} ->
        {:error, {:not_found, entity}, []}

      {:error, {:not_authorized}} ->
        {:error, {:not_authorized}, []}

      {:error, :import_in_progress} ->
        {:error, :import_in_progress, []}
    end
  end

  defp do_import(%{project: project, author: _author, file_id_hash: file_id_hash} = ctx) do
    span_metadata = %{project_slug: project.slug, file_id_hash: file_id_hash}

    result =
      :telemetry.span(@telemetry_event, span_metadata, fn ->
        started_at = System.monotonic_time()

        outcome = perform_import(ctx)

        finished_at = System.monotonic_time()

        duration_ms =
          (finished_at - started_at)
          |> System.convert_time_unit(:native, :millisecond)

        {measurements, metadata} = telemetry_payload(outcome, ctx, duration_ms)
        wrapped_outcome = attach_duration(outcome, duration_ms)

        {wrapped_outcome, measurements, metadata}
      end)

    case result do
      {:ok, data} ->
        handle_success(ctx, data)

      {:error, reason, data} ->
        handle_failure(ctx, reason, data)
    end
  end

  defp perform_import(
         %{project: project, container: container, author: author, config: config} = ctx
       ) do
    client = Keyword.get(config, :client, Client)
    client_opts = Keyword.get(config, :client_opts, [])

    with {:ok, download} <- client.fetch_markdown(ctx.file_id, client_opts),
         {front_matter, body} <- split_front_matter(download.body),
         parser_opts = Keyword.get(config, :parser_opts, []) ++ [metadata: front_matter],
         {:ok, parsed} <- MarkdownParser.parse(body, parser_opts),
         {:ok, resolution} <- CustomElements.resolve(parsed.custom_elements),
         {:ok, media_result} <- ingest_media(parsed.media, project.slug, config),
         {:ok, element_resolution} <-
           resolve_custom_elements(
             parsed.custom_elements,
             resolution,
             project.slug,
             author,
             config
           ),
         {:ok, content_model} <-
           build_page_content(parsed.blocks, %{
             media_entries: media_result.entries,
             media_refs: map_by_id(parsed.media),
             custom_elements: element_resolution.replacements,
             custom_element_map: map_by_id(parsed.custom_elements)
           }) do
      warnings =
        []
        |> append_warnings(parsed.warnings)
        |> append_warnings(resolution.warnings)
        |> append_warnings(element_resolution.warnings)
        |> append_warnings(media_result.warnings)

      title = choose_title(parsed, front_matter, download.file_id)

      attrs = build_page_attrs(title, content_model)

      case ContainerEditor.add_new(container, attrs, author, project) do
        {:ok, revision} ->
          {:ok,
           %{
             revision: revision,
             warnings: warnings,
             download_bytes: download.bytes,
             media: media_result,
             title: title
           }}

        {:error, reason} ->
          {:error, reason,
           %{warnings: warnings, download_bytes: download.bytes, media: media_result}}
      end
    else
      {:error, {:body_too_large, info}} ->
        {:error, {:body_too_large, info},
         %{warnings: [], download_bytes: info[:bytes] || 0, media: empty_media_stats()}}

      {:error, {:invalid_file_id, reason}} ->
        {:error, {:invalid_file_id, reason},
         %{warnings: [], download_bytes: 0, media: empty_media_stats()}}

      {:error, {:http_status, status, response}} ->
        {:error, {:http_status, status, response},
         %{warnings: [], download_bytes: 0, media: empty_media_stats()}}

      {:error, {:http_redirect, status, location}} ->
        warning =
          Warnings.build(:download_redirect, %{
            status: status,
            location: location || "unknown"
          })

        {:error, {:http_redirect, status, location},
         %{warnings: [warning], download_bytes: 0, media: empty_media_stats()}}

      {:error, {:http_error, reason}} ->
        {:error, {:http_error, reason},
         %{warnings: [], download_bytes: 0, media: empty_media_stats()}}

      {:error, :document_too_complex, warnings} ->
        {:error, :document_too_complex,
         %{warnings: warnings, download_bytes: 0, media: empty_media_stats()}}

      {:error, reason, warnings} when is_list(warnings) ->
        {:error, reason, %{warnings: warnings, download_bytes: 0, media: empty_media_stats()}}

      {:error, reason} ->
        {:error, reason, %{warnings: [], download_bytes: 0, media: empty_media_stats()}}
    end
  end

  defp ingest_media(media_refs, project_slug, config) do
    media_module = Keyword.get(config, :media_ingestor, MediaIngestor)

    media_opts =
      [project_slug: project_slug]
      |> Keyword.merge(Keyword.get(config, :media_options, []))

    media_module.ingest(media_refs, media_opts)
  end

  defp resolve_custom_elements(custom_elements, resolution, project_slug, author, config) do
    builder_specs = activity_builder_specs(config, project_slug, author)
    element_map = map_by_id(custom_elements)

    {replacements, warnings} =
      Enum.reduce(resolution.elements, {%{}, []}, fn {id, element}, {acc, warn_acc} ->
        case element do
          %YouTube{} = youtube ->
            {Map.put(acc, id, {:youtube, youtube}), warn_acc}

          _ ->
            case find_activity_builder(element, builder_specs) do
              {builder, builder_opts} ->
                case builder.build(element, builder_opts) do
                  {:ok, result} ->
                    builder_warnings = Map.get(result, :warnings, [])

                    entry =
                      {:activity,
                       %{
                         builder: builder,
                         status: :ok,
                         result: result,
                         element: element
                       }}

                    {Map.put(acc, id, entry), warn_acc ++ builder_warnings}

                  {:error, reason, builder_warnings} ->
                    Logger.warning(
                      "activity builder #{inspect(builder)} failed id=#{id} reason=#{inspect(reason)} warnings=#{inspect(builder_warnings)}"
                    )

                    original = Map.fetch!(element_map, id)

                    entry =
                      {:activity,
                       %{
                         builder: builder,
                         status: :error,
                         reason: reason,
                         element: original
                       }}

                    {Map.put(acc, id, entry), warn_acc ++ (builder_warnings || [])}
                end

              nil ->
                {acc, warn_acc}
            end
        end
      end)

    replacements_with_fallbacks =
      Enum.reduce(resolution.fallbacks, replacements, fn {id, _fallback}, acc ->
        case Map.fetch(element_map, id) do
          {:ok, element} -> Map.put_new(acc, id, {:fallback, element})
          :error -> acc
        end
      end)

    {:ok, %{replacements: replacements_with_fallbacks, warnings: warnings}}
  end

  defp activity_builder_specs(config, project_slug, author) do
    common_opts = [project_slug: project_slug, author: author]

    builders =
      case Keyword.get(config, :activity_builders) do
        nil ->
          [
            {Keyword.get(config, :mcq_builder, McqBuilder),
             Keyword.get(config, :mcq_builder_opts, [])},
            {CheckAllThatApplyBuilder, Keyword.get(config, :cata_builder_opts, [])},
            {ShortAnswerBuilder, Keyword.get(config, :short_answer_builder_opts, [])},
            {DropdownBuilder, Keyword.get(config, :dropdown_builder_opts, [])}
          ]

        list when is_list(list) ->
          list
      end

    Enum.map(builders, fn
      {module, opts} -> {module, Keyword.merge(common_opts, opts)}
      module -> {module, common_opts}
    end)
  end

  defp find_activity_builder(element, specs) do
    Enum.find_value(specs, fn {module, opts} ->
      Code.ensure_loaded?(module)

      if function_exported?(module, :supported?, 1) do
        if module.supported?(element) do
          {module, opts}
        end
      end
    end)
  end

  defp build_page_content(blocks, context) do
    nodes =
      blocks
      |> Enum.sort_by(& &1.index)
      |> Enum.flat_map(&block_to_nodes(&1, context))

    {:ok, %{"version" => "0.1.0", "model" => wrap_in_contents(nodes)}}
  end

  defp block_to_nodes(%{type: :heading, level: level, inlines: inlines}, _context) do
    [
      %{
        "type" => "h#{level}",
        "id" => unique_id(),
        "children" => convert_inlines(inlines)
      }
    ]
  end

  defp block_to_nodes(%{type: :paragraph, inlines: inlines}, _context) do
    children = convert_inlines(inlines)

    if Enum.all?(children, &(&1["text"] == "")) do
      []
    else
      [
        %{
          "type" => "p",
          "id" => unique_id(),
          "children" => children
        }
      ]
    end
  end

  defp block_to_nodes(%{type: :unordered_list, items: items}, context) do
    [
      %{
        "type" => "ul",
        "id" => unique_id(),
        "children" =>
          Enum.map(items, fn item ->
            list_item_node(item, context)
          end)
      }
    ]
  end

  defp block_to_nodes(%{type: :ordered_list, items: items}, context) do
    [
      %{
        "type" => "ol",
        "id" => unique_id(),
        "children" =>
          Enum.map(items, fn item ->
            list_item_node(item, context)
          end)
      }
    ]
  end

  defp block_to_nodes(%{type: :blockquote, blocks: blocks}, context) do
    children =
      blocks
      |> Enum.flat_map(&block_to_nodes(&1, context))

    [
      %{
        "type" => "blockquote",
        "id" => unique_id(),
        "children" => children
      }
    ]
  end

  defp block_to_nodes(%{type: :code, code: code, language: language}, _context) do
    [
      %{
        "type" => "code",
        "id" => unique_id(),
        "language" => language || "text",
        "code" => code,
        "children" => [%{"text" => ""}]
      }
    ]
  end

  defp block_to_nodes(%{type: :table, header: header, rows: rows}, _context) do
    [
      build_table_node(header, rows)
    ]
  end

  defp block_to_nodes(%{type: :image, media_id: id, alt: alt, title: title}, context) do
    entry = Map.get(context.media_entries, id, %{url: nil})

    src =
      entry.url ||
        case Map.get(context.media_refs, id) do
          %MediaReference{src: source} -> source
          _ -> nil
        end

    node =
      %{
        "type" => "img",
        "id" => unique_id(),
        "src" => src,
        "children" => [%{"text" => ""}]
      }
      |> maybe_put("alt", string_or_nil(alt))
      |> maybe_put("caption", build_caption(title))

    [node]
  end

  defp block_to_nodes(%{type: :formula, src: src}, _context) do
    [
      %{
        "type" => "formula",
        "id" => unique_id(),
        "subtype" => "latex",
        "src" => src,
        "children" => [%{"text" => ""}]
      }
    ]
  end

  defp block_to_nodes(%{type: :custom_element_placeholder, id: id}, context) do
    case Map.get(context.custom_elements, id) do
      {:youtube, youtube} ->
        [build_youtube_node(youtube)]

      {:activity, %{status: :ok, result: result}} ->
        [build_activity_reference_node(result)]

      {:activity, %{status: :error, element: element}} ->
        [build_custom_element_table(element)]

      {:fallback, element} ->
        [build_custom_element_table(element)]

      nil ->
        case Map.get(context.custom_element_map, id) do
          %CustomElement{} = element ->
            [build_custom_element_table(element)]

          _ ->
            []
        end
    end
  end

  defp block_to_nodes(_, _), do: []

  defp list_item_node(%{inlines: inlines, nested: nested}, context) do
    inline_children = convert_inlines(inlines)

    paragraph =
      if Enum.all?(inline_children, &(&1["text"] == "")) do
        []
      else
        [
          %{
            "type" => "p",
            "id" => unique_id(),
            "children" => inline_children
          }
        ]
      end

    nested_nodes =
      nested
      |> Enum.flat_map(&block_to_nodes(&1, context))

    %{
      "type" => "li",
      "id" => unique_id(),
      "children" => paragraph ++ nested_nodes
    }
  end

  defp build_youtube_node(%YouTube{} = youtube) do
    raw = youtube.raw || %{}

    %{
      "type" => "youtube",
      "id" => unique_id(),
      "src" => youtube.video_id || youtube.source,
      "children" => [%{"text" => ""}]
    }
    |> maybe_put("caption", build_caption(youtube.caption))
    |> maybe_put("startTime", parse_numeric(Map.get(raw, "startTime")))
    |> maybe_put("endTime", parse_numeric(Map.get(raw, "endTime")))
    |> maybe_put("width", parse_dimension(Map.get(raw, "width")))
    |> maybe_put("height", parse_dimension(Map.get(raw, "height")))
    |> maybe_put("alt", string_or_nil(Map.get(raw, "alt")))
  end

  defp parse_dimension(nil), do: nil

  defp parse_dimension(value) when is_binary(value) do
    trimmed = String.trim(value)

    case trimmed do
      "" ->
        nil

      _ ->
        case Float.parse(trimmed) do
          {num, ""} ->
            num

          _ ->
            case Integer.parse(trimmed) do
              {int, ""} -> int
              _ -> trimmed
            end
        end
    end
  end

  defp parse_dimension(value) when is_number(value), do: value
  defp parse_dimension(_), do: nil

  defp parse_numeric(nil), do: nil
  defp parse_numeric(value) when is_number(value), do: value

  defp parse_numeric(value) when is_binary(value) do
    trimmed = String.trim(value)

    case trimmed do
      "" ->
        nil

      _ ->
        case Integer.parse(trimmed) do
          {int, ""} ->
            int

          _ ->
            case Float.parse(trimmed) do
              {float, ""} -> float
              _ -> nil
            end
        end
    end
  end

  defp parse_numeric(_), do: nil

  defp build_activity_reference_node(%{revision: revision}) do
    %{
      "type" => "activity-reference",
      "id" => unique_id(),
      "activity_id" => revision.resource_id,
      "activitySlug" => revision.slug,
      "children" => []
    }
  end

  defp build_custom_element_table(%CustomElement{element_type: type, raw_rows: rows}) do
    header = [
      [%{text: "Key", marks: [], href: nil}],
      [%{text: "Value", marks: [], href: nil}]
    ]

    body_rows =
      Enum.map(rows, fn {key, value} ->
        [
          [%{text: key || "", marks: [], href: nil}],
          [%{text: value || "", marks: [], href: nil}]
        ]
      end)

    table = build_table_node(header, body_rows)

    caption =
      (type && String.trim(type) != "" && "CustomElement #{String.upcase(type)}") || nil

    maybe_put(table, "caption", build_caption(caption))
  end

  defp build_table_node(header, rows) do
    header_nodes =
      if header == [] do
        []
      else
        [
          %{
            "type" => "tr",
            "id" => unique_id(),
            "children" =>
              Enum.map(header, fn cell ->
                %{
                  "type" => "th",
                  "id" => unique_id(),
                  "children" => convert_inlines(cell)
                }
              end)
          }
        ]
      end

    row_nodes =
      Enum.map(rows, fn cells ->
        %{
          "type" => "tr",
          "id" => unique_id(),
          "children" =>
            Enum.map(cells, fn cell ->
              %{
                "type" => "td",
                "id" => unique_id(),
                "children" => convert_inlines(cell)
              }
            end)
        }
      end)

    %{
      "type" => "table",
      "id" => unique_id(),
      "children" => header_nodes ++ row_nodes
    }
  end

  defp convert_inlines(inlines) when is_list(inlines) do
    case inlines
         |> Enum.map(&convert_inline/1)
         |> List.flatten()
         |> cleanup_formula_artifacts() do
      [] -> [%{"text" => ""}]
      nodes -> nodes
    end
  end

  defp convert_inline(%{text: text, marks: marks, href: nil}) do
    text
    |> normalize_inline_text()
    |> case do
      nil -> []
      "" -> [%{"text" => ""}]
      content -> [apply_marks(%{"text" => content}, marks)]
    end
  end

  defp convert_inline(%{text: text, marks: marks, href: href}) do
    link_children = convert_inline(%{text: text, marks: marks, href: nil})

    [
      %{
        "type" => "a",
        "href" => href,
        "children" => link_children
      }
    ]
  end

  defp convert_inline(%{type: :inline_formula, src: src}) do
    case string_or_nil(src) do
      nil ->
        []

      content ->
        normalized =
          content
          |> String.replace("\\\\", "\\")

        [
          %{
            "type" => "formula_inline",
            "id" => unique_id(),
            "src" => normalized,
            "subtype" => "latex",
            "children" => [%{"text" => ""}]
          }
        ]
    end
  end

  defp convert_inline(_), do: []

  defp cleanup_formula_artifacts(nodes) do
    nodes
    |> do_cleanup_formula_artifacts([])
    |> Enum.reverse()
  end

  defp do_cleanup_formula_artifacts([], acc), do: acc

  defp do_cleanup_formula_artifacts(
         [%{"text" => text} = node | rest = [%{"type" => "formula_inline"} | _]],
         acc
       ) do
    cond do
      blank_or_backslash?(text) ->
        do_cleanup_formula_artifacts(rest, acc)

      String.ends_with?(text, "\\") ->
        updated = %{node | "text" => String.trim_trailing(text, "\\")}
        do_cleanup_formula_artifacts([updated | rest], acc)

      true ->
        do_cleanup_formula_artifacts(rest, [node | acc])
    end
  end

  defp do_cleanup_formula_artifacts(
         [%{"type" => "formula_inline"} = formula, %{"text" => text} = node | rest],
         acc
       ) do
    cond do
      blank_or_backslash?(text) ->
        do_cleanup_formula_artifacts(rest, [formula | acc])

      String.starts_with?(text, "\\") ->
        updated = %{node | "text" => String.trim_leading(text, "\\")}
        do_cleanup_formula_artifacts([formula, updated | rest], acc)

      true ->
        do_cleanup_formula_artifacts(rest, [node, formula | acc])
    end
  end

  defp do_cleanup_formula_artifacts([node | rest], acc) do
    do_cleanup_formula_artifacts(rest, [node | acc])
  end

  defp blank_or_backslash?(text) do
    trimmed = String.trim(text)
    trimmed == "" or trimmed == "\\"
  end

  defp normalize_inline_text(text) when is_binary(text), do: text
  defp normalize_inline_text(_), do: nil

  defp apply_marks(node, marks) do
    Enum.reduce(marks, node, fn mark, acc ->
      case mark_to_key(mark) do
        nil -> acc
        key -> Map.put(acc, key, true)
      end
    end)
  end

  defp mark_to_key(mark) when is_binary(mark) do
    case String.trim(mark) do
      "" -> nil
      value -> value
    end
  end

  defp mark_to_key(mark) when is_atom(mark) do
    case mark do
      :bold -> "strong"
      :italic -> "em"
      other -> Atom.to_string(other)
    end
  end

  defp mark_to_key(_), do: nil

  defp build_caption(nil), do: nil
  defp build_caption(""), do: nil

  defp build_caption(text) do
    [
      %{
        "type" => "p",
        "id" => unique_id(),
        "children" => [%{"text" => text}]
      }
    ]
  end

  defp wrap_in_contents(nodes) do
    nodes
    |> Enum.reduce([], fn node, acc ->
      if wrap_in_content?(node) do
        case acc do
          [%{"type" => "content", "children" => children} = content | rest] ->
            [%{content | "children" => children ++ [node]} | rest]

          _ ->
            content = %{
              "type" => "content",
              "id" => unique_id(),
              "children" => [node]
            }

            [content | acc]
        end
      else
        [node | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp wrap_in_content?(%{"type" => "activity-reference"}), do: false
  defp wrap_in_content?(_), do: true

  defp build_page_attrs(title, content) do
    %{
      tags: [],
      objectives: %{"attached" => []},
      children: [],
      content: content,
      title: title,
      graded: false,
      max_attempts: 0,
      recommended_attempts: 0,
      scoring_strategy_id: ScoringStrategy.get_id_by_type("total"),
      resource_type_id: ResourceType.id_for_page()
    }
  end

  defp telemetry_payload(
         {:ok, data},
         %{project: project, author: author, file_id_hash: hash},
         duration_ms
       ) do
    media = data.media

    measurement = %{
      duration_ms: duration_ms,
      download_bytes: data.download_bytes,
      media_bytes: media_stat(media, :bytes_uploaded)
    }

    metadata = %{
      project_id: project.id,
      author_id: author.id,
      file_id_hash: hash,
      warning_count: length(data.warnings),
      uploaded_media_count: media_stat(media, :uploaded_count),
      failed_media_count: media_stat(media, :failed_count),
      skipped_media_count: media_stat(media, :skipped_count)
    }

    {measurement, metadata}
  end

  defp telemetry_payload(
         {:error, _reason, data},
         %{project: project, author: author, file_id_hash: hash},
         duration_ms
       ) do
    media = Map.get(data, :media)

    measurement = %{
      duration_ms: duration_ms,
      download_bytes: Map.get(data, :download_bytes, 0),
      media_bytes: media_stat(media, :bytes_uploaded)
    }

    metadata = %{
      project_id: project.id,
      author_id: author.id,
      file_id_hash: hash,
      warning_count: length(Map.get(data, :warnings, [])),
      uploaded_media_count: media_stat(media, :uploaded_count),
      failed_media_count: media_stat(media, :failed_count),
      skipped_media_count: media_stat(media, :skipped_count)
    }

    {measurement, metadata}
  end

  defp attach_duration({:ok, data}, duration_ms),
    do: {:ok, Map.put(data, :duration_ms, duration_ms)}

  defp attach_duration({:error, reason, data}, duration_ms),
    do: {:error, reason, Map.put(data, :duration_ms, duration_ms)}

  defp handle_success(%{project: project, author: author, file_id_hash: hash}, %{
         revision: revision,
         warnings: warnings,
         download_bytes: download_bytes,
         media: media,
         duration_ms: duration_ms,
         title: title
       }) do
    log_success(project.slug, hash, duration_ms, warnings)

    capture_audit(
      author,
      project,
      hash,
      revision,
      warnings,
      duration_ms,
      download_bytes,
      media,
      title
    )

    {:ok, revision, warnings}
  end

  defp handle_failure(
         %{project: project, file_id_hash: hash},
         reason,
         %{warnings: warnings} = _data
       ) do
    Logger.warning(fn ->
      "Google Docs import failed project=#{project.slug} file_hash=#{hash} reason=#{inspect(reason)}"
    end)

    {:error, reason, warnings || []}
  end

  defp log_success(project_slug, file_hash, duration_ms, warnings) do
    Logger.info(fn ->
      "Google Docs import succeeded project=#{project_slug} file_hash=#{file_hash} duration_ms=#{duration_ms} warnings=#{length(warnings)}"
    end)
  end

  defp capture_audit(
         author,
         project,
         file_hash,
         revision,
         warnings,
         duration_ms,
         download_bytes,
         media,
         title
       ) do
    warning_codes =
      warnings
      |> Enum.map(& &1.code)
      |> Enum.reduce(%{}, fn code, acc ->
        Map.update(acc, to_string(code), 1, &(&1 + 1))
      end)

    details = %{
      "file_id_hash" => file_hash,
      "page_revision_id" => revision.id,
      "page_resource_id" => revision.resource_id,
      "page_title" => title,
      "warning_codes" => warning_codes,
      "warning_count" => length(warnings),
      "duration_ms" => duration_ms,
      "duration_bucket" => duration_bucket(duration_ms),
      "download_bytes" => download_bytes,
      "uploaded_media_count" => media.uploaded_count,
      "reused_media_count" => media.reused_count,
      "failed_media_count" => media.failed_count,
      "skipped_media_count" => media.skipped_count,
      "media_bytes_uploaded" => media.bytes_uploaded
    }

    case Auditing.capture(author, :google_doc_imported, project, details) do
      {:ok, _} ->
        :ok

      {:error, changeset} ->
        Logger.warning("Failed to record Google Docs import audit event: #{inspect(changeset)}")
    end
  end

  defp duration_bucket(duration_ms) when duration_ms <= 6_000, do: "<=6s"
  defp duration_bucket(duration_ms) when duration_ms <= 12_000, do: "6-12s"
  defp duration_bucket(_duration_ms), do: ">12s"

  defp build_config(opts) do
    base = Application.get_env(:oli, :google_docs_import, [])
    Keyword.merge(base, opts)
  end

  defp fetch_project(slug) do
    case Course.get_project_by_slug(slug) do
      nil -> {:error, {:not_found, :project}}
      project -> {:ok, project}
    end
  end

  defp fetch_container(project_slug, nil) do
    case AuthoringResolver.root_container(project_slug) do
      nil -> {:error, {:not_found, :container}}
      container -> {:ok, container}
    end
  end

  defp fetch_container(project_slug, slug) do
    case AuthoringResolver.from_revision_slug(project_slug, slug) do
      nil -> {:error, {:not_found, :container}}
      container -> {:ok, container}
    end
  end

  defp ensure_container(%{resource_type_id: type_id}) do
    if type_id == ResourceType.id_for_container() do
      :ok
    else
      {:error, {:invalid_container_type, type_id}}
    end
  end

  defp guard_key(project_slug, file_id) do
    {:google_docs_import, project_slug, hash_file_id(file_id)}
  end

  defp acquire_guard(key) do
    ensure_guard_table()

    case :ets.insert_new(@guard_table, {key, System.monotonic_time()}) do
      true -> :ok
      false -> {:error, :import_in_progress}
    end
  end

  defp release_guard(key) do
    ensure_guard_table()
    :ets.delete(@guard_table, key)
  end

  defp ensure_guard_table do
    case :ets.info(@guard_table) do
      :undefined ->
        :ets.new(@guard_table, [:named_table, :set, :public, read_concurrency: true])

      _ ->
        @guard_table
    end
  end

  defp hash_file_id(file_id) do
    :crypto.hash(:sha256, file_id)
    |> Base.encode16(case: :lower)
  end

  defp split_front_matter(<<"---", rest::binary>>) do
    case String.split(rest, ~r/\R---\R/, parts: 2) do
      [front, body] ->
        {parse_front_matter(String.trim(front)), String.trim_leading(body)}

      _ ->
        {%{}, String.trim_leading(rest, "\n")}
    end
  end

  defp split_front_matter(content), do: {%{}, content}

  defp parse_front_matter(front) do
    front
    |> String.split(~r/\R/, trim: true)
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ":", parts: 2) do
        [key, value] ->
          Map.put(acc, String.trim(key), String.trim(value))

        _ ->
          acc
      end
    end)
  end

  defp choose_title(%{title: title}, metadata, fallback) do
    cond do
      is_binary(title) and String.trim(title) != "" ->
        title

      is_binary(metadata["title"]) and String.trim(metadata["title"]) != "" ->
        metadata["title"]

      true ->
        "Imported page #{String.slice(fallback, 0, 8)}"
    end
  end

  defp append_warnings(list, nil), do: list
  defp append_warnings(list, []), do: list
  defp append_warnings(list, warnings), do: list ++ warnings

  defp media_stat(%{} = media, field), do: Map.get(media, field, 0)
  defp media_stat(_, _field), do: 0

  defp map_by_id(collection) do
    Enum.reduce(collection, %{}, fn
      %MediaReference{id: id} = element, acc -> Map.put(acc, id, element)
      %CustomElement{id: id} = element, acc -> Map.put(acc, id, element)
      _other, acc -> acc
    end)
  end

  defp empty_media_stats do
    %MediaIngestor.Result{
      entries: %{},
      order: [],
      warnings: [],
      bytes_uploaded: 0,
      uploaded_count: 0,
      reused_count: 0,
      dedupe_hits: 0,
      skipped_count: 0,
      failed_count: 0
    }
  end

  defp unique_id do
    :erlang.unique_integer([:monotonic, :positive])
    |> Integer.to_string(36)
  end

  defp string_or_nil(value) when is_binary(value), do: String.trim(value)
  defp string_or_nil(_), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

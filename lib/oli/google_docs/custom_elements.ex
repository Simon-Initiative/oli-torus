defmodule Oli.GoogleDocs.CustomElements do
  @moduledoc """
  Interprets custom element placeholders emitted by the Markdown parser and
  converts them into typed structs that downstream stages can consume.

  Recognised element types currently include YouTube embeds and MCQ activity
  specifications. Unknown elements fall back to table rendering with a warning.
  """

  alias Oli.GoogleDocs.MarkdownParser.CustomElement
  alias Oli.GoogleDocs.Warnings

  @type resolve_option :: {:warn_unknown, boolean()}

  defmodule Result do
    @moduledoc """
    Summary of custom element resolution for a parsed document.
    """

    @enforce_keys [:elements, :warnings, :fallbacks, :order]
    defstruct elements: %{},
              warnings: [],
              fallbacks: %{},
              order: []
  end

  defmodule YouTube do
    @moduledoc """
    Normalised representation of a YouTube custom element.
    """

    @enforce_keys [:id, :block_index, :source, :caption]
    defstruct [
      :id,
      :block_index,
      :source,
      :caption,
      :video_id,
      :embed_url,
      :watch_url,
      :raw
    ]
  end

  defmodule Mcq do
    @moduledoc """
    Normalised representation of an MCQ custom element.
    """

    defmodule Choice do
      @moduledoc false

      @enforce_keys [:id, :index, :text]
      defstruct [:id, :index, :text, :feedback, :feedback_key]
    end

    @enforce_keys [:id, :block_index, :stem, :choices, :correct_key]
    defstruct [
      :id,
      :block_index,
      :stem,
      :choices,
      :correct_key,
      :raw
    ]
  end

  @doc """
  Resolves the given list of custom element specs into typed structs.

  Unknown elements are recorded as fallbacks so that the caller can render the
  original table. Warnings are accumulated in occurrence order.
  """
  @spec resolve([CustomElement.t()], [resolve_option()]) :: {:ok, Result.t()}
  def resolve(custom_elements, opts \\ []) when is_list(custom_elements) do
    initial = %Result{elements: %{}, warnings: [], fallbacks: %{}, order: []}

    result =
      Enum.reduce(custom_elements, initial, fn %CustomElement{} = element, acc ->
        case dispatch(element, opts) do
          {:ok, typed, warnings} ->
            acc
            |> add_order(element.id)
            |> add_element(typed)
            |> add_warnings(warnings)

          {:fallback, reason, warnings} ->
            acc
            |> add_order(element.id)
            |> add_fallback(element, reason)
            |> add_warnings(warnings)
        end
      end)

    {:ok, finalize(result)}
  end

  defp finalize(%Result{} = result) do
    %{
      result
      | warnings: Enum.reverse(result.warnings),
        order: Enum.reverse(result.order)
    }
  end

  defp add_order(%Result{order: order} = result, id), do: %{result | order: [id | order]}

  defp add_element(%Result{elements: elements} = result, typed) do
    %{result | elements: Map.put(elements, typed.id, typed)}
  end

  defp add_fallback(%Result{fallbacks: fallbacks} = result, %CustomElement{} = element, reason) do
    %{result | fallbacks: Map.put(fallbacks, element.id, %{reason: reason, element: element})}
  end

  defp add_warnings(%Result{warnings: warnings} = result, new_warnings) do
    %{result | warnings: Enum.reduce(new_warnings, warnings, &[&1 | &2])}
  end

  defp dispatch(%CustomElement{element_type: type} = element, opts) do
    case String.downcase(type) do
      "youtube" -> dispatch_youtube(element)
      "mcq" -> dispatch_mcq(element)
      other -> dispatch_unknown(element, other, opts)
    end
  end

  defp dispatch_unknown(%CustomElement{} = _element, type, opts) do
    warn? = Keyword.get(opts, :warn_unknown, true)

    warnings =
      if warn? do
        [Warnings.build(:custom_element_unknown, %{element_type: type})]
      else
        []
      end

    {:fallback, :unknown_type, warnings}
  end

  defp dispatch_youtube(%CustomElement{} = element) do
    data = normalise_keys(element.data)
    source = Map.get(data, "src", "")

    if String.trim(source) == "" do
      warning =
        Warnings.build(:custom_element_invalid_shape, %{
          element_type: element.element_type
        })

      {:fallback, :invalid, [warning]}
    else
      {video_id, embed_url, watch_url} = derive_youtube_urls(source)

      youtube = %YouTube{
        id: element.id,
        block_index: element.block_index,
        source: source,
        caption: Map.get(data, "caption"),
        video_id: video_id,
        embed_url: embed_url,
        watch_url: watch_url,
        raw: element.data
      }

      {:ok, youtube, []}
    end
  end

  defp dispatch_mcq(%CustomElement{} = element) do
    data = normalise_keys(element.data)
    stem = Map.get(data, "stem", "")
    correct_key = Map.get(data, "correct")

    feedbacks =
      element.data
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        case parse_indexed_key(key, "feedback") do
          {:ok, index} ->
            Map.put(acc, index, %{key: key, text: value})

          :error ->
            acc
        end
      end)

    choices =
      element.data
      |> Enum.reduce([], fn {key, value}, acc ->
        case parse_indexed_key(key, "choice") do
          {:ok, index} ->
            feedback = Map.get(feedbacks, index)

            [
              %Mcq.Choice{
                id: key,
                index: index,
                text: value,
                feedback: feedback && feedback.text,
                feedback_key: feedback && feedback.key
              }
              | acc
            ]

          :error ->
            acc
        end
      end)
      |> Enum.sort_by(& &1.index)

    mcq = %Mcq{
      id: element.id,
      block_index: element.block_index,
      stem: stem,
      choices: choices,
      correct_key: correct_key,
      raw: element.data
    }

    {:ok, mcq, []}
  end

  defp derive_youtube_urls(source) do
    case extract_video_id(source) do
      {:ok, id} ->
        embed = "https://www.youtube.com/embed/#{id}"
        watch = "https://www.youtube.com/watch?v=#{id}"
        {id, embed, watch}

      :error ->
        {nil, nil, source}
    end
  end

  defp extract_video_id(source) do
    trimmed = String.trim(source)

    cond do
      trimmed == "" ->
        :error

      Regex.match?(~r/^[\w-]{11}$/, trimmed) ->
        {:ok, trimmed}

      true ->
        parse_uri_for_video_id(trimmed)
    end
  end

  defp parse_uri_for_video_id(source) do
    case URI.parse(source) do
      %URI{host: host, path: path, query: query} when is_binary(host) ->
        cond do
          host in ["youtu.be", "www.youtu.be"] ->
            id =
              path
              |> String.trim_leading("/")
              |> String.split("/", parts: 2)
              |> hd()
              |> String.trim()

            validate_video_id(id)

          host in ["youtube.com", "www.youtube.com", "m.youtube.com"] ->
            with {:ok, params} <- decode_query(query),
                 {:ok, id} <- Map.fetch(params, "v"),
                 {:ok, valid_id} <- validate_video_id(id) do
              {:ok, valid_id}
            else
              _ ->
                cond do
                  String.starts_with?(path || "", "/embed/") ->
                    id =
                      path
                      |> String.trim_leading("/embed/")
                      |> String.split("/", parts: 2)
                      |> hd()

                    validate_video_id(id)

                  true ->
                    :error
                end
            end

          true ->
            :error
        end

      _ ->
        :error
    end
  end

  defp decode_query(nil), do: {:error, :no_query}
  defp decode_query(query), do: {:ok, URI.decode_query(query)}

  defp validate_video_id(id) when is_binary(id) do
    trimmed = String.trim(id)

    if Regex.match?(~r/^[\w-]{11}$/, trimmed) do
      {:ok, trimmed}
    else
      :error
    end
  end

  defp validate_video_id(_), do: :error

  defp normalise_keys(data) do
    Enum.reduce(data, %{}, fn {key, value}, acc ->
      Map.put(acc, String.downcase(key), value)
    end)
  end

  defp parse_indexed_key(key, prefix) when is_binary(key) do
    downcased = String.downcase(key)

    case String.starts_with?(downcased, prefix) do
      true ->
        suffix = String.replace_prefix(downcased, prefix, "")

        with true <- suffix != "",
             true <- Regex.match?(~r/^\d+$/, suffix) do
          {:ok, String.to_integer(suffix)}
        else
          _ -> :error
        end

      false ->
        :error
    end
  end

  defp parse_indexed_key(_, _), do: :error
end

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
  @dropdown_marker ~r/\[(dropdown\d+)\]/i
  @dropdown_attribute ~r/^(dropdown\d+)-(.*)$/i

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

  defmodule CheckAllThatApply do
    @moduledoc """
    Normalised representation of a Check All That Apply custom element.
    """

    defmodule Choice do
      @moduledoc false
      @enforce_keys [:id, :index, :text]
      defstruct [:id, :index, :text]
    end

    @enforce_keys [:id, :block_index, :stem, :choices, :correct_keys, :raw]
    defstruct [
      :id,
      :block_index,
      :stem,
      :choices,
      :correct_keys,
      :correct_feedback,
      :incorrect_feedback,
      :raw
    ]
  end

  defmodule ShortAnswer do
    @moduledoc """
    Normalised representation of a Short Answer custom element.
    """

    defmodule Answer do
      @moduledoc false
      @enforce_keys [:value, :feedback, :correct?, :index]
      defstruct [:value, :feedback, :correct?, :index]
    end

    @enforce_keys [:id, :block_index, :stem, :answers, :input_type, :raw]
    defstruct [
      :id,
      :block_index,
      :stem,
      :answers,
      :input_type,
      :incorrect_feedback,
      :raw
    ]
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

  defmodule Dropdown do
    @moduledoc """
    Normalised representation of a dropdown question custom element.
    """

    @enforce_keys [:id, :block_index, :stem, :inputs, :data_by_input, :raw_rows]
    defstruct [
      :id,
      :block_index,
      :stem,
      :inputs,
      :data_by_input,
      :raw_rows
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
      "cata" -> dispatch_cata(element)
      "check_all_that_apply" -> dispatch_cata(element)
      "checkallthatapply" -> dispatch_cata(element)
      "short_answer" -> dispatch_short_answer(element)
      "shortanswer" -> dispatch_short_answer(element)
      "dropdown" -> dispatch_dropdown(element)
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

  defp dispatch_cata(%CustomElement{} = element) do
    data = normalise_keys(element.data)
    stem = Map.get(data, "stem", "")

    {choices, warnings} = extract_cata_choices(element.raw_rows)

    if choices == [] do
      warning =
        Warnings.build(:custom_element_invalid_shape, %{element_type: element.element_type})

      {:fallback, :invalid, [warning]}
    else
      {correct_keys, warnings} =
        data
        |> Map.get("correct", "")
        |> parse_correct_keys()
        |> validate_correct_keys(choices, warnings)

      if correct_keys == [] do
        warning =
          Warnings.build(:cata_missing_correct, %{
            element_type: element.element_type
          })

        {:fallback, :invalid, warnings ++ [warning]}
      else
        cata = %CheckAllThatApply{
          id: element.id,
          block_index: element.block_index,
          stem: stem,
          choices: choices,
          correct_keys: correct_keys,
          correct_feedback: string_or_nil(Map.get(data, "correct_feedback")),
          incorrect_feedback: string_or_nil(Map.get(data, "incorrect_feedback")),
          raw: element.raw_rows
        }

        {:ok, cata, Enum.reverse(warnings)}
      end
    end
  end

  defp dispatch_short_answer(%CustomElement{} = element) do
    data = normalise_keys(element.data)
    stem = Map.get(data, "stem", "")
    input_type = data |> Map.get("type", "text") |> to_string() |> String.downcase()

    {answers, warnings} = extract_short_answer_responses(element.raw_rows)

    if answers == [] do
      warning =
        Warnings.build(:short_answer_invalid_shape, %{
          element_type: element.element_type
        })

      {:fallback, :invalid, [warning]}
    else
      sa = %ShortAnswer{
        id: element.id,
        block_index: element.block_index,
        stem: stem,
        answers: answers,
        input_type: input_type,
        incorrect_feedback: string_or_nil(Map.get(data, "incorrect_feedback")),
        raw: element.raw_rows
      }

      {:ok, sa, Enum.reverse(warnings)}
    end
  end

  defp dispatch_dropdown(%CustomElement{} = element) do
    data = normalise_keys(element.data)
    stem = Map.get(data, "stem", "") |> to_string()

    inputs =
      @dropdown_marker
      |> Regex.scan(stem, capture: :all_but_first)
      |> Enum.flat_map(& &1)
      |> Enum.map(&String.downcase/1)

    if inputs == [] do
      warning =
        Warnings.build(:dropdown_missing_markers, %{
          element_type: element.element_type
        })

      {:fallback, :invalid, [warning]}
    else
      case duplicate_markers(inputs) do
        [] ->
          dropdown = %Dropdown{
            id: element.id,
            block_index: element.block_index,
            stem: stem,
            inputs: inputs,
            data_by_input: group_by_prefix(element.data),
            raw_rows: element.raw_rows
          }

          {:ok, dropdown, []}

        duplicates ->
          warning =
            Warnings.build(:dropdown_duplicate_markers, %{
              duplicates: Enum.join(duplicates, ", ")
            })

          {:fallback, :invalid, [warning]}
      end
    end
  end

  defp duplicate_markers(items) do
    items
    |> Enum.reduce({[], MapSet.new()}, fn item, {dupes, seen} ->
      if MapSet.member?(seen, item) do
        if item in dupes do
          {dupes, seen}
        else
          {[item | dupes], seen}
        end
      else
        {dupes, MapSet.put(seen, item)}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  # group_by_prefix(%{"dropdown1-choice1" => "Dog"})
  # => %{"dropdown1" => %{"choice1" => "Dog"}}
  @spec group_by_prefix(Enumerable.t()) :: map()
  defp group_by_prefix(entries) do
    Enum.reduce(entries, %{}, fn {key, value}, acc ->
      case Regex.run(@dropdown_attribute, to_string(key)) do
        [_, prefix, suffix] ->
          prefix = String.downcase(prefix)
          suffix = String.downcase(String.trim(suffix))

          if suffix == "" do
            acc
          else
            update_in(acc, [prefix], fn
              nil -> %{suffix => value}
              inner_map -> Map.put(inner_map, suffix, value)
            end)
          end

        _ ->
          acc
      end
    end)
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

  defp extract_cata_choices(rows) do
    Enum.reduce(rows, {[], []}, fn {key, value}, {choices, warnings} ->
      case parse_indexed_key(key, "choice") do
        {:ok, index} ->
          text = value |> to_string() |> String.trim()

          if text == "" do
            warning = Warnings.build(:cata_choice_missing, %{choice_key: key})
            {choices, [warning | warnings]}
          else
            choice = %CheckAllThatApply.Choice{id: String.downcase(key), index: index, text: text}
            {[choice | choices], warnings}
          end

        :error ->
          {choices, warnings}
      end
    end)
    |> then(fn {choices, warnings} ->
      {Enum.sort_by(choices, & &1.index), warnings}
    end)
  end

  defp parse_correct_keys(value) do
    value
    |> to_string()
    |> String.split([",", ";"], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&String.downcase/1)
  end

  defp validate_correct_keys(correct_keys, choices, warnings) do
    choice_lookup =
      choices
      |> Enum.reduce(%{}, fn %CheckAllThatApply.Choice{id: id} = choice, acc ->
        Map.put(acc, id, choice)
      end)

    Enum.reduce(correct_keys, {[], warnings}, fn key, {acc, warn_acc} ->
      case Map.fetch(choice_lookup, key) do
        {:ok, _choice} ->
          {[key | acc], warn_acc}

        :error ->
          warning = Warnings.build(:cata_missing_correct, %{correct_key: key})
          {acc, [warning | warn_acc]}
      end
    end)
    |> then(fn {keys, warn_acc} ->
      {Enum.reverse(keys), warn_acc}
    end)
  end

  defp extract_short_answer_responses(rows) do
    reserved_prefixes = ["hint"]

    reserved_keys =
      MapSet.new(["stem", "type", "incorrect_feedback", "correct_feedback", "submit_and_compare"])

    Enum.reduce(rows, {[], [], 0}, fn {key, value}, {answers, warnings, order} ->
      downcased = String.downcase(key)

      cond do
        Enum.any?(reserved_prefixes, &String.starts_with?(downcased, &1)) ->
          {answers, warnings, order}

        MapSet.member?(reserved_keys, downcased) ->
          {answers, warnings, order}

        true ->
          text = value |> to_string() |> String.trim()
          ans_key = key |> to_string() |> String.trim()

          if ans_key == "" do
            warning = Warnings.build(:short_answer_invalid_shape, %{answer_key: key})
            {answers, [warning | warnings], order}
          else
            answer = %ShortAnswer.Answer{
              value: ans_key,
              feedback: text,
              correct?: false,
              index: order
            }

            {[answer | answers], warnings, order + 1}
          end
      end
    end)
    |> then(fn {answers, warnings, _order} ->
      answers =
        answers
        |> Enum.sort_by(& &1.index)
        |> mark_first_answer_correct()

      {answers, warnings}
    end)
  end

  defp mark_first_answer_correct([]), do: []

  defp mark_first_answer_correct([first | rest]) do
    [%{first | correct?: true} | Enum.map(rest, &%{&1 | correct?: false})]
  end

  defp string_or_nil(nil), do: nil

  defp string_or_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp string_or_nil(value), do: value

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

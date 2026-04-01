defmodule Oli.Analytics.Summary.ResponseLabel do
  defstruct [
    :response,
    :label
  ]

  def build(_part_attempt, "oli_file_upload"), do: unsupported()
  def build(part_attempt, "oli_adaptive"), do: from_adaptive(part_attempt)
  def build(_part_attempt, "oli_embedded"), do: unsupported()
  def build(_part_attempt, "oli_image_coding"), do: unsupported()
  def build(_part_attempt, "oli_directed_discussion"), do: unsupported()

  def build(part_attempt, "oli_multiple_choice"), do: from_choices(part_attempt)
  def build(part_attempt, "oli_ordering"), do: from_choices(part_attempt)
  def build(part_attempt, "oli_check_all_that_apply"), do: from_choices(part_attempt)
  def build(part_attempt, "oli_image_hotspot"), do: from_choices(part_attempt)

  def build(part_attempt, "oli_custom_dnd") do
    parts_as_choices =
      part_attempt.activity_revision.content
      |> Map.get("authoring", %{})
      |> Map.get("parts", [])

    from_choices_helper(parts_as_choices, part_attempt, &letters_from_choices/2)
  end

  def build(part_attempt, "oli_likert") do
    order_descending =
      part_attempt.activity_revision.content
      |> Map.get("orderDescending", false)

    from_choices(part_attempt, fn choices, ids ->
      if order_descending do
        numbers_from_choices(Enum.reverse(choices), ids)
      else
        numbers_from_choices(choices, ids)
      end
    end)
  end

  def build(part_attempt, "oli_multi_input") do
    case Enum.find(part_attempt.activity_revision.content["inputs"], fn input ->
           input["partId"] == part_attempt.part_id
         end) do
      %{"inputType" => "text"} ->
        build(part_attempt, "oli_short_answer")

      %{"inputType" => "dropdown"} = input ->
        choices_for_this_part = Map.get(input, "choiceIds", []) |> MapSet.new()

        part_attempt.activity_revision.content
        |> Map.get("choices", [])
        |> Enum.filter(fn c -> MapSet.member?(choices_for_this_part, c["id"]) end)
        |> from_choices_helper(part_attempt, &letters_from_choices/2)

      %{"inputType" => "math"} ->
        build(part_attempt, "oli_short_answer")

      %{"inputType" => "numeric"} ->
        build(part_attempt, "oli_short_answer")

      %{"inputType" => "vlabvalue"} ->
        build(part_attempt, "oli_short_answer")

      _ ->
        unsupported()
    end
  end

  def build(part_attempt, "oli_vlab") do
    # identical to multi input, so delegate
    build(part_attempt, "oli_multi_input")
  end

  def build(part_attempt, "oli_response_multi") do
    # identical to multi input, so delegate
    build(part_attempt, "oli_multi_input")
  end

  def build(part_attempt, "oli_short_answer") do
    case part_attempt.response do
      %{"input" => input} when is_binary(input) ->
        to_struct(input, input)

      _ ->
        empty()
    end
  end

  def build(_part_attempt, _dynamically_registered), do: unsupported()

  defp from_adaptive(part_attempt) do
    part = find_adaptive_part(part_attempt)
    stage_values = normalize_stage_values(part_attempt.response)

    case Map.get(part || %{}, "type") do
      "janus-mcq" -> adaptive_choice_label(part_attempt, part, stage_values)
      "janus-dropdown" -> adaptive_dropdown_label(part_attempt, part, stage_values)
      "janus-fill-blanks" -> adaptive_fill_blanks_label(part_attempt, part, stage_values)
      _ -> adaptive_value_label(part_attempt, stage_values)
    end
  end

  defp from_choices(part_attempt, labeller \\ &letters_from_choices/2) do
    part_attempt.activity_revision.content
    |> Map.get("choices")
    |> from_choices_helper(part_attempt, labeller)
  end

  defp from_choices_helper(choices, part_attempt, labeller) do
    case part_attempt.response do
      %{"input" => nil} ->
        to_struct("No answer", "")

      %{"input" => input} when is_binary(input) ->
        labeller.(choices, String.split(input, " "))
        |> to_struct(input)

      _ ->
        to_struct("No answer", "")
    end
  end

  defp find_adaptive_part(part_attempt) do
    part_attempt.activity_revision.content
    |> Map.get("partsLayout", [])
    |> Enum.find(&(Map.get(&1, "id") == part_attempt.part_id))
  end

  defp adaptive_choice_label(part_attempt, part, stage_values) do
    choice_labels =
      part
      |> Map.get("custom", %{})
      |> Map.get("mcqItems", [])
      |> Enum.map(fn item ->
        item
        |> Map.get("nodes", [])
        |> extract_adaptive_text()
        |> blank_to_nil()
        |> case do
          nil -> "Option"
          label -> label
        end
      end)

    selected_indices =
      case stage_value(stage_values, part_attempt.part_id, "selectedChoices") do
        values when is_list(values) and values != [] ->
          Enum.map(values, &normalize_integer/1)

        _ ->
          [
            stage_value(stage_values, part_attempt.part_id, "selectedChoice")
            |> normalize_integer()
          ]
      end
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(&(&1 <= 0))

    selected_labels =
      case stage_value(stage_values, part_attempt.part_id, "selectedChoicesText") do
        values when is_list(values) and values != [] ->
          Enum.map(values, &to_string/1)

        _ ->
          case stage_value(stage_values, part_attempt.part_id, "selectedChoiceText") do
            value when is_binary(value) and value != "" ->
              [value]

            _ ->
              Enum.map(
                selected_indices,
                &(Enum.at(choice_labels, &1 - 1) || Integer.to_string(&1))
              )
          end
      end

    to_choice_struct(selected_indices, selected_labels)
  end

  defp adaptive_dropdown_label(part_attempt, part, stage_values) do
    option_labels = part |> Map.get("custom", %{}) |> Map.get("optionLabels", [])

    selected_index =
      stage_value(stage_values, part_attempt.part_id, "selectedIndex")
      |> normalize_integer()
      |> case do
        value when is_integer(value) and value > 0 -> value
        _ -> nil
      end

    selected_label =
      first_present([
        stage_value(stage_values, part_attempt.part_id, "selectedItem"),
        stage_value(stage_values, part_attempt.part_id, "value"),
        if(is_integer(selected_index), do: Enum.at(option_labels, selected_index - 1))
      ])

    case {selected_index, blank_to_nil(selected_label)} do
      {nil, nil} -> empty()
      {index, nil} -> to_struct(Integer.to_string(index), Integer.to_string(index))
      {nil, label} -> to_struct(label, label)
      {index, label} -> to_struct(label, Integer.to_string(index))
    end
  end

  defp adaptive_value_label(part_attempt, stage_values) do
    value =
      first_present([
        stage_value(stage_values, part_attempt.part_id, "text"),
        stage_value(stage_values, part_attempt.part_id, "value"),
        extract_input(part_attempt.response)
      ])

    case normalize_scalar_value(value) do
      nil -> empty()
      normalized -> to_struct(normalized, normalized)
    end
  end

  defp adaptive_fill_blanks_label(part_attempt, part, stage_values) do
    blank_entries =
      fill_blank_definitions(part, stage_values)
      |> Enum.map(fn %{index: index, label: label} ->
        value =
          stage_value(stage_values, part_attempt.part_id, "Input #{index}.Value")
          |> normalize_scalar_value()

        %{
          label: label,
          value: value
        }
      end)

    if Enum.all?(blank_entries, &is_nil(&1.value)) do
      empty()
    else
      response =
        blank_entries
        |> Enum.map_join(" | ", fn %{value: value} -> value || "[blank]" end)

      label =
        blank_entries
        |> Enum.map_join("; ", fn %{label: label, value: value} ->
          "#{label}: #{value || "No response"}"
        end)

      to_struct(label, response)
    end
  end

  defp to_choice_struct([], _selected_labels), do: empty()

  defp to_choice_struct(selected_indices, selected_labels) do
    response = Enum.map_join(selected_indices, " ", &Integer.to_string/1)

    label =
      selected_labels
      |> Enum.map(&to_string/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(", ")
      |> blank_to_nil()

    to_struct(label || response, response)
  end

  defp normalize_stage_values(response) when is_map(response) do
    Enum.reduce(response, %{}, fn {_key, entry}, acc ->
      case entry do
        %{"path" => path, "value" => value} -> Map.put(acc, normalize_stage_path(path), value)
        %{path: path, value: value} -> Map.put(acc, normalize_stage_path(path), value)
        _ -> acc
      end
    end)
  end

  defp normalize_stage_values(_), do: %{}

  defp normalize_stage_path(path) when is_binary(path) do
    path
    |> String.split("|stage")
    |> List.last()
    |> case do
      "." <> rest -> "stage." <> rest
      "stage" <> _ = value -> value
      value -> value
    end
  end

  defp stage_value(stage_values, part_id, key) do
    Map.get(stage_values, "stage.#{part_id}.#{key}") || Map.get(stage_values, key)
  end

  defp fill_blank_definitions(part, stage_values) do
    elements =
      part
      |> Map.get("custom", %{})
      |> Map.get("elements", [])
      |> Enum.with_index(1)
      |> Enum.map(fn {element, index} ->
        %{
          index: index,
          label: blank_to_nil(Map.get(element, "key")) || "Blank #{index}"
        }
      end)

    if elements == [] do
      inferred_fill_blank_definitions(stage_values)
    else
      elements
    end
  end

  defp inferred_fill_blank_definitions(stage_values) do
    stage_values
    |> Map.keys()
    |> Enum.reduce([], fn key, acc ->
      case Regex.run(~r/(?:^|\.)(?:Input )(\d+)\.Value$/, key, capture: :all_but_first) do
        [index] ->
          [String.to_integer(index) | acc]

        _ ->
          acc
      end
    end)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn index ->
      %{
        index: index,
        label: "Blank #{index}"
      }
    end)
  end

  defp extract_input(%{"input" => input}), do: input
  defp extract_input(%{input: input}), do: input
  defp extract_input(_), do: nil

  defp normalize_scalar_value(nil), do: nil
  defp normalize_scalar_value(value) when is_binary(value), do: blank_to_nil(value)
  defp normalize_scalar_value(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_scalar_value(value) when is_float(value), do: to_string(value)

  defp normalize_scalar_value(value) when is_list(value),
    do: value |> Enum.map(&to_string/1) |> Enum.join(", ") |> blank_to_nil()

  defp normalize_scalar_value(_), do: nil

  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp normalize_integer(_), do: nil

  defp extract_adaptive_text(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(&extract_adaptive_text/1)
    |> Enum.join("")
  end

  defp extract_adaptive_text(%{"text" => text}) when is_binary(text), do: text

  defp extract_adaptive_text(%{"children" => children}) when is_list(children),
    do: extract_adaptive_text(children)

  defp extract_adaptive_text(%{"nodes" => nodes}) when is_list(nodes),
    do: extract_adaptive_text(nodes)

  defp extract_adaptive_text(_), do: ""

  defp first_present(values) do
    Enum.find_value(values, fn value ->
      case normalize_scalar_value(value) do
        nil -> nil
        normalized -> normalized
      end
    end)
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    value = String.trim(value)
    if value == "", do: nil, else: value
  end

  defp blank_to_nil(value), do: value

  defp letters_from_choices(nil, _ids), do: "Empty"

  defp letters_from_choices(choices, ids) do
    choice_labels =
      Enum.with_index(choices)
      |> Enum.map(fn {choice, index} ->
        selected_choice =
          case choice do
            c when is_map(c) -> Map.get(choice, "id")
            _ -> nil
          end

        {selected_choice, <<index + 65::utf8>>}
      end)
      |> Map.new()

    Enum.map(ids, fn id -> Map.get(choice_labels, id) end)
    |> Enum.join(", ")
  end

  defp numbers_from_choices(choices, ids) do
    choice_labels =
      Enum.with_index(choices)
      |> Enum.map(fn {choice, index} -> {choice["id"], index + 1} end)
      |> Map.new()

    Enum.map(ids, fn id -> Map.get(choice_labels, id) end)
    |> Enum.join(", ")
  end

  defp to_struct(label, response) do
    %__MODULE__{
      response: response,
      label: label
    }
  end

  defp unsupported(), do: to_struct("unsupported", "unsupported")
  defp empty(), do: to_struct("No answer", "")
end

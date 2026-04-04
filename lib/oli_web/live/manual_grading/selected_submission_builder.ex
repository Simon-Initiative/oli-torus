defmodule OliWeb.ManualGrading.SelectedSubmissionBuilder do
  @moduledoc false

  alias Oli.Activities.AdaptiveParts

  @multi_input_slugs ~w(oli_multi_input oli_response_multi oli_vlab)
  @choice_activity_slugs ~w(
    oli_multiple_choice
    oli_check_all_that_apply
    oli_ordering
    oli_image_hotspot
    oli_likert
  )

  def build(nil, _part_attempts, _selected_part_attempt_guid, _activity_types_map), do: nil
  def build(_attempt, nil, _selected_part_attempt_guid, _activity_types_map), do: nil
  def build(_attempt, _part_attempts, nil, _activity_types_map), do: nil

  def build(attempt, part_attempts, selected_part_attempt_guid, activity_types_map) do
    case Enum.find(part_attempts, &(&1.attempt_guid == selected_part_attempt_guid)) do
      nil ->
        nil

      part_attempt ->
        activity_slug = activity_slug(attempt, activity_types_map)
        metadata = part_metadata(attempt, part_attempt, activity_slug)

        %{
          title: submission_title(activity_slug, part_attempts, part_attempt),
          subtitle: submission_subtitle(activity_slug, metadata, part_attempt),
          score: submission_score(part_attempt),
          response_view: build_submission_view(activity_slug, attempt, part_attempt, metadata)
        }
    end
  end

  def input_type_label(nil, _part_attempt, _activity_types_map), do: "Input"
  def input_type_label(_attempt, nil, _activity_types_map), do: "Input"

  def input_type_label(attempt, part_attempt, activity_types_map) do
    activity_slug = activity_slug(attempt, activity_types_map)
    metadata = part_metadata(attempt, part_attempt, activity_slug)

    case metadata do
      %{type: type} when is_binary(type) -> component_type_label(type)
      _ -> activity_type_label(activity_slug)
    end
  end

  defp activity_slug(attempt, activity_types_map) do
    activity_types_map
    |> Map.get(attempt.activity_type_id, %{})
    |> Map.get(:slug)
  end

  defp submission_title(activity_slug, part_attempts, part_attempt) do
    index =
      Enum.find_index(part_attempts, &(&1.attempt_guid == part_attempt.attempt_guid))
      |> case do
        nil -> nil
        value -> value + 1
      end

    cond do
      activity_slug == "oli_adaptive" and index ->
        "Screen Input #{index}"

      (activity_slug in @multi_input_slugs and index) && length(part_attempts) > 1 ->
        "Question Input #{index}"

      index && length(part_attempts) > 1 ->
        "Part #{index}"

      true ->
        "Question Response"
    end
  end

  defp submission_subtitle(activity_slug, metadata, part_attempt) do
    label =
      case metadata do
        %{type: type} when is_binary(type) -> component_type_label(type)
        _ -> activity_type_label(activity_slug)
      end

    "#{label} • Part ID: #{part_attempt.part_id}"
  end

  defp submission_score(part_attempt) do
    score =
      case part_attempt.score do
        nil -> "Pending"
        value -> value
      end

    out_of =
      case part_attempt.out_of do
        nil -> "Not Set"
        value -> value
      end

    "#{score} / #{out_of}"
  end

  defp build_submission_view("oli_adaptive", _attempt, part_attempt, %{
         type: "janus-mcq",
         part: part
       }) do
    build_adaptive_mcq_view(part_attempt, part)
  end

  defp build_submission_view(
         "oli_adaptive",
         _attempt,
         part_attempt,
         %{type: "janus-dropdown", part: part}
       ) do
    build_adaptive_dropdown_view(part_attempt, part)
  end

  defp build_submission_view(
         "oli_adaptive",
         _attempt,
         part_attempt,
         %{type: "janus-fill-blanks", part: part}
       ) do
    build_adaptive_fill_blanks_view(part_attempt, part)
  end

  defp build_submission_view(
         "oli_adaptive",
         _attempt,
         part_attempt,
         %{type: type, part: part}
       )
       when type in ["janus-input-text", "janus-multi-line-text"] do
    build_adaptive_prose_view(part_attempt, part)
  end

  defp build_submission_view(
         "oli_adaptive",
         _attempt,
         part_attempt,
         %{type: type, part: part}
       )
       when type in [
              "janus-input-number",
              "janus-slider",
              "janus-text-slider",
              "janus-formula"
            ] do
    build_adaptive_value_view(part_attempt, part)
  end

  defp build_submission_view(
         activity_slug,
         attempt,
         part_attempt,
         %{family: :multi_input} = metadata
       )
       when activity_slug in @multi_input_slugs do
    case metadata.type do
      "dropdown" ->
        build_multi_input_dropdown_view(attempt, part_attempt, metadata)

      type when type in ["text", "numeric", "math", "vlabvalue"] ->
        build_multi_input_value_view(attempt, part_attempt, metadata)

      _ ->
        build_generic_submission_view(part_attempt)
    end
  end

  defp build_submission_view(activity_slug, attempt, part_attempt, _metadata)
       when activity_slug in @choice_activity_slugs do
    build_regular_choice_view(activity_slug, attempt, part_attempt)
  end

  defp build_submission_view("oli_short_answer", attempt, part_attempt, _metadata) do
    build_regular_prose_view("oli_short_answer", attempt, part_attempt)
  end

  defp build_submission_view(activity_slug, attempt, part_attempt, _metadata) do
    case extract_input_value(part_attempt) do
      nil ->
        build_generic_submission_view(part_attempt)

      _value ->
        build_regular_value_view(activity_slug, attempt, part_attempt)
    end
  end

  defp part_metadata(attempt, part_attempt, "oli_adaptive") do
    part = AdaptiveParts.part_definition(attempt.revision.content, part_attempt.part_id)

    if AdaptiveParts.scorable_part?(part) do
      %{family: :adaptive, part: part, type: part["type"]}
    end
  end

  defp part_metadata(attempt, part_attempt, activity_slug)
       when activity_slug in @multi_input_slugs do
    content = attempt.revision.content || %{}

    input =
      content
      |> Map.get("inputs", [])
      |> Enum.find(&(&1["partId"] == part_attempt.part_id))

    authored_part =
      content
      |> Map.get("authoring", %{})
      |> Map.get("parts", [])
      |> Enum.find(&(&1["id"] == part_attempt.part_id))

    if is_map(input) or is_map(authored_part) do
      %{
        family: :multi_input,
        input: input,
        part: authored_part,
        type: input && input["inputType"],
        prompt: multi_input_prompt(content, input)
      }
    end
  end

  defp part_metadata(_attempt, _part_attempt, _activity_slug), do: nil

  defp build_adaptive_mcq_view(part_attempt, part_definition) do
    config = part_config(part_definition)
    choice_labels = extract_adaptive_mcq_choice_labels(config)
    selected_labels = extract_adaptive_selected_labels(part_attempt, choice_labels)

    %{
      kind: :choice_list,
      prompt: adaptive_submission_prompt(part_definition),
      description:
        if(Map.get(config, "multipleSelection"),
          do: "Multiple selection response",
          else: "Single selection response"
        ),
      selected_summary: empty_fallback(selected_labels, "No option selected"),
      choices:
        Enum.with_index(choice_labels, 1)
        |> Enum.map(fn {label, index} ->
          %{
            label: label,
            selected:
              label in selected_labels or index in extract_adaptive_selected_indices(part_attempt)
          }
        end)
    }
  end

  defp build_adaptive_dropdown_view(part_attempt, part_definition) do
    config = part_config(part_definition)

    selected =
      first_present([
        extract_stage_value(part_attempt, "selectedItem"),
        extract_stage_value(part_attempt, "value"),
        extract_input_value(part_attempt)
      ])

    %{
      kind: :choice_list,
      prompt: adaptive_submission_prompt(part_definition),
      description: blank_to_nil(Map.get(config, "prompt")) || "Dropdown response",
      selected_summary: empty_fallback(selected && [selected], "No option selected"),
      choices:
        Enum.map(Map.get(config, "optionLabels", []), fn label ->
          %{label: label, selected: label == selected}
        end)
    }
  end

  defp build_adaptive_fill_blanks_view(part_attempt, part_definition) do
    config = part_config(part_definition)
    stage_values = normalize_stage_values(part_attempt)

    blanks =
      Map.get(config, "elements", [])
      |> Enum.with_index(1)
      |> Enum.map(fn {element, index} ->
        value = Map.get(stage_values, "Input #{index}.Value")
        correctness = Map.get(stage_values, "Input #{index}.Correct")

        %{
          label: Map.get(element, "key") || "Blank #{index}",
          value: format_submission_value(value) || "No response recorded",
          meta:
            case correctness do
              true -> "Correct"
              false -> "Incorrect"
              _ -> nil
            end
        }
      end)

    %{
      kind: :fill_blanks,
      prompt: adaptive_submission_prompt(part_definition),
      description: "Blank-by-blank learner response",
      blanks: blanks
    }
  end

  defp build_adaptive_value_view(part_attempt, part_definition) do
    config = part_config(part_definition)
    part_type = Map.get(part_definition, "type")
    value = extract_primary_value(part_attempt)

    details =
      []
      |> maybe_add_detail("Prompt", blank_to_nil(Map.get(config, "prompt")))
      |> maybe_add_detail("Range", format_value_range(config, part_type))
      |> maybe_add_detail("Selected Label", slider_label(config, value, part_type))

    %{
      kind: :value,
      prompt: adaptive_submission_prompt(part_definition),
      description: component_type_label(part_type),
      value: format_submission_value(value) || "No response recorded",
      details: details
    }
  end

  defp build_adaptive_prose_view(part_attempt, part_definition) do
    config = part_config(part_definition)

    %{
      kind: :prose,
      prompt: adaptive_submission_prompt(part_definition),
      description: component_type_label(Map.get(part_definition, "type")),
      value:
        format_submission_value(extract_primary_value(part_attempt)) || "No response recorded",
      details:
        []
        |> maybe_add_detail("Prompt", blank_to_nil(Map.get(config, "prompt")))
    }
  end

  defp build_multi_input_dropdown_view(attempt, part_attempt, metadata) do
    choices =
      attempt.revision.content
      |> Map.get("choices", [])
      |> choices_for_ids(Map.get(metadata.input || %{}, "choiceIds", []))

    selected_tokens = normalize_input_tokens(extract_input_value(part_attempt))
    selected_labels = extract_selected_choice_labels(selected_tokens, choices)

    %{
      kind: :choice_list,
      prompt: metadata.prompt || "Dropdown response",
      description: "Dropdown response",
      selected_summary: empty_fallback(selected_labels, "No option selected"),
      choices:
        Enum.map(choices, fn choice ->
          %{label: choice.label, selected: choice_selected?(choice, selected_tokens)}
        end)
    }
  end

  defp build_multi_input_value_view(_attempt, part_attempt, metadata) do
    %{
      kind: :value,
      prompt: metadata.prompt || component_type_label(metadata.type),
      description: component_type_label(metadata.type),
      value: format_submission_value(extract_input_value(part_attempt)) || "No response recorded",
      details: []
    }
  end

  defp build_regular_choice_view(activity_slug, attempt, part_attempt) do
    choices =
      attempt.revision.content
      |> Map.get("choices", [])
      |> Enum.map(fn choice ->
        %{id: choice["id"], label: extract_choice_label(choice)}
      end)

    selected_tokens = normalize_input_tokens(extract_input_value(part_attempt))
    selected_labels = extract_selected_choice_labels(selected_tokens, choices)

    %{
      kind: :choice_list,
      prompt: regular_prompt(attempt.revision.content) || activity_type_label(activity_slug),
      description: regular_choice_description(activity_slug, selected_tokens),
      selected_summary: empty_fallback(selected_labels, "No option selected"),
      choices:
        Enum.map(choices, fn choice ->
          %{label: choice.label, selected: choice_selected?(choice, selected_tokens)}
        end)
    }
  end

  defp build_regular_value_view(activity_slug, attempt, part_attempt) do
    %{
      kind: :value,
      prompt: regular_prompt(attempt.revision.content) || "Recorded Submission",
      description: activity_type_label(activity_slug),
      value: format_submission_value(extract_input_value(part_attempt)) || "No response recorded",
      details:
        part_attempt.response
        |> normalize_response_entries()
        |> Enum.reject(&(&1.label == "Response"))
    }
  end

  defp build_regular_prose_view(activity_slug, attempt, part_attempt) do
    %{
      kind: :prose,
      prompt: regular_prompt(attempt.revision.content) || "Recorded Submission",
      description: activity_type_label(activity_slug),
      value: format_submission_value(extract_input_value(part_attempt)) || "No response recorded",
      details:
        part_attempt.response
        |> normalize_response_entries()
        |> Enum.reject(&(&1.label == "Response"))
    }
  end

  defp build_generic_submission_view(part_attempt) do
    details =
      part_attempt.response
      |> normalize_response_entries()
      |> case do
        [] -> [%{label: "Response", value: "No response recorded"}]
        entries -> entries
      end

    %{
      kind: :details,
      prompt: "Recorded Submission",
      description: "Submission data for this input",
      details: details
    }
  end

  defp regular_choice_description("oli_check_all_that_apply", _tokens),
    do: "Multiple selection response"

  defp regular_choice_description("oli_ordering", _tokens),
    do: "Recorded order"

  defp regular_choice_description("oli_likert", _tokens),
    do: "Scale response"

  defp regular_choice_description(_activity_slug, selected_tokens) do
    if length(selected_tokens) > 1,
      do: "Multiple selection response",
      else: "Single selection response"
  end

  defp choice_selected?(choice, selected_tokens) do
    choice.id in selected_tokens or choice.label in selected_tokens
  end

  defp extract_selected_choice_labels(selected_tokens, choices) do
    label_map = Map.new(choices, &{&1.id, &1.label})
    Enum.map(selected_tokens, fn token -> Map.get(label_map, token, token) end)
  end

  defp choices_for_ids(all_choices, choice_ids) do
    choice_map = Map.new(all_choices, &{&1["id"], &1})

    Enum.map(choice_ids, fn id ->
      choice = Map.get(choice_map, id, %{})
      %{id: id, label: extract_choice_label(choice)}
    end)
  end

  defp extract_choice_label(choice) do
    choice
    |> Map.get("content", [])
    |> extract_rich_text()
    |> blank_to_nil()
    |> case do
      nil -> "Option"
      label -> label
    end
  end

  defp part_config(part), do: Map.get(part, "custom", %{})

  defp component_type_label(nil), do: "Input"
  defp component_type_label("dropdown"), do: "Dropdown"
  defp component_type_label("numeric"), do: "Number"
  defp component_type_label("math"), do: "Math"
  defp component_type_label("text"), do: "Text"
  defp component_type_label("vlabvalue"), do: "Value"

  defp component_type_label(type) do
    type
    |> String.replace_prefix("janus-", "")
    |> String.replace("-", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp activity_type_label("oli_multiple_choice"), do: "Multiple Choice"
  defp activity_type_label("oli_check_all_that_apply"), do: "Check All That Apply"
  defp activity_type_label("oli_ordering"), do: "Ordering"
  defp activity_type_label("oli_image_hotspot"), do: "Image Hotspot"
  defp activity_type_label("oli_likert"), do: "Likert"
  defp activity_type_label("oli_short_answer"), do: "Short Answer"
  defp activity_type_label("oli_multi_input"), do: "Multi Input"
  defp activity_type_label("oli_response_multi"), do: "Response Multi"
  defp activity_type_label("oli_vlab"), do: "VLab"
  defp activity_type_label(nil), do: "Input"

  defp activity_type_label(activity_slug) do
    activity_slug
    |> String.replace_prefix("oli_", "")
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp adaptive_submission_prompt(part) do
    config = part_config(part)

    blank_to_nil(Map.get(config, "label")) ||
      blank_to_nil(Map.get(config, "title")) ||
      blank_to_nil(Map.get(config, "prompt")) ||
      component_type_label(Map.get(part, "type"))
  end

  defp multi_input_prompt(_content, nil), do: nil

  defp multi_input_prompt(content, input) do
    first_present([
      find_input_prompt(
        Map.get(content, "stem", %{}) |> Map.get("content", []),
        Map.get(input, "id")
      ),
      component_type_label(Map.get(input, "inputType"))
    ])
  end

  defp regular_prompt(content) do
    content
    |> Map.get("stem", %{})
    |> Map.get("content", [])
    |> extract_rich_text()
    |> blank_to_nil()
  end

  defp find_input_prompt(nodes, input_id) when is_list(nodes) do
    Enum.find_value(nodes, &find_input_prompt(&1, input_id))
  end

  defp find_input_prompt(%{"content" => content}, input_id) when is_list(content) do
    Enum.find_value(content, &find_input_prompt(&1, input_id))
  end

  defp find_input_prompt(%{"children" => children}, input_id) when is_list(children) do
    if Enum.any?(children, &input_ref?(&1, input_id)) do
      children
      |> Enum.reject(&input_ref?(&1, input_id))
      |> extract_rich_text()
      |> blank_to_nil()
    else
      Enum.find_value(children, &find_input_prompt(&1, input_id))
    end
  end

  defp find_input_prompt(_, _input_id), do: nil

  defp input_ref?(%{"type" => "input_ref", "id" => id}, input_id), do: id == input_id
  defp input_ref?(_, _input_id), do: false

  defp extract_adaptive_mcq_choice_labels(config) do
    Map.get(config, "mcqItems", [])
    |> Enum.map(fn item ->
      item
      |> Map.get("nodes", [])
      |> extract_rich_text()
      |> blank_to_nil()
      |> case do
        nil -> "Option"
        label -> label
      end
    end)
  end

  defp extract_adaptive_selected_labels(part_attempt, choice_labels) do
    case extract_stage_value(part_attempt, "selectedChoicesText") do
      values when is_list(values) and values != [] ->
        Enum.map(values, &to_string/1)

      _ ->
        case extract_stage_value(part_attempt, "selectedChoiceText") do
          value when is_binary(value) and value != "" ->
            [value]

          _ ->
            case extract_input_value(part_attempt) do
              nil ->
                []

              value when is_binary(value) ->
                value
                |> String.split(~r/[,\s]+/, trim: true)
                |> Enum.map(fn token ->
                  case normalize_integer(token) do
                    nil -> token
                    index -> Enum.at(choice_labels, index - 1) || token
                  end
                end)

              value when is_list(value) ->
                Enum.map(value, &to_string/1)

              _ ->
                []
            end
        end
    end
  end

  defp extract_adaptive_selected_indices(part_attempt) do
    case extract_stage_value(part_attempt, "selectedChoices") do
      values when is_list(values) and values != [] -> Enum.map(values, &normalize_integer/1)
      _ -> [extract_stage_value(part_attempt, "selectedChoice") |> normalize_integer()]
    end
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_stage_values(part_attempt) do
    case part_attempt.response do
      response when is_map(response) ->
        response
        |> Map.values()
        |> Enum.reduce(%{}, fn entry, acc ->
          case entry do
            %{"path" => path, "value" => value} ->
              Map.put(acc, normalize_stage_path(path), value)

            %{path: path, value: value} ->
              Map.put(acc, normalize_stage_path(path), value)

            _ ->
              acc
          end
        end)

      _ ->
        %{}
    end
  end

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

  defp extract_stage_value(part_attempt, key) do
    stage_values = normalize_stage_values(part_attempt)
    prefix = "stage.#{part_attempt.part_id}."

    Map.get(stage_values, prefix <> key) ||
      Map.get(stage_values, key)
  end

  defp extract_input_value(%{response: %{"input" => input}}), do: input
  defp extract_input_value(%{response: %{input: input}}), do: input
  defp extract_input_value(_), do: nil

  defp extract_primary_value(part_attempt) do
    first_present([
      extract_stage_value(part_attempt, "text"),
      extract_stage_value(part_attempt, "value"),
      extract_input_value(part_attempt)
    ])
  end

  defp normalize_input_tokens(nil), do: []
  defp normalize_input_tokens(value) when is_list(value), do: Enum.map(value, &to_string/1)

  defp normalize_input_tokens(value) when is_binary(value) do
    value
    |> String.split(~r/[,\s]+/, trim: true)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_input_tokens(value), do: [to_string(value)]

  defp format_value_range(config, part_type)
       when part_type in ["janus-slider", "janus-text-slider"] do
    minimum = Map.get(config, "minimum")
    maximum = Map.get(config, "maximum")

    if is_nil(minimum) or is_nil(maximum), do: nil, else: "#{minimum} to #{maximum}"
  end

  defp format_value_range(_config, _part_type), do: nil

  defp slider_label(config, value, "janus-text-slider") do
    labels = Map.get(config, "sliderOptionLabels", [])

    case normalize_integer(value) do
      nil ->
        nil

      index ->
        minimum = Map.get(config, "minimum", 0)
        Enum.at(labels, index - minimum)
    end
  end

  defp slider_label(_config, _value, _part_type), do: nil

  defp normalize_response_entries(nil), do: []

  defp normalize_response_entries(%{"input" => input, "files" => files} = response) do
    []
    |> maybe_add_detail("Response", format_submission_value(input))
    |> maybe_add_detail("Files", format_submission_files(files))
    |> Kernel.++(
      response
      |> Map.drop(["input", "files"])
      |> normalize_map_details()
    )
  end

  defp normalize_response_entries(response) when is_map(response),
    do: normalize_map_details(response)

  defp normalize_response_entries(response),
    do: [%{label: "Response", value: to_string(response)}]

  defp normalize_map_details(map) do
    Enum.flat_map(map, fn {key, value} ->
      case format_submission_value(value) do
        nil -> []
        formatted -> [%{label: humanize_key(key), value: formatted}]
      end
    end)
  end

  defp maybe_add_detail(details, _label, nil), do: details

  defp maybe_add_detail(details, label, value),
    do: details ++ [%{label: label, value: value}]

  defp humanize_key(key) when is_atom(key), do: key |> Atom.to_string() |> humanize_key()

  defp humanize_key(key) when is_binary(key) do
    key
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp humanize_key(key), do: key |> to_string() |> humanize_key()

  defp format_submission_value(nil), do: nil
  defp format_submission_value(""), do: nil
  defp format_submission_value(value) when is_binary(value), do: value
  defp format_submission_value(value) when is_number(value), do: to_string(value)
  defp format_submission_value(true), do: "true"
  defp format_submission_value(false), do: "false"

  defp format_submission_value(value) when is_list(value),
    do: Enum.map_join(value, "\n", &format_submission_value/1)

  defp format_submission_value(value) when is_map(value) do
    value
    |> Enum.map_join("\n", fn {key, inner_value} ->
      "#{humanize_key(key)}: #{format_submission_value(inner_value)}"
    end)
  end

  defp format_submission_value(value), do: to_string(value)

  defp format_submission_files(files) when is_list(files) do
    files
    |> Enum.map(&Map.get(&1, "name", "Attachment"))
    |> empty_fallback("No files uploaded")
  end

  defp format_submission_files(_), do: nil

  defp empty_fallback(values, fallback) when is_list(values) do
    values
    |> Enum.reject(&(&1 in [nil, ""]))
    |> case do
      [] -> fallback
      filtered -> Enum.join(filtered, ", ")
    end
  end

  defp empty_fallback(value, fallback) when value in [nil, ""], do: fallback
  defp empty_fallback(value, _fallback), do: value

  defp first_present(values) do
    Enum.find(values, &(not is_nil(blank_to_nil(&1))))
  end

  defp normalize_integer(nil), do: nil
  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_float(value) do
    trunc(value)
  end

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp normalize_integer(_value), do: nil

  defp extract_rich_text(nodes) when is_list(nodes) do
    nodes
    |> Enum.map_join(" ", &extract_rich_text/1)
    |> normalize_whitespace()
  end

  defp extract_rich_text(%{"text" => text}) when is_binary(text), do: text

  defp extract_rich_text(%{"children" => children}) when is_list(children),
    do: extract_rich_text(children)

  defp extract_rich_text(%{"content" => content}) when is_list(content),
    do: extract_rich_text(content)

  defp extract_rich_text(_), do: ""

  defp normalize_whitespace(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value
end

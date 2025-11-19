defmodule Oli.GoogleDocs.DropdownBuilder do
  @moduledoc """
  Builds Torus `oli_multi_input` activities with dropdown inputs from parsed Google Docs
  dropdown custom elements.
  """
  @behaviour Oli.GoogleDocs.ActivityBuilder

  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.GoogleDocs.ActivityBuilder.Utils
  alias Oli.GoogleDocs.CustomElements.Dropdown
  alias Oli.GoogleDocs.DropdownBuilder.ChoiceSpec
  alias Oli.GoogleDocs.Warnings

  @type build_option ::
          {:project_slug, String.t()}
          | {:author, Oli.Accounts.Author.t()}
          | {:activity_editor, module()}
          | {:title, String.t()}

  defmodule Result do
    @moduledoc """
    Outcome of building a dropdown (multi-input) activity.
    """

    @enforce_keys [:dropdown, :model, :revision, :warnings]
    defstruct [:dropdown, :model, :revision, :activity_content, :warnings]
  end

  defmodule ChoiceSpec do
    @moduledoc false

    @enforce_keys [:id, :original_id, :index, :text, :feedback]
    defstruct [:id, :original_id, :index, :text, :feedback]
  end

  @default_hint_count 3
  @dropdown_marker ~r/\[(dropdown\d+)\]/i

  @impl true
  def supported?(%Dropdown{}), do: true
  def supported?(_), do: false

  @doc """
  Validates the dropdown payload and creates an `oli_multi_input` activity within the project.

  Returns `{:ok, %Result{}}` on success or `{:error, reason, warnings}` when the dropdown should
  fall back to table rendering.
  """
  @spec build(Dropdown.t(), [build_option()]) :: {:ok, Result.t()} | {:error, atom(), list(map())}
  @impl true
  def build(%Dropdown{} = dropdown, opts) do
    project_slug = Keyword.fetch!(opts, :project_slug)
    author = Keyword.fetch!(opts, :author)
    activity_editor = Keyword.get(opts, :activity_editor, ActivityEditor)
    title = Keyword.get(opts, :title, default_title(dropdown))

    with {:ok, model, warnings} <- build_model(dropdown) do
      case activity_editor.create(
             project_slug,
             "oli_multi_input",
             author,
             model,
             [],
             "embedded",
             title
           ) do
        {:ok, {revision, transformed}} ->
          result = %Result{
            dropdown: dropdown,
            model: model,
            revision: revision,
            activity_content: transformed,
            warnings: warnings
          }

          {:ok, result}

        {:error, reason} ->
          {:error, :activity_creation_failed, warnings ++ [activity_creation_warning(reason)]}

        {:error, reason, data} ->
          {:error, :activity_creation_failed,
           warnings ++ [activity_creation_warning({reason, data})]}
      end
    else
      {:error, reason, warnings} when is_list(warnings) ->
        {:error, reason, warnings}
    end
  end

  defp activity_creation_warning(reason) do
    Warnings.build(:dropdown_activity_creation_failed, %{reason: inspect(reason)})
  end

  defp default_title(%Dropdown{stem: stem}) do
    stem
    |> to_string()
    |> String.trim()
    |> String.slice(0, 60)
  end

  defp build_model(%Dropdown{} = dropdown) do
    with {:ok, payload} <- build_parts(dropdown) do
      stem = build_stem(dropdown.stem)

      model = %{
        "stem" => stem,
        "choices" => payload.choices,
        "inputs" => payload.inputs,
        "submitPerPart" => true,
        "authoring" => %{
          "version" => 2,
          "targeted" => payload.targeted,
          "parts" => payload.parts,
          "previewText" => dropdown.stem || "",
          "transformations" => []
        }
      }

      {:ok, model, payload.warnings}
    end
  end

  defp build_stem(stem_text) do
    stem_map = Utils.make_content_map(stem_text || "")
    content = Map.get(stem_map, "content", [])
    Map.put(stem_map, "content", replace_dropdown_markers(content))
  end

  defp replace_dropdown_markers(nodes) when is_list(nodes) do
    nodes
    |> Enum.flat_map(&replace_dropdown_markers/1)
  end

  defp replace_dropdown_markers(%{"children" => children} = node) do
    [%{node | "children" => replace_dropdown_markers(children)}]
  end

  defp replace_dropdown_markers(%{"text" => text} = node) when is_binary(text) do
    segments = Regex.split(@dropdown_marker, text, include_captures: true, trim: false)
    attrs = Map.drop(node, ["text"])

    segments
    |> Enum.flat_map(fn segment ->
      case Regex.run(@dropdown_marker, segment) do
        [_, id] ->
          [build_input_ref(String.downcase(id))]

        _ ->
          if segment == "" do
            []
          else
            [Map.put(attrs, "text", segment)]
          end
      end
    end)
    |> case do
      [] -> [Map.put(attrs, "text", "")]
      list -> list
    end
  end

  defp replace_dropdown_markers(node), do: [node]

  defp build_input_ref(id) do
    %{
      "type" => "input_ref",
      "id" => id,
      "children" => [%{"text" => ""}]
    }
  end

  defp build_parts(%Dropdown{} = dropdown) do
    initial = %{parts: [], inputs: [], choices: [], targeted: [], warnings: []}

    dropdown.inputs
    |> Enum.reduce_while({:ok, initial}, fn input_id, {:ok, acc} ->
      attrs = Map.get(dropdown.data_by_input, input_id)

      if is_nil(attrs) do
        warning = Warnings.build(:dropdown_missing_input_data, %{input: input_id})
        {:halt, {:error, :missing_input_data, acc.warnings ++ [warning]}}
      else
        case build_part(input_id, attrs) do
          {:ok, part_payload} ->
            updated = %{
              parts: [part_payload.part | acc.parts],
              inputs: [part_payload.input | acc.inputs],
              choices: acc.choices ++ part_payload.choices,
              targeted: acc.targeted ++ part_payload.targeted,
              warnings: acc.warnings ++ part_payload.warnings
            }

            {:cont, {:ok, updated}}

          {:error, reason, part_warnings} ->
            {:halt, {:error, reason, acc.warnings ++ part_warnings}}
        end
      end
    end)
    |> case do
      {:ok, payload} ->
        {:ok,
         %{
           parts: Enum.reverse(payload.parts),
           inputs: Enum.reverse(payload.inputs),
           choices: payload.choices,
           targeted: payload.targeted,
           warnings: payload.warnings
         }}

      {:error, reason, warnings} ->
        {:error, reason, warnings}
    end
  end

  defp build_part(part_id, attrs) do
    normalized = normalize_part_attrs(attrs)

    with {:ok, choices, warnings} <- build_choices(part_id, normalized),
         {:ok, correct_choice_id} <- resolve_correct_choice(part_id, normalized, choices) do
      {responses, targeted} = build_responses(choices, correct_choice_id)

      part = %{
        "id" => part_id,
        "responses" => responses ++ [build_catch_all_response()],
        "scoringStrategy" => "best",
        "hints" => build_hints(normalized)
      }

      input = %{
        "id" => part_id,
        "inputType" => "dropdown",
        "partId" => part_id,
        "choiceIds" => Enum.map(choices, & &1.id)
      }

      choice_models = Enum.map(choices, &choice_to_model/1)

      {:ok,
       %{
         part: part,
         input: input,
         choices: choice_models,
         targeted: targeted,
         warnings: warnings
       }}
    else
      {:error, reason, warnings} -> {:error, reason, warnings}
    end
  end

  defp build_choices(part_id, attrs) do
    {choices, warnings} =
      Enum.reduce(attrs, {[], []}, fn {key, value}, {acc, warn_acc} ->
        case parse_indexed_suffix(key, "choice") do
          {:ok, index} ->
            text = trimmed(value)

            if text == "" do
              choice_key = "#{part_id}-#{key}"
              warning = Warnings.build(:dropdown_choice_missing, %{choice_key: choice_key})
              {acc, [warning | warn_acc]}
            else
              {feedback, warn_acc} =
                build_feedback(part_id, index, Map.get(attrs, "feedback#{index}"), warn_acc)

              choice = %ChoiceSpec{
                id: qualified_choice_id(part_id, index),
                original_id: "choice#{index}",
                index: index,
                text: text,
                feedback: feedback
              }

              {[choice | acc], warn_acc}
            end

          :error ->
            {acc, warn_acc}
        end
      end)

    sorted = Enum.sort_by(choices, & &1.index)

    if length(sorted) < 2 do
      warning = Warnings.build(:dropdown_insufficient_choices, %{input: part_id})
      {:error, :insufficient_choices, Enum.reverse([warning | warnings])}
    else
      {:ok, sorted, Enum.reverse(warnings)}
    end
  end

  defp resolve_correct_choice(part_id, attrs, choices) do
    raw = trimmed(Map.get(attrs, "correct"))

    cond do
      raw == "" ->
        {:error, :missing_correct, [Warnings.build(:dropdown_missing_correct, %{input: part_id})]}

      true ->
        downcased = String.downcase(raw)

        case Enum.find(choices, &(String.downcase(&1.original_id) == downcased)) do
          nil ->
            {:error, :missing_correct,
             [Warnings.build(:dropdown_missing_correct, %{input: part_id})]}

          choice ->
            {:ok, choice.id}
        end
    end
  end

  defp build_responses(choices, correct_choice_id) do
    choices
    |> Enum.reduce({[], []}, fn choice, {responses, targeted} ->
      response_id = Utils.unique_id()
      score = if choice.id == correct_choice_id, do: 1.0, else: 0.0

      response = %{
        "id" => response_id,
        "rule" => "input like {#{choice.id}}",
        "score" => score,
        "feedback" => choice.feedback
      }

      targeted =
        if score == 0.0 do
          [[[choice.id], response_id] | targeted]
        else
          targeted
        end

      {[response | responses], targeted}
    end)
    |> then(fn {responses, targeted} -> {Enum.reverse(responses), Enum.reverse(targeted)} end)
  end

  defp build_feedback(part_id, index, value, warnings) do
    text = trimmed(value)
    feedback_key = "#{part_id}-feedback#{index}"

    if text == "" do
      warning = Warnings.build(:dropdown_feedback_missing, %{feedback_key: feedback_key})
      {Utils.empty_feedback(), [warning | warnings]}
    else
      {Utils.make_content_map(text), warnings}
    end
  end

  defp build_hints(attrs) do
    hints =
      attrs
      |> Enum.reduce([], fn {key, value}, acc ->
        case parse_indexed_suffix(key, "hint") do
          {:ok, index} ->
            text = trimmed(value)

            if text == "" do
              acc
            else
              [{index, Utils.make_content_map(text)} | acc]
            end

          :error ->
            acc
        end
      end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(&elem(&1, 1))

    needed = max(@default_hint_count - length(hints), 0)
    hints ++ Enum.map(1..needed, fn _ -> Utils.make_content_map("") end)
  end

  defp build_catch_all_response do
    %{
      "id" => Utils.unique_id(),
      "rule" => "input like {.*}",
      "score" => 0.0,
      "feedback" => Utils.make_content_map("Incorrect")
    }
  end

  defp choice_to_model(%ChoiceSpec{id: id, text: text}) do
    Utils.make_content_map(text)
    |> Map.put("id", id)
  end

  defp normalize_part_attrs(attrs) do
    Enum.reduce(attrs, %{}, fn {key, value}, acc ->
      Map.put(acc, String.downcase(to_string(key)), value)
    end)
  end

  defp parse_indexed_suffix(key, prefix) when is_binary(key) do
    downcased = String.downcase(key)

    if String.starts_with?(downcased, prefix) do
      suffix = String.replace_prefix(downcased, prefix, "")

      if suffix != "" and Regex.match?(~r/^\d+$/, suffix) do
        {:ok, String.to_integer(suffix)}
      else
        :error
      end
    else
      :error
    end
  end

  defp parse_indexed_suffix(_, _), do: :error

  defp trimmed(nil), do: ""
  defp trimmed(value) when is_binary(value), do: String.trim(value)
  defp trimmed(value), do: value |> to_string() |> String.trim()

  defp qualified_choice_id(part_id, index), do: "#{part_id}_choice#{index}"
end

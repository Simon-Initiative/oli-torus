defmodule Oli.GoogleDocs.CheckAllThatApplyBuilder do
  @moduledoc """
  Builds Check All That Apply activities from Google Docs custom elements.
  """
  @behaviour Oli.GoogleDocs.ActivityBuilder

  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.GoogleDocs.ActivityBuilder.Utils
  alias Oli.GoogleDocs.CustomElements.CheckAllThatApply
  alias Oli.GoogleDocs.CustomElements.CheckAllThatApply.Choice
  alias Oli.GoogleDocs.Warnings

  @type build_option ::
          {:project_slug, String.t()}
          | {:author, Oli.Accounts.Author.t()}
          | {:activity_editor, module()}
          | {:title, String.t()}

  defmodule Result do
    @moduledoc """
    Outcome of building a Check All That Apply activity.
    """

    @enforce_keys [:cata, :model, :revision, :warnings]
    defstruct [:cata, :model, :revision, :activity_content, :warnings]
  end

  @impl true
  def supported?(%CheckAllThatApply{}), do: true
  def supported?(_), do: false

  @impl true
  def build(%CheckAllThatApply{} = cata, opts) do
    project_slug = Keyword.fetch!(opts, :project_slug)
    author = Keyword.fetch!(opts, :author)
    activity_editor = Keyword.get(opts, :activity_editor, ActivityEditor)
    title = Keyword.get(opts, :title, default_title(cata))

    {choices, warnings} = normalise_choices(cata.choices)

    with {:ok, choices} <- ensure_minimum_choices(choices, warnings),
         {:ok, correct_ids, warnings} <- resolve_correct(choices, cata.correct_keys, warnings),
         {:ok, model, warnings} <- build_model(cata, choices, correct_ids, warnings),
         {:ok, {revision, transformed}} <-
           activity_editor.create(
             project_slug,
             "oli_check_all_that_apply",
             author,
             model,
             [],
             "embedded",
             title
           ) do
      result = %Result{
        cata: cata,
        model: model,
        revision: revision,
        activity_content: transformed,
        warnings: warnings
      }

      {:ok, result}
    else
      {:error, reason, builder_warnings} when is_list(builder_warnings) ->
        {:error, reason, builder_warnings}

      {:error, reason} ->
        {:error, :activity_creation_failed,
         [
           Warnings.build(:cata_activity_creation_failed, %{reason: inspect(reason)})
         ]}
    end
  end

  defp normalise_choices(choices) do
    Enum.reduce(choices, {[], []}, fn %Choice{} = choice, {acc, warnings} ->
      text = choice.text |> to_string() |> String.trim()

      cond do
        text == "" ->
          warning = Warnings.build(:cata_choice_missing, %{choice_key: choice.id})
          {acc, [warning | warnings]}

        true ->
          updated = %Choice{choice | text: text, id: String.downcase(choice.id)}
          {[updated | acc], warnings}
      end
    end)
  end

  defp ensure_minimum_choices(choices, warnings) do
    if length(choices) < 2 do
      warning = Warnings.build(:custom_element_invalid_shape, %{element_type: "cata"})
      {:error, :insufficient_choices, warnings ++ [warning]}
    else
      {:ok, Enum.sort_by(choices, & &1.index)}
    end
  end

  defp resolve_correct(choices, correct_keys, warnings) do
    choice_lookup =
      choices
      |> Enum.reduce(%{}, fn %Choice{id: id} = choice, acc ->
        Map.put(acc, String.downcase(id), choice)
      end)

    {ids, warnings} =
      Enum.reduce(correct_keys, {[], warnings}, fn key, {acc, warn_acc} ->
        normalised = key |> to_string() |> String.trim() |> String.downcase()

        case Map.fetch(choice_lookup, normalised) do
          {:ok, %Choice{id: id}} ->
            {[id | acc], warn_acc}

          :error ->
            warning = Warnings.build(:cata_missing_correct, %{correct_key: key})
            {acc, [warning | warn_acc]}
        end
      end)

    ids = Enum.reverse(ids)

    if ids == [] do
      warning = Warnings.build(:cata_missing_correct, %{})
      {:error, :missing_correct, warnings ++ [warning]}
    else
      {:ok, ids, warnings}
    end
  end

  defp build_model(cata, choices, correct_ids, warnings) do
    choice_models =
      Enum.map(choices, fn %Choice{id: id, text: text} ->
        Utils.make_content_map(text)
        |> Map.put("id", id)
      end)

    all_choice_ids = Enum.map(choices, & &1.id)

    correct_response =
      %{
        "id" => Utils.unique_id(),
        "rule" => match_list_rule(all_choice_ids, correct_ids),
        "score" => 1.0,
        "feedback" => feedback_map(cata.correct_feedback, "Correct"),
        "correct" => true
      }

    responses = [correct_response, catch_all_response(cata.incorrect_feedback)]

    part = %{
      "id" => Utils.unique_id(),
      "scoringStrategy" => "best",
      "responses" => responses,
      "hints" => Utils.parse_hints(cata.raw, default_count: 3)
    }

    model = %{
      "stem" => Utils.make_content_map(cata.stem || ""),
      "choices" => choice_models,
      "authoring" => %{
        "version" => 2,
        "parts" => [part],
        "correct" => [correct_ids, correct_response["id"]],
        "targeted" => [],
        "transformations" => [],
        "previewText" => cata.stem || ""
      }
    }

    {:ok, model, warnings}
  end

  defp catch_all_response(feedback_text) do
    %{
      "id" => Utils.unique_id(),
      "rule" => "input like {.*}",
      "score" => 0.0,
      "feedback" => feedback_map(feedback_text, "Incorrect")
    }
  end

  defp match_list_rule(all_ids, ids_to_match) do
    positives = Enum.map(ids_to_match, &match_rule/1)
    negatives = Enum.map(all_ids -- ids_to_match, &invert_rule(match_rule(&1)))
    rules = positives ++ negatives

    case rules do
      [] -> ".*"
      [single] -> single
      [first | rest] -> Enum.reduce(rest, first, fn rule, acc -> "#{rule} && (#{acc})" end)
    end
  end

  defp match_rule(id), do: "input like {#{escape_input(id)}}"

  defp invert_rule(rule), do: "(!(#{rule}))"

  defp escape_input(text) do
    text
    |> to_string()
    |> String.replace(~r/[\\{}]/, fn <<char>> -> "\\#{<<char>>}" end)
  end

  defp feedback_map(value, default) do
    text =
      value
      |> case do
        nil ->
          default

        string ->
          trimmed = string |> to_string() |> String.trim()

          if trimmed == "" do
            default
          else
            string
          end
      end

    Utils.make_content_map(text)
  end

  defp default_title(%CheckAllThatApply{stem: stem}) do
    stem
    |> to_string()
    |> String.trim()
    |> String.slice(0, 60)
  end
end

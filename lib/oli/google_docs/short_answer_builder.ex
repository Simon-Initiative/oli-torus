defmodule Oli.GoogleDocs.ShortAnswerBuilder do
  @moduledoc """
  Builds short answer activities from Google Docs custom elements.
  """
  @behaviour Oli.GoogleDocs.ActivityBuilder

  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.GoogleDocs.ActivityBuilder.Utils
  alias Oli.GoogleDocs.CustomElements.ShortAnswer
  alias Oli.GoogleDocs.CustomElements.ShortAnswer.Answer
  alias Oli.GoogleDocs.Warnings

  @type build_option ::
          {:project_slug, String.t()}
          | {:author, Oli.Accounts.Author.t()}
          | {:activity_editor, module()}
          | {:title, String.t()}

  defmodule Result do
    @moduledoc """
    Outcome of building a short answer activity.
    """

    @enforce_keys [:short_answer, :model, :revision, :warnings]
    defstruct [:short_answer, :model, :revision, :activity_content, :warnings]
  end

  @impl true
  def supported?(%ShortAnswer{}), do: true
  def supported?(_), do: false

  @impl true
  def build(%ShortAnswer{} = short_answer, opts) do
    project_slug = Keyword.fetch!(opts, :project_slug)
    author = Keyword.fetch!(opts, :author)
    activity_editor = Keyword.get(opts, :activity_editor, ActivityEditor)
    title = Keyword.get(opts, :title, default_title(short_answer))

    {answers, warnings} = normalise_answers(short_answer.answers)

    with {:ok, answers, warnings} <- ensure_answers(answers, warnings),
         {:ok, model, warnings} <- build_model(short_answer, answers, warnings),
         {:ok, {revision, transformed}} <-
           activity_editor.create(
             project_slug,
             "oli_short_answer",
             author,
             model,
             [],
             "embedded",
             title
           ) do
      result = %Result{
        short_answer: short_answer,
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
         [Warnings.build(:short_answer_activity_creation_failed, %{reason: inspect(reason)})]}
    end
  end

  defp normalise_answers(answers) do
    Enum.reduce(answers, {[], []}, fn %Answer{} = answer, {acc, warnings} ->
      value = answer.value |> to_string() |> String.trim()
      feedback = answer.feedback |> to_string() |> String.trim()

      cond do
        value == "" ->
          warning = Warnings.build(:short_answer_invalid_shape, %{answer_key: answer.value})
          {acc, [warning | warnings]}

        true ->
          updated = %Answer{answer | value: value, feedback: feedback}
          {[updated | acc], warnings}
      end
    end)
  end

  defp ensure_answers([], warnings) do
    warning = Warnings.build(:short_answer_invalid_shape, %{reason: "no answers"})
    {:error, :no_answers, warnings ++ [warning]}
  end

  defp ensure_answers(answers, warnings) do
    {:ok, Enum.sort_by(answers, & &1.index), warnings}
  end

  defp build_model(%ShortAnswer{} = sa, answers, warnings) do
    input_type = normalise_input_type(sa.input_type)

    {responses, warnings} = build_responses(answers, input_type, warnings)

    catch_all = catch_all_response(sa.incorrect_feedback)

    part = %{
      "id" => Utils.unique_id(),
      "scoringStrategy" => "best",
      "responses" => responses ++ [catch_all],
      "hints" => Utils.parse_hints(sa.raw, default_count: 3)
    }

    model = %{
      "stem" => Utils.make_content_map(sa.stem || ""),
      "inputType" => input_type,
      "authoring" => %{
        "parts" => [part],
        "transformations" => [],
        "previewText" => sa.stem || ""
      }
    }

    {:ok, model, warnings}
  end

  defp build_responses(answers, input_type, warnings) do
    Enum.reduce(answers, {[], warnings}, fn %Answer{} = answer, {acc, warn_acc} ->
      rule = rule_for_answer(answer.value, input_type)
      score = if answer.correct?, do: 1.0, else: 0.0

      feedback_text =
        if answer.feedback == "", do: default_feedback(answer.correct?), else: answer.feedback

      response = %{
        "id" => Utils.unique_id(),
        "rule" => rule,
        "score" => score,
        "feedback" => Utils.make_content_map(feedback_text),
        "correct" => answer.correct?
      }

      {[response | acc], warn_acc}
    end)
    |> then(fn {responses, warn_acc} ->
      {Enum.reverse(responses), warn_acc}
    end)
  end

  defp catch_all_response(feedback_text) do
    feedback =
      feedback_text
      |> case do
        nil ->
          "Incorrect"

        text ->
          trimmed = text |> to_string() |> String.trim()

          if trimmed == "" do
            "Incorrect"
          else
            text
          end
      end

    %{
      "id" => Utils.unique_id(),
      "rule" => "input like {.*}",
      "score" => 0.0,
      "feedback" => Utils.make_content_map(feedback)
    }
  end

  defp rule_for_answer(value, "numeric") do
    trimmed = String.trim(value)
    "input = {#{trimmed}}"
  end

  defp rule_for_answer(value, _type) do
    escaped = escape_input(value)
    "input contains {#{escaped}}"
  end

  defp normalise_input_type(type) when is_binary(type) do
    case String.downcase(String.trim(type)) do
      "numeric" -> "numeric"
      "number" -> "numeric"
      "textarea" -> "textarea"
      "math" -> "math"
      _ -> "text"
    end
  end

  defp normalise_input_type(_), do: "text"

  defp escape_input(value) do
    value
    |> to_string()
    |> String.replace(~r/[\\{}]/, fn <<char>> -> "\\#{<<char>>}" end)
  end

  defp default_feedback(true), do: "Correct"
  defp default_feedback(false), do: "Incorrect"

  defp default_title(%ShortAnswer{stem: stem}) do
    stem
    |> to_string()
    |> String.trim()
    |> String.slice(0, 60)
  end
end

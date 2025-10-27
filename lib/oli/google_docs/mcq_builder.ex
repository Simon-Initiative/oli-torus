defmodule Oli.GoogleDocs.McqBuilder do
  @moduledoc """
  Builds Torus multiple-choice activities from parsed Google Docs MCQ custom
  elements. The builder validates required fields, applies sensible defaults,
  and delegates persistence to the authoring activity editor.
  """
  @behaviour Oli.GoogleDocs.ActivityBuilder

  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.GoogleDocs.ActivityBuilder.Utils
  alias Oli.GoogleDocs.CustomElements.Mcq
  alias Oli.GoogleDocs.CustomElements.Mcq.Choice
  alias Oli.GoogleDocs.Warnings

  @type build_option ::
          {:project_slug, String.t()}
          | {:author, Oli.Accounts.Author.t()}
          | {:activity_editor, module()}
          | {:title, String.t()}

  defmodule Result do
    @moduledoc """
    Outcome of building an MCQ activity.
    """

    @enforce_keys [:mcq, :model, :revision, :warnings]
    defstruct [:mcq, :model, :revision, :activity_content, :warnings]
  end

  @impl true
  def supported?(%Mcq{}), do: true
  def supported?(_), do: false

  @doc """
  Validates the MCQ payload and creates an `oli_multiple_choice` activity within
  the project.

  Returns `{:ok, %Result{}}` on success or `{:error, reason, warnings}` when the
  MCQ should fall back to table rendering.
  """
  @spec build(Mcq.t(), [build_option()]) ::
          {:ok, Result.t()} | {:error, atom(), list(map())}
  @impl true
  def build(%Mcq{} = mcq, opts) do
    project_slug = Keyword.fetch!(opts, :project_slug)
    author = Keyword.fetch!(opts, :author)
    activity_editor = Keyword.get(opts, :activity_editor, ActivityEditor)
    title = Keyword.get(opts, :title, default_title(mcq))

    {choices, warnings} = normalise_choices(mcq.choices)
    warnings = Enum.reverse(warnings)

    with {:ok, choices} <- ensure_minimum_choices(choices, warnings),
         {:ok, correct_id} <- resolve_correct_key(mcq.correct_key, choices, warnings),
         {:ok, model, warnings} <-
           build_model(mcq, choices, correct_id, warnings),
         {:ok, {revision, transformed}} <-
           activity_editor.create(
             project_slug,
             "oli_multiple_choice",
             author,
             model,
             [],
             "embedded",
             title
           ) do
      result = %Result{
        mcq: mcq,
        model: model,
        revision: revision,
        activity_content: transformed,
        warnings: warnings
      }

      {:ok, result}
    else
      {:error, reason, warnings} when is_list(warnings) ->
        {:error, reason, warnings}

      {:error, reason} ->
        {:error, :activity_creation_failed, warnings ++ [activity_creation_warning(reason)]}

      {:error, reason, data} ->
        {:error, :activity_creation_failed,
         warnings ++ [activity_creation_warning({reason, data})]}
    end
  end

  defp activity_creation_warning(reason) do
    Warnings.build(:mcq_activity_creation_failed, %{
      reason: inspect(reason)
    })
  end

  defp default_title(%Mcq{stem: stem}) do
    stem
    |> to_string()
    |> String.trim()
    |> String.slice(0, 60)
  end

  defp normalise_choices(choices) do
    {acc, warnings} =
      Enum.reduce(choices, {[], []}, fn %Choice{} = choice, {acc, warnings} ->
        trimmed = choice.text |> to_string() |> String.trim()

        if trimmed == "" do
          warning =
            Warnings.build(:mcq_choice_missing, %{
              choice_key: choice.id
            })

          {acc, [warning | warnings]}
        else
          {[%Choice{choice | text: trimmed} | acc], warnings}
        end
      end)

    {Enum.reverse(acc), warnings}
  end

  defp ensure_minimum_choices(choices, warnings) when length(choices) < 2 do
    warning =
      Warnings.build(:custom_element_invalid_shape, %{
        element_type: "mcq"
      })

    {:error, :insufficient_choices, warnings ++ [warning]}
  end

  defp ensure_minimum_choices(choices, _warnings), do: {:ok, choices}

  defp resolve_correct_key(correct_key, choices, warnings) do
    key =
      correct_key
      |> to_string()
      |> String.trim()

    cond do
      key == "" ->
        warning = Warnings.build(:mcq_missing_correct, %{})
        {:error, :missing_correct, warnings ++ [warning]}

      true ->
        downcased = String.downcase(key)

        case Enum.find(choices, fn choice ->
               String.downcase(choice.id) == downcased
             end) do
          nil ->
            warning =
              Warnings.build(:mcq_missing_correct, %{
                correct_key: correct_key
              })

            {:error, :missing_correct, warnings ++ [warning]}

          %Choice{id: id} ->
            {:ok, id}
        end
    end
  end

  defp build_model(mcq, choices, correct_id, warnings) do
    {choice_models, response_models, warnings, targeted} =
      Enum.reduce(choices, {[], [], warnings, []}, fn %Choice{} = choice,
                                                      {choice_acc, response_acc, warn_acc,
                                                       targeted_acc} ->
        choice_model =
          Utils.make_content_map(choice.text)
          |> Map.put("id", choice.id)

        {feedback, new_warnings} = build_feedback(choice)

        response_id = Utils.unique_id()

        response_model = %{
          "id" => response_id,
          "rule" => "input like {#{choice.id}}",
          "score" => score_for(choice.id, correct_id),
          "feedback" => feedback
        }

        targeted_acc =
          if choice.id == correct_id do
            targeted_acc
          else
            [[[choice.id], response_id] | targeted_acc]
          end

        {[choice_model | choice_acc], [response_model | response_acc], warn_acc ++ new_warnings,
         targeted_acc}
      end)

    responses = Enum.reverse(response_models) ++ [build_catch_all_response()]

    part = %{
      "id" => Utils.unique_id(),
      "responses" => responses,
      "scoringStrategy" => "best",
      "hints" => build_hints(mcq)
    }

    model = %{
      "stem" => Utils.make_content_map(mcq.stem || ""),
      "choices" => Enum.reverse(choice_models),
      "authoring" => %{
        "version" => 2,
        "targeted" => targeted |> Enum.reverse(),
        "parts" => [part],
        "previewText" => mcq.stem || "",
        "transformations" => []
      }
    }

    {:ok, model, warnings}
  end

  defp build_feedback(%Choice{} = choice) do
    case choice.feedback do
      nil ->
        {Utils.empty_feedback(), [missing_feedback_warning(choice)]}

      feedback_text ->
        trimmed = feedback_text |> to_string() |> String.trim()

        if trimmed == "" do
          {Utils.empty_feedback(), [missing_feedback_warning(choice)]}
        else
          {Utils.make_content_map(trimmed), []}
        end
    end
  end

  defp score_for(choice_id, correct_id) when choice_id == correct_id, do: 1.0
  defp score_for(_, _), do: 0.0

  @default_hint_count 3

  defp build_hints(%Mcq{raw: raw}) do
    Utils.parse_hints(raw, default_count: @default_hint_count)
  end

  defp missing_feedback_warning(%Choice{feedback_key: key, id: choice_id}) do
    Warnings.build(:mcq_feedback_missing, %{
      feedback_key: key || default_feedback_key(choice_id)
    })
  end

  defp default_feedback_key(nil), do: "feedback"

  defp default_feedback_key(choice_id) do
    "feedback_for_#{choice_id}"
  end

  defp build_catch_all_response do
    %{
      "id" => Utils.unique_id(),
      "rule" => "input like {.*}",
      "score" => 0.0,
      "feedback" => Utils.make_content_map("Incorrect")
    }
  end
end

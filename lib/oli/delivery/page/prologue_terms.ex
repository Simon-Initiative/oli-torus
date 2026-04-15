defmodule Oli.Delivery.Page.PrologueTerms do
  @moduledoc """
  Shared builder for prologue terms.

  Produces the ordered term list used by the student prologue UI and scenario
  assertions.
  """

  alias OliWeb.Common.FormatDateTime

  def build(effective_settings, ctx, has_scheduled_resources?) do
    [
      due_term(effective_settings, ctx, has_scheduled_resources?),
      score_as_you_go_term(effective_settings),
      scoring_term(effective_settings),
      question_attempts_term(effective_settings),
      time_limit_term(effective_settings),
      submit_term(effective_settings)
    ]
    |> Enum.reject(&is_nil/1)
  end

  def parse_minutes(minutes) when minutes <= 60, do: to_minutes(minutes)

  def parse_minutes(minutes) when minutes > 60 do
    hours = div(minutes, 60)
    minutes = rem(minutes, 60)

    if minutes != 0,
      do: "#{to_hours(hours)} and #{to_minutes(minutes)}",
      else: "#{to_hours(hours)}"
  end

  defp due_term(%{end_date: nil}, _ctx, false), do: nil

  defp due_term(%{end_date: nil}, _ctx, true) do
    term("page_due_terms", [{:text, "This assignment is "}, {:strong, "not yet scheduled."}])
  end

  defp due_term(%{end_date: end_date, start_date: start_date, scheduling_type: scheduling_type}, ctx, _?) do
    verb_form =
      case DateTime.compare(DateTime.utc_now(), end_date) do
        :gt -> "was"
        :lt -> "is"
      end

    available_verb_form =
      cond do
        is_nil(start_date) -> "is"
        DateTime.compare(DateTime.utc_now(), start_date) == :gt -> "was"
        true -> "is"
      end

    segments =
      if start_date do
        [
          {:text, "This assignment #{available_verb_form} available on "},
          {:strong, format_available_datetime(start_date, ctx)},
          {:text, " and #{verb_form} #{scheduling_type_phrase(scheduling_type)} "},
          {:strong, format_due_datetime(end_date, ctx)}
        ]
      else
        [
          {:text, "This assignment is available "},
          {:strong, "Now"},
          {:text, " and #{verb_form} #{scheduling_type_phrase(scheduling_type)} "},
          {:strong, format_due_datetime(end_date, ctx)}
        ]
      end

    term("page_due_terms", segments)
  end

  defp score_as_you_go_term(%{batch_scoring: false}) do
    term(
      "score_as_you_go_term",
      [{:strong, "Score as you go:"}, {:text, " your score is updated as you complete questions on this page."}]
    )
  end

  defp score_as_you_go_term(_), do: nil

  defp scoring_term(effective_settings) do
    policy_text =
      if effective_settings.batch_scoring, do: "this assignment", else: "each question"

    strategy_text =
      case effective_settings.scoring_strategy_id do
        1 -> "the average of your attempts"
        2 -> "determined by your best attempt"
        3 -> "determined by your last attempt"
        4 -> "determined by the total sum of your attempts"
        _ -> "determined by your best attempt"
      end

    term(
      "page_scoring_terms",
      [{:text, "For #{policy_text}, your score will be #{strategy_text}."}]
    )
  end

  defp question_attempts_term(%{batch_scoring: true}), do: nil

  defp question_attempts_term(%{max_attempts: 0}) do
    term(
      "question_attempts",
      [{:text, "You can attempt each question "}, {:strong, "unlimited"}, {:text, " times."}]
    )
  end

  defp question_attempts_term(%{max_attempts: 1}) do
    term(
      "question_attempts",
      [{:text, "You can attempt each question "}, {:strong, "1"}, {:text, " time."}]
    )
  end

  defp question_attempts_term(%{max_attempts: max_attempts}) do
    term(
      "question_attempts",
      [{:text, "You can attempt each question "}, {:strong, "#{max_attempts}"}, {:text, " times."}]
    )
  end

  defp time_limit_term(%{time_limit: time_limit}) when is_integer(time_limit) and time_limit > 0 do
    term(
      "page_time_limit_term",
      [
        {:text, "You have "},
        {:strong, parse_minutes(time_limit)},
        {:text, " to complete the assessment from the time you begin."}
      ]
    )
  end

  defp time_limit_term(_), do: nil

  defp submit_term(%{late_submit: :allow, time_limit: 0, scheduling_type: :due_by}) do
    term("page_submit_term", [{:text, "If you submit after the due date, it will be marked late."}])
  end

  defp submit_term(%{late_submit: :allow, time_limit: time_limit})
       when time_limit not in ["nil", 0] do
    term("page_submit_term", [{:text, "If you exceed this time, it will be marked late."}])
  end

  defp submit_term(_), do: nil

  defp term(id, segments) do
    %{
      id: id,
      segments: segments,
      text:
        segments
        |> Enum.map(fn {_kind, value} -> value end)
        |> Enum.join("")
        |> String.replace(~r/\s+/, " ")
        |> String.trim()
    }
  end

  defp format_available_datetime(datetime, ctx),
    do: FormatDateTime.to_formatted_datetime(datetime, ctx, "{WDshort} {Mshort} {D}, {YYYY} at {h12}:{m}{am}.")

  defp format_due_datetime(datetime, ctx),
    do: FormatDateTime.to_formatted_datetime(datetime, ctx, "{WDshort} {Mshort} {D}, {YYYY} by {h12}:{m}{am}.")

  defp scheduling_type_phrase(:due_by), do: "due on"
  defp scheduling_type_phrase(_), do: "suggested by"

  defp to_minutes(1), do: "1 minute"
  defp to_minutes(minutes), do: "#{minutes} minutes"
  defp to_hours(1), do: "1 hour"
  defp to_hours(hours), do: "#{hours} hours"
end

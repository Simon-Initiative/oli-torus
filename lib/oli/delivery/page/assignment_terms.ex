defmodule Oli.Delivery.Page.AssignmentTerms do
  @moduledoc """
  Builds the grouped Assignment Terms view model for the student prologue page.

  This module intentionally contains no HEEx. It centralizes the conditional
  card visibility, labels, and copy so the prologue UI can render the Figma
  grouped-card layout without embedding assessment-setting rules in templates.
  """

  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Settings.Combined
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Common.SessionContext

  @type formatted_segment :: {:text | :strong, String.t()}

  @type schedule_card :: %{
          available: String.t() | nil,
          due: String.t() | nil,
          late_submission:
            nil
            | %{
                state: :default | :warning,
                title: String.t(),
                segments: [formatted_segment],
                text: String.t()
              }
        }

  @type time_limit_card :: %{
          minutes: pos_integer(),
          duration: String.t(),
          segments: [formatted_segment],
          text: String.t()
        }

  @type scoring_card :: %{
          mode: :score_at_end | :score_as_you_go,
          strategy: :average | :best | :most_recent | :total,
          segments: [formatted_segment],
          text: String.t()
        }

  @type attempts_card :: %{
          title: String.t(),
          value: String.t(),
          description: String.t() | nil,
          cta_label: String.t(),
          cta_enabled?: boolean(),
          past_attempts: [past_attempt]
        }

  @type past_attempt :: %{
          number: pos_integer(),
          score: number() | nil,
          out_of: number() | nil,
          submitted_at: String.t() | nil,
          lifecycle_state: atom() | nil,
          attempt_guid: String.t() | nil
        }

  @type t :: %{
          schedule: schedule_card | nil,
          time_limit: time_limit_card | nil,
          scoring: scoring_card | nil,
          attempts: attempts_card
        }

  @full_datetime "{WDfull}, {Mfull} {D}, {YYYY} at {h12}:{m}{am} {Z}"
  @submitted_date "{WDshort} {Mshort} {D}, {YYYY}"

  @spec build(Combined.t(), [ResourceAttempt.t()], SessionContext.t(), keyword()) :: t()
  def build(
        %Combined{} = effective_settings,
        historical_attempts,
        %SessionContext{} = ctx,
        opts \\ []
      ) do
    graded_attempts = graded_attempts(historical_attempts)
    attempts_taken = length(graded_attempts)
    allow_attempt? = Keyword.get(opts, :allow_attempt?, true)

    %{
      schedule: schedule_card(effective_settings, ctx),
      time_limit: time_limit_card(effective_settings),
      scoring: scoring_card(effective_settings),
      attempts:
        attempts_card(effective_settings, graded_attempts, attempts_taken, ctx, allow_attempt?)
    }
  end

  defp schedule_card(%Combined{} = effective_settings, ctx) do
    available = available_value(effective_settings, ctx)
    due = due_value(effective_settings, ctx)
    late_submission = late_submission(effective_settings)

    case {available, due, late_submission} do
      {nil, nil, nil} ->
        nil

      _ ->
        %{
          available: available,
          due: due,
          late_submission: late_submission
        }
    end
  end

  defp available_value(%Combined{start_date: nil, end_date: nil}, _ctx), do: nil
  defp available_value(%Combined{start_date: nil}, _ctx), do: "Now"

  defp available_value(%Combined{start_date: start_date}, ctx),
    do: FormatDateTime.to_formatted_datetime(start_date, ctx, @full_datetime)

  defp due_value(%Combined{end_date: nil}, _ctx), do: nil

  defp due_value(%Combined{end_date: end_date}, ctx),
    do: FormatDateTime.to_formatted_datetime(end_date, ctx, @full_datetime)

  defp late_submission(%Combined{late_start: :disallow, late_submit: :disallow}), do: nil

  defp late_submission(%Combined{end_date: end_date} = effective_settings)
       when not is_nil(end_date) do
    if due_date_passed?(effective_settings) do
      late_submission_card(:warning, [
        {:text, "The due date has passed. If you start a "},
        {:strong, "new attempt"},
        {:text, ", it will be "},
        {:strong, "marked late."}
      ])
    else
      late_submission_card(:default, [
        {:text, "Submissions "},
        {:strong, "past the due date"},
        {:text, " will be "},
        {:strong, "marked late"}
      ])
    end
  end

  defp late_submission(%Combined{time_limit: time_limit})
       when is_integer(time_limit) and time_limit > 0 do
    late_submission_card(:default, [
      {:text, "Submissions "},
      {:strong, "past the time limit"},
      {:text, " will be "},
      {:strong, "marked late"}
    ])
  end

  defp late_submission(_), do: nil

  defp late_submission_card(state, segments) do
    %{
      state: state,
      title: "Late Submissions",
      segments: segments,
      text: segment_text(segments)
    }
  end

  defp due_date_passed?(%Combined{end_date: end_date}),
    do: DateTime.compare(DateTime.utc_now(), end_date) == :gt

  defp time_limit_card(%Combined{time_limit: time_limit})
       when is_integer(time_limit) and time_limit > 0 do
    duration = Oli.Delivery.Page.PrologueTerms.parse_minutes(time_limit)

    segments = [
      {:strong, duration},
      {:text, " to complete once you begin"}
    ]

    %{
      minutes: time_limit,
      duration: duration,
      segments: segments,
      text: segment_text(segments)
    }
  end

  defp time_limit_card(_), do: nil

  defp scoring_card(%Combined{batch_scoring: true, max_attempts: 1}), do: nil

  defp scoring_card(%Combined{} = effective_settings) do
    strategy = scoring_strategy(effective_settings.scoring_strategy_id)

    %{
      mode: scoring_mode(effective_settings),
      strategy: strategy,
      segments: scoring_segments(effective_settings, strategy),
      text: scoring_segments(effective_settings, strategy) |> segment_text()
    }
  end

  defp scoring_mode(%Combined{batch_scoring: true}), do: :score_at_end
  defp scoring_mode(%Combined{batch_scoring: false}), do: :score_as_you_go

  defp scoring_segments(%Combined{batch_scoring: true, max_attempts: max_attempts}, strategy) do
    [
      {:text, "Your final score will be your "},
      {:strong, score_at_end_strategy_text(strategy, max_attempts)}
    ]
  end

  defp scoring_segments(
         %Combined{batch_scoring: false, max_attempts: max_attempts} = settings,
         strategy
       ) do
    [
      {:strong, "Score as you go: "},
      {:text,
       "Each question is submitted and scored individually. You have #{attempts_per_question_text(max_attempts)} per question. "},
      dynamic_replacement_segments(settings),
      {:text, "Your "},
      {:strong, score_as_you_go_strategy_text(strategy)},
      {:text, " for each question will count toward your final score."}
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  defp dynamic_replacement_segments(%Combined{replacement_strategy: :dynamic}),
    do: [
      {:text, "Resetting may give you a "},
      {:strong, "new version"},
      {:text, " of the question. "}
    ]

  defp dynamic_replacement_segments(_), do: nil

  defp attempts_card(effective_settings, graded_attempts, attempts_taken, ctx, allow_attempt?) do
    %{
      title: attempts_title(effective_settings),
      value: attempts_value(effective_settings, attempts_taken),
      description: attempts_description(effective_settings),
      cta_label: cta_label(effective_settings, attempts_taken),
      cta_enabled?: allow_attempt?,
      past_attempts:
        graded_attempts
        |> Enum.with_index(1)
        |> Enum.map(fn {attempt, index} -> past_attempt(attempt, index, ctx) end)
    }
  end

  defp attempts_title(%Combined{batch_scoring: false}), do: "Attempts per question"
  defp attempts_title(_), do: "Attempts"

  defp attempts_value(%Combined{batch_scoring: false, max_attempts: 0}, _attempts_taken),
    do: "Unlimited"

  defp attempts_value(
         %Combined{batch_scoring: false, max_attempts: max_attempts},
         _attempts_taken
       ),
       do: Integer.to_string(max_attempts)

  defp attempts_value(%Combined{max_attempts: 0}, attempts_taken),
    do: "#{attempts_taken}/unlimited"

  defp attempts_value(%Combined{max_attempts: max_attempts}, attempts_taken),
    do: "#{attempts_taken}/#{max_attempts}"

  defp attempts_description(%Combined{batch_scoring: true}), do: nil

  defp attempts_description(%Combined{
         batch_scoring: false,
         replacement_strategy: :dynamic,
         max_attempts: max_attempts
       }) do
    "Each question can be attempted #{attempts_description_count(max_attempts)}. Resetting may replace the question."
  end

  defp attempts_description(%Combined{batch_scoring: false, max_attempts: max_attempts}) do
    "Each question can be attempted #{attempts_description_count(max_attempts)}."
  end

  defp cta_label(%Combined{batch_scoring: false}, _attempts_taken), do: "Begin Assignment"

  defp cta_label(_effective_settings, attempts_taken),
    do: "Begin #{ordinal_attempt(attempts_taken + 1)} Attempt"

  defp past_attempt(%ResourceAttempt{} = attempt, index, ctx) do
    %{
      number: index,
      score: attempt.score,
      out_of: attempt.out_of,
      submitted_at: submitted_at(attempt.date_submitted, ctx),
      lifecycle_state: attempt.lifecycle_state,
      attempt_guid: attempt.attempt_guid
    }
  end

  defp submitted_at(nil, _ctx), do: nil

  defp submitted_at(date_submitted, ctx),
    do: FormatDateTime.to_formatted_datetime(date_submitted, ctx, @submitted_date)

  defp graded_attempts(historical_attempts) when is_list(historical_attempts) do
    Enum.filter(historical_attempts, fn
      %ResourceAttempt{revision: %{graded: graded}} -> graded
      %ResourceAttempt{} -> true
      _ -> false
    end)
  end

  defp scoring_strategy(1), do: :average
  defp scoring_strategy(2), do: :best
  defp scoring_strategy(3), do: :most_recent
  defp scoring_strategy(4), do: :total
  defp scoring_strategy(_), do: :best

  defp score_at_end_strategy_text(strategy, 0),
    do: "#{score_at_end_strategy_label(strategy)} attempt"

  defp score_at_end_strategy_text(strategy, max_attempts),
    do: "#{score_at_end_strategy_label(strategy)} attempt out of #{max_attempts}"

  defp score_at_end_strategy_label(:average), do: "average"
  defp score_at_end_strategy_label(:best), do: "best"
  defp score_at_end_strategy_label(:most_recent), do: "most recent"
  defp score_at_end_strategy_label(:total), do: "total"

  defp score_as_you_go_strategy_text(:average), do: "average score"
  defp score_as_you_go_strategy_text(:best), do: "best score"
  defp score_as_you_go_strategy_text(:most_recent), do: "most recent score"
  defp score_as_you_go_strategy_text(:total), do: "total score"

  defp attempts_per_question_text(0), do: "unlimited attempts"
  defp attempts_per_question_text(1), do: "1 attempt"
  defp attempts_per_question_text(max_attempts), do: "#{max_attempts} attempts"

  defp attempts_description_count(0), do: "an unlimited number of times"
  defp attempts_description_count(1), do: "1 time"
  defp attempts_description_count(max_attempts), do: "up to #{max_attempts} times"

  defp ordinal_attempt(next_attempt_number) do
    case {rem(next_attempt_number, 10), rem(next_attempt_number, 100)} do
      {1, 11} -> "#{next_attempt_number}th"
      {2, 12} -> "#{next_attempt_number}th"
      {3, 13} -> "#{next_attempt_number}th"
      {1, _} -> "#{next_attempt_number}st"
      {2, _} -> "#{next_attempt_number}nd"
      {3, _} -> "#{next_attempt_number}rd"
      _ -> "#{next_attempt_number}th"
    end
  end

  defp segment_text(segments) do
    segments
    |> Enum.map(fn {_kind, value} -> value end)
    |> Enum.join("")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end

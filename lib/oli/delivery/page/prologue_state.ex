defmodule Oli.Delivery.Page.PrologueState do
  @moduledoc """
  Shared read model for student prologue state.

  This is the non-UI boundary used by the prologue delivery flow to derive
  attempt availability and messaging from a `PrologueContext`.
  """

  alias Oli.Delivery.{Gating, Settings}
  alias Oli.Delivery.Page.PrologueContext
  alias Oli.Delivery.Sections.Section
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Common.SessionContext

  @default_ctx %SessionContext{
    browser_timezone: "Etc/UTC",
    local_tz: "Etc/UTC",
    author: nil,
    user: nil,
    is_liveview: false,
    section: nil
  }

  defstruct [
    :page_context,
    :allow_attempt?,
    :attempt_message,
    :show_blocking_gates?,
    :attempts_taken,
    :max_attempts,
    :attempts_summary,
    :next_attempt_ordinal,
    :new_attempt_allowed,
    :terms
  ]

  def create_for_visit(%Section{} = section, page_slug, user, opts \\ []) do
    section
    |> PrologueContext.create_for_visit(page_slug, user)
    |> build(section, user, opts)
  end

  def build(%PrologueContext{} = page_context, %Section{} = section, user, opts \\ []) do
    ctx = Keyword.get(opts, :ctx, @default_ctx)
    is_admin? = Keyword.get(opts, :is_admin?, false)

    resource_attempts =
      Enum.filter(page_context.resource_attempts, fn a -> a.revision.graded end)

    attempts_taken = length(resource_attempts)
    blocking_gates = blocking_gates(section, user, page_context, is_admin?)

    new_attempt_allowed =
      Settings.new_attempt_allowed(
        page_context.effective_settings,
        attempts_taken,
        blocking_gates
      )

    max_attempts = max_attempts_label(page_context.effective_settings.max_attempts)

    terms =
      Oli.Delivery.Page.PrologueTerms.build(
        page_context.effective_settings,
        ctx,
        Oli.Delivery.Sections.Scheduling.has_scheduled_resources?(section.id)
      )

    %__MODULE__{
      page_context: %{page_context | historical_attempts: resource_attempts},
      allow_attempt?: new_attempt_allowed == {:allowed},
      attempt_message:
        attempt_message(
          new_attempt_allowed,
          page_context.effective_settings.max_attempts,
          attempts_taken,
          blocking_gates,
          ctx,
          page_context.effective_settings.start_date
        ),
      show_blocking_gates?: blocking_gates != [],
      attempts_taken: attempts_taken,
      max_attempts: max_attempts,
      attempts_summary: "Attempts #{attempts_taken}/#{max_attempts}",
      next_attempt_ordinal: ordinal_attempt(attempts_taken + 1),
      new_attempt_allowed: new_attempt_allowed,
      terms: terms
    }
  end

  defp blocking_gates(_section, _user, _page_context, true = _is_admin), do: []

  defp blocking_gates(
         section,
         user,
         %{page: %{resource_id: resource_id, graded: false}},
         _is_admin
       ),
       do: Gating.blocked_by(section, user, resource_id)

  defp blocking_gates(
         section,
         user,
         %{page: %{resource_id: resource_id, graded: true}},
         _is_admin
       ) do
    blocking_gates = Gating.blocked_by(section, user, resource_id)

    if Enum.any?(blocking_gates, fn gc -> gc.graded_resource_policy == :allows_nothing end) or
         !Oli.Delivery.Attempts.Core.has_any_attempts?(user, section, resource_id) do
      blocking_gates
    else
      Enum.filter(blocking_gates, fn gc ->
        gc.graded_resource_policy == :allows_review
      end)
    end
  end

  defp attempt_message(
         {:blocking_gates},
         _max_attempts,
         _attempts_taken,
         blocking_gates,
         ctx,
         _start_date
       ) do
    Gating.details(blocking_gates, format_datetime: format_datetime_fn(ctx))
  end

  defp attempt_message(
         {:score_as_you_go_completed},
         _max_attempts,
         _attempts_taken,
         _blocking_gates,
         _ctx,
         _start_date
       ),
       do: "This score as you go assessment has already been completed."

  defp attempt_message(
         {:no_attempts_remaining},
         max_attempts,
         _attempts_taken,
         _blocking_gates,
         _ctx,
         _start_date
       ),
       do:
         "You have no attempts remaining out of #{max_attempts} total attempt#{plural(max_attempts)}."

  defp attempt_message(
         {:before_start_date},
         _max_attempts,
         _attempts_taken,
         _blocking_gates,
         _ctx,
         start_date
       ),
       do:
         "This assessment is not yet available. It will be available on #{FormatDateTime.date(start_date, precision: :minutes)}"

  defp attempt_message(
         {:end_date_passed},
         _max_attempts,
         _attempts_taken,
         _blocking_gates,
         _ctx,
         _start_date
       ),
       do: "The deadline for this assignment has passed."

  defp attempt_message(
         {:allowed},
         0,
         _attempts_taken,
         _blocking_gates,
         _ctx,
         _start_date
       ),
       do: "You can take this scored page an unlimited number of times"

  defp attempt_message(
         {:allowed},
         max_attempts,
         attempts_taken,
         _blocking_gates,
         _ctx,
         _start_date
       ) do
    attempts_remaining = max_attempts - attempts_taken

    "You have #{attempts_remaining} attempt#{plural(attempts_remaining)} remaining out of #{max_attempts} total attempt#{plural(max_attempts)}."
  end

  defp max_attempts_label(0), do: "unlimited"
  defp max_attempts_label(max_attempts), do: max_attempts

  defp ordinal_attempt(next_attempt_number) do
    case {rem(next_attempt_number, 10), rem(next_attempt_number, 100)} do
      {1, _} -> Integer.to_string(next_attempt_number) <> "st"
      {2, _} -> Integer.to_string(next_attempt_number) <> "nd"
      {3, _} -> Integer.to_string(next_attempt_number) <> "rd"
      {_, 11} -> Integer.to_string(next_attempt_number) <> "th"
      {_, 12} -> Integer.to_string(next_attempt_number) <> "th"
      {_, 13} -> Integer.to_string(next_attempt_number) <> "th"
      _ -> Integer.to_string(next_attempt_number) <> "th"
    end
  end

  defp plural(1), do: ""
  defp plural(_), do: "s"

  defp format_datetime_fn(ctx) do
    fn datetime ->
      FormatDateTime.date(datetime, ctx: ctx, precision: :minutes)
    end
  end
end

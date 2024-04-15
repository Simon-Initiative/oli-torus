defmodule OliWeb.Components.Delivery.Student do
  use OliWeb, :html

  import OliWeb.Delivery.Student.Utils,
    only: [star_icon: 1]

  alias OliWeb.Common.FormatDateTime
  alias Oli.Delivery.Attempts.HistoricalGradedAttemptSummary
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias OliWeb.Components.Common

  attr(:raw_avg_score, :map)

  def score_summary(assigns) do
    ~H"""
    <div :if={@raw_avg_score[:score]} role="score summary" class="flex items-center gap-[6px] ml-auto">
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none">
        <path
          d="M3.88301 14.0007L4.96634 9.31732L1.33301 6.16732L6.13301 5.75065L7.99967 1.33398L9.86634 5.75065L14.6663 6.16732L11.033 9.31732L12.1163 14.0007L7.99967 11.5173L3.88301 14.0007Z"
          fill="#0CAF61"
        />
      </svg>
      <span class="text-[12px] leading-[16px] tracking-[0.02px] text-[#0CAF61] font-semibold whitespace-nowrap">
        <%= format_float(@raw_avg_score[:score]) %> / <%= format_float(@raw_avg_score[:out_of]) %>
      </span>
    </div>
    """
  end

  defp format_float(float) do
    float
    |> round()
    |> trunc()
  end

  attr(:ctx, OliWeb.Common.SessionContext)
  attr(:section_slug, :string)
  attr(:page_revision_slug, :string)
  attr(:attempts_count, :integer)
  attr(:attempt_summary, HistoricalGradedAttemptSummary)
  attr(:effective_settings, :map)

  def attempts_dropdown(assigns) do
    assigns = assign(assigns, :id, "page-#{assigns[:page_revision_slug]}-attempts")

    ~H"""
    <div class="self-stretch justify-start items-start gap-6 inline-flex relative mb-1">
      <button
        id={"#{@id}-dropdown-button"}
        class="opacity-80 dark:text-white text-sm font-bold font-['Open Sans'] uppercase no-wrap tracking-wider"
        phx-click={show_attempts_dropdown("##{@id}-dropdown", @page_revision_slug)}
        phx-value-hide-target={"##{@id}-dropdown"}
      >
        Attempts <%= @attempts_count %>/<%= max_attempts(@effective_settings) %>
        <span><i class="fa-solid fa-caret-down"></i></span>
      </button>
      <.dropdown_menu id={"#{@id}-dropdown"}>
        <Common.loading_spinner :if={
          !@attempt_summary || @attempt_summary.page_revision_slug != @page_revision_slug
        } />
        <.attempts_summary
          :if={@attempt_summary && @attempt_summary.page_revision_slug == @page_revision_slug}
          ctx={@ctx}
          attempt_summary={@attempt_summary}
          section_slug={@section_slug}
          effective_settings={@effective_settings}
          page_revision_slug={@page_revision_slug}
        />
      </.dropdown_menu>
    </div>
    """
  end

  defp max_attempts(%{max_attempts: 0}), do: "∞"
  defp max_attempts(%{max_attempts: max_attempts}), do: max_attempts

  attr(:id, :string, required: true)
  attr(:class, :string, default: "")
  slot(:inner_block, required: true)

  def dropdown_menu(assigns) do
    ~H"""
    <div
      id={@id}
      class={"hidden absolute top-[50px] right-0 z-50 whitespace-nowrap bg-white dark:bg-black p-2 rounded-lg shadow-lg #{@class}"}
    >
      <ul>
        <%= render_slot(@inner_block) %>
      </ul>
    </div>
    """
  end

  defp show_attempts_dropdown(id, page_revision_slug) do
    %JS{}
    |> JS.toggle(
      to: id,
      in: {"ease-out duration-300", "opacity-0 top-[40px]", "opacity-100"},
      out: {"ease-out duration-300", "opacity-100", "opacity-0 top-[40px]"}
    )
    |> JS.push("load_historical_graded_attempt_summary",
      value: %{page_revision_slug: page_revision_slug}
    )
  end

  defp hide_attempts_dropdown(id) do
    %JS{}
    |> JS.hide(
      to: id,
      transition: {"ease-out duration-300", "opacity-100", "opacity-0 top-[40px]"}
    )
    |> JS.push("clear_historical_graded_attempt_summary")
  end

  attr(:attempt_summary, HistoricalGradedAttemptSummary)
  attr(:effective_settings, :map)
  attr(:ctx, OliWeb.Common.SessionContext)
  attr(:section_slug, :string)
  attr(:page_revision_slug, :string)

  defp attempts_summary(
         %{attempt_summary: %HistoricalGradedAttemptSummary{historical_attempts: []}} = assigns
       ) do
    ~H"""
    <div
      id="attempts_summary"
      class="w-full flex-col justify-start items-start gap-3 flex"
      phx-click-away={hide_attempts_dropdown("#page-#{@page_revision_slug}-attempts-dropdown")}
    >
      <div class="self-stretch flex-col justify-start items-start flex p-3">
        There are no attempts for this page.
      </div>
    </div>
    """
  end

  defp attempts_summary(assigns) do
    ~H"""
    <div
      id="attempts_summary"
      class="flex flex-col gap-3"
      phx-click-away={hide_attempts_dropdown("#page-#{@page_revision_slug}-attempts-dropdown")}
    >
      <div class="flex flex-row justify-between p-2">
        <div class="text-sm uppercase">
          Score Information
        </div>
        <button phx-click={hide_attempts_dropdown("#page-#{@page_revision_slug}-attempts-dropdown")}>
          <i class="fa-solid fa-xmark"></i>
        </button>
      </div>
      <div class="flex flex-col p-2">
        <.attempt_summary
          :for={
            {attempt, index} <-
              @attempt_summary.historical_attempts
              |> Enum.with_index(1)
          }
          index={index}
          section_slug={@section_slug}
          page_revision_slug={@page_revision_slug}
          attempt={attempt}
          ctx={@ctx}
          effective_settings={@effective_settings}
        />
      </div>
    </div>
    """
  end

  attr(:index, :integer)
  attr(:attempt, ResourceAttempt)
  attr(:ctx, OliWeb.Common.SessionContext)
  attr(:effective_settings, :map)
  attr(:section_slug, :string)
  attr(:page_revision_slug, :string)

  defp attempt_summary(assigns) do
    ~H"""
    <div id={"attempt_#{@index}_summary"} class="py-1">
      <.attempt_details
        ctx={@ctx}
        index={@index}
        attempt={@attempt}
        section_slug={@section_slug}
        page_revision_slug={@page_revision_slug}
        effective_settings={@effective_settings}
      />
    </div>
    """
  end

  attr(:index, :integer)
  attr(:attempt, ResourceAttempt)
  attr(:ctx, OliWeb.Common.SessionContext)
  attr(:section_slug, :string)
  attr(:page_revision_slug, :string)
  attr(:effective_settings, :map)

  defp attempt_details(%{attempt: %ResourceAttempt{lifecycle_state: :active}} = assigns) do
    ~H"""
    <div class="flex flex-col">
      <div class="flex flex-row justify-between gap-10 text-xs">
        <div class="flex flex-row gap-1 text-xs font-semibold">
          <div class="font-semibold uppercase text-gray-500 mr-1">Attempt <%= @index %>:</div>
        </div>
        <.time_remaining
          :if={has_end_date?(@effective_settings)}
          effective_settings={@effective_settings}
        />
      </div>
      <div class="flex flex-row justify-end">
        <div
          :if={allow_review_submission?(@effective_settings)}
          class="w-[124px] py-1 justify-end items-center gap-2.5 inline-flex"
        >
          <.link
            href={~p"/sections/#{@section_slug}/lesson/#{@page_revision_slug}"}
            role="review_attempt_link"
          >
            <div class="cursor-pointer hover:opacity-40 text-blue-500 text-xs font-semibold font-['Open Sans'] uppercase tracking-wide">
              Continue
            </div>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp attempt_details(assigns) do
    ~H"""
    <div class="flex flex-col">
      <div class="flex flex-row justify-between gap-10 text-xs">
        <div class="flex flex-row gap-1 text-xs font-semibold">
          <div class="font-semibold uppercase text-gray-500 mr-1">Attempt <%= @index %>:</div>
          <div class="w-4 h-4 relative"><.star_icon /></div>

          <div role="attempt score" class="text-emerald-600 tracking-tight">
            <%= Float.round(@attempt.score, 2) %>
          </div>
          <div class="text-emerald-600">
            /
          </div>
          <div role="attempt out of" class="text-emerald-600 tracking-tight">
            <%= Float.round(@attempt.out_of, 2) %>
          </div>
        </div>
        <div>
          <%= FormatDateTime.to_formatted_datetime(
            @attempt.date_submitted,
            @ctx,
            "{WDshort} {Mshort} {D}, {YYYY}"
          ) %>
        </div>
      </div>
      <div class="flex flex-row justify-end">
        <div
          :if={allow_review_submission?(@effective_settings)}
          class="w-[124px] py-1 justify-end items-center gap-2.5 inline-flex"
        >
          <.link
            href={
              ~p"/sections/#{@section_slug}/lesson/#{@page_revision_slug}/attempt/#{@attempt.attempt_guid}/review"
            }
            role="review_attempt_link"
          >
            <div class="cursor-pointer hover:opacity-40 text-blue-500 text-xs font-semibold font-['Open Sans'] uppercase tracking-wide">
              Review
            </div>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp allow_review_submission?(%{review_submission: :allow}), do: true
  defp allow_review_submission?(_), do: false

  defp has_end_date?(effective_settings) do
    case effective_settings.end_date do
      nil -> false
      _ -> true
    end
  end

  defp time_remaining(%{effective_settings: %{end_date: nil}} = assigns) do
    ~H"""

    """
  end

  defp time_remaining(assigns) do
    ~H"""
    <div>
      <span class="text-xs text-gray-500 mr-1">
        Time Remaining:
      </span>
      <%= format_time_remaining(@effective_settings) %>
    </div>
    """
  end

  defp format_time_remaining(effective_settings) do
    # Get the current time
    current_time = Timex.now()

    # Calculate the difference in seconds, clamp negative values to 0
    diff_seconds =
      Timex.diff(effective_settings.end_date, current_time, :seconds)
      |> max(0)

    # Calculate hours, minutes and seconds
    hours = div(diff_seconds, 3600)
    minutes = div(rem(diff_seconds, 3600), 60)
    seconds = rem(diff_seconds, 60)

    # format duration as HH:MM:SS
    (hours
     |> Integer.to_string()
     |> String.pad_leading(2, "0")) <>
      ":" <>
      (minutes
       |> Integer.to_string()
       |> String.pad_leading(2, "0")) <>
      ":" <>
      (seconds
       |> Integer.to_string()
       |> String.pad_leading(2, "0"))
  end
end
